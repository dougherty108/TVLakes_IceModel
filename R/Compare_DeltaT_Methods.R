###### Compare delta_T methods for the sensible heat flux ########

### Authors
# Charlie Dougherty

# NOTES
# Runs the ice model for one lake several times, changing only how delta_T
# (the air-minus-surface temperature difference in the sensible heat flux,
# Qh = rho_air * Ca * Ch * delta_T * wind) is calculated, and plots how
# delta_T, Qh and ice thickness respond.
#
# Methods (see the run_ice_model() header in R/functions/functions.R):
#   "lag"            current model: T_air(t) - T_air(t-1)
#   "ashton"         surface temp from conduction / air-exchange balance
#   "energy_balance" surface temp solved from the full surface energy balance
#   "lwr_out"        surface temp from LWR_out (add it to `methods` below;
#                    most useful for lakes with measured LWR_out)
#
# Everything else in the model is identical between runs, so differences
# in the output come from delta_T alone.

source("R/functions/libraries.R")
source("R/functions/functions.R")

lake_key <- "ELB"   # any LAKE_CONFIGS key: "ELB", "WLB", "LH", "LF", "GL4", "LOC"

methods <- c(
  "Current (lag)"  = "lag",
  "Ashton"         = "ashton",
  "Energy balance" = "energy_balance"
)

# Optional date window for the plot, e.g. one ice season:
#   plot_window <- as.Date(c("2020-10-01", "2021-07-01"))
plot_window <- NULL

###################### Build model inputs ######################
# Uses the lake's own 00_ data-prep script, which leaves `inputs` behind.
source(file.path("R", lake_key, paste0("00_", lake_key, "_data_preparation.R")))

ts_ready <- prepare_model_input(
  inputs$time_series,
  warming_rate = 0,
  constants    = lake_constants(lake_key)
)

###################### Run the model once per method ######################
results <- purrr::imap_dfr(methods, function(method, label) {
  message("Running ", lake_key, " with delta_T_method = '", method, "'")
  run_ice_model(ts_ready,
                constants      = lake_constants(lake_key),
                show_progress  = FALSE,
                delta_T_method = method) |>
    dplyr::select(time, thickness, sensible_Q, delta_T, T_surface) |>
    dplyr::mutate(method = label)
}) |>
  dplyr::mutate(method = factor(method, levels = names(methods)))

###################### Daily means for plotting ######################
daily <- results |>
  dplyr::mutate(date = as.Date(time)) |>
  dplyr::group_by(method, date) |>
  dplyr::summarise(dplyr::across(c(thickness, sensible_Q, delta_T, T_surface),
                                 ~ mean(.x, na.rm = TRUE)),
                   .groups = "drop")

air_daily <- ts_ready |>
  dplyr::mutate(date = as.Date(time)) |>
  dplyr::group_by(date) |>
  dplyr::summarise(T_air = mean(T_air, na.rm = TRUE) - 273.15, .groups = "drop")

if (!is.null(plot_window)) {
  daily     <- dplyr::filter(daily,     date >= plot_window[1], date <= plot_window[2])
  air_daily <- dplyr::filter(air_daily, date >= plot_window[1], date <= plot_window[2])
}

###################### Plot ######################
method_cols <- c("#1b6ca8", "#d1495b", "#2e8b57", "#e9a03b")[seq_along(methods)]
names(method_cols) <- names(methods)

panel <- function(df, y, ylab, hline = NULL) {
  p <- ggplot(df, aes(date, .data[[y]], colour = method)) +
    { if (!is.null(hline)) geom_hline(yintercept = hline, colour = "grey60", linewidth = 0.3) } +
    geom_line(linewidth = 0.4) +
    scale_colour_manual(values = method_cols, name = NULL) +
    labs(x = NULL, y = ylab) +
    theme_bw(base_size = 11) +
    theme(legend.position = "bottom")
  p
}

p_air <- ggplot(air_daily, aes(date, T_air)) +
  geom_hline(yintercept = 0, colour = "grey60", linewidth = 0.3) +
  geom_line(colour = "grey30", linewidth = 0.3) +
  labs(x = NULL, y = "Air temp (deg C)") +
  theme_bw(base_size = 11)

p_dT  <- panel(daily, "delta_T",    "delta T (K)",  hline = 0)
p_Qh  <- panel(daily, "sensible_Q", "Qh (W m-2)",   hline = 0)
p_h   <- panel(daily, "thickness",  "Ice thickness (m)")

p <- (p_air / p_dT / p_Qh / p_h) +
  plot_layout(guides = "collect", heights = c(0.7, 1, 1, 1.3)) +
  plot_annotation(
    title    = paste0(inputs$lake_name, ": effect of the delta_T method on the sensible heat flux"),
    subtitle = "Daily means; only delta_T differs between runs"
  ) &
  theme(legend.position = "bottom")

print(p)

out_dir <- file.path("figures", "Compare_DeltaT_Methods")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
ggsave(file.path(out_dir, paste0(lake_key, "_deltaT_methods.png")),
       p, width = 10, height = 10, dpi = 150)

###################### Summary table ######################
# Ice season = Jul-Jun "ice year", labelled by the year it ends in.
summary_tbl <- results |>
  dplyr::mutate(ice_year = lubridate::year(time) +
                  (lubridate::month(time) >= 7)) |>
  dplyr::group_by(method, ice_year) |>
  dplyr::summarise(
    max_thickness_m = round(max(thickness, na.rm = TRUE), 2),
    mean_Qh_on_ice  = round(mean(sensible_Q[thickness > 0], na.rm = TRUE), 1),
    ice_free_days   = round(sum(thickness <= 0) / 24),
    .groups = "drop"
  ) |>
  tidyr::pivot_wider(names_from = method,
                     values_from = c(max_thickness_m, mean_Qh_on_ice, ice_free_days))

print(summary_tbl, width = Inf)
