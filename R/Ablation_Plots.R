# ============================================================
# Ablation_Plots.R - diagnostic plots of ice lost at the surface through time
#
#   1. One figure per lake (3 stacked panels, shared time axis):
#        a. modelled ice thickness (context)
#        b. daily ablation rate, cm/day: surface melt + internal melt
#        c. cumulative ablation within each ablation season, m
#   2. One summary figure: ablation per season, all lakes
#
# What counts as ablation here (all from run_ice_model() output, m per step):
#   surface_loss   melt at the surface from the surface energy balance
#                  (with surface_bc = "flux": only once T_s reaches 0 °C)
#   internal_melt  ice lost to penetrating shortwave (sw_penetration = TRUE):
#                  interior melt that drains, PLUS the bottom half-slice and
#                  sw_to_base share that melt the base. Not strictly surface
#                  ablation, but it is the SW-driven thinning that replaced Chi.
#   implied sublimation (diagnostic only, dashed): -latent_Q / (rho * L_s)
#                  whenever latent_Q < 0. The model treats latent heat as an
#                  energy term only - it does NOT remove this mass - so this
#                  line shows how much surface lowering sublimation would add.
#
# Seasons: Dry Valley lakes run 1 Jul - 30 Jun so each austral summer sits in
# one season; GL4 / The Loch run 1 Oct - 30 Sep (N. hemisphere water year).
#
# Reads  Data/model_outputs/<LAKE>_<years>_output.csv
# Writes figures/Ablation_Plots/*.png
# Run from the project root:  source("R/Ablation_Plots.R")
# ============================================================

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(ggplot2); library(readr); library(lubridate)
})

in_dir  <- if (exists("abl_in_dir"))  abl_in_dir  else "Data/model_outputs"
out_dir <- if (exists("abl_out_dir")) abl_out_dir else "figures/Ablation_Plots"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

LAKES <- c(ELB = "East Lobe Bonney", WLB = "West Lobe Bonney", LH = "Lake Hoare",
           LF = "Lake Fryxell", GL4 = "Green Lake 4", LOC = "The Loch")
SEASONAL <- c("GL4", "LOC")

RHO <- 917; L_S <- 2.834e6          # ice density (kg/m3), latent heat of sublimation (J/kg)

COMP_LAB <- c(surface = "Surface melt", internal = "Penetrating-SW melt (interior + base)",
              sublim = "Implied sublimation (not removed in model)")
COMP_COL <- c(surface = "#eb6834", internal = "#2a78d6", sublim = "#1baf7a")
INK <- "#2b2b2b"; MUTED <- "#77756e"; GRID <- "#e6e4dd"

theme_abl <- function(base = 13) {
  theme_minimal(base_size = base) +
    theme(panel.grid.minor = element_blank(),
          panel.grid.major = element_line(colour = GRID, linewidth = 0.3),
          axis.text = element_text(colour = MUTED), axis.title = element_text(colour = INK),
          strip.text = element_text(colour = INK, face = "bold", hjust = 0),
          strip.placement = "outside",
          plot.title = element_text(colour = INK, face = "bold"),
          plot.subtitle = element_text(colour = MUTED),
          plot.caption = element_text(colour = MUTED, hjust = 0),
          legend.position = "top", legend.title = element_blank(),
          plot.background = element_rect(fill = "white", colour = NA))
}
save_fig <- function(p, name, w = 13.33, h = 7.5)
  ggsave(file.path(out_dir, name), p, width = w, height = h, dpi = 200, bg = "white")

# ---- load + daily aggregation ------------------------------------------------
read_lake <- function(lake) {
  f <- list.files(in_dir, pattern = paste0("^", lake, "_\\d{4}_\\d{4}_output\\.csv$"),
                  full.names = TRUE)
  if (!length(f)) return(NULL)
  d <- readr::read_csv(f[1], show_col_types = FALSE, progress = FALSE,
         col_select = dplyr::any_of(c("time", "thickness", "latent_Q", "surface_loss",
                                      "internal_melt", "bottom_gain")))
  if (!"internal_melt" %in% names(d)) d$internal_melt <- 0
  start_month <- if (lake %in% SEASONAL) 10 else 7
  dt_sec <- median(as.numeric(diff(d$time), units = "secs"), na.rm = TRUE)

  d |>
    mutate(sublim = pmax(-latent_Q, 0) * dt_sec / (RHO * L_S),   # m per step
           day = as.Date(time)) |>
    group_by(day) |>
    summarise(thickness = mean(thickness, na.rm = TRUE),
              surface   = sum(surface_loss,  na.rm = TRUE),
              internal  = sum(internal_melt, na.rm = TRUE),
              sublim    = sum(sublim,        na.rm = TRUE),
              .groups = "drop") |>
    mutate(lake = lake,
           season = year(day) - (month(day) < start_month),
           season_lab = sprintf("%d-%02d", season, (season + 1) %% 100))
}

daily <- bind_rows(lapply(names(LAKES), read_lake))
if (!nrow(daily)) stop("No <LAKE>_<years>_output.csv files found in ", in_dir)
lakes_found <- intersect(names(LAKES), unique(daily$lake))
message("Ablation plots for: ", paste(lakes_found, collapse = ", "))

# cumulative ablation within each season
daily <- daily |>
  group_by(lake, season) |>
  arrange(day, .by_group = TRUE) |>
  mutate(cum_surface  = cumsum(surface),
         cum_internal = cumsum(internal),
         cum_sublim   = cumsum(sublim)) |>
  ungroup()

# ---- 1. per-lake figure ------------------------------------------------------
PANELS <- c(th = "Ice thickness (m)",
            rate = "Daily ablation (cm/day)",
            cum = "Cumulative ablation this season (m)")

plot_lake <- function(lk) {
  d <- filter(daily, lake == lk)

  th   <- transmute(d, day, panel = "th", value = thickness)
  rate <- d |>
    select(day, surface, internal) |>
    pivot_longer(-day, names_to = "comp", values_to = "value") |>
    mutate(panel = "rate", value = value * 100,
           comp = factor(comp, levels = names(COMP_LAB)))
  cum <- d |>
    select(day, season, surface = cum_surface, internal = cum_internal, sublim = cum_sublim) |>
    mutate(total = surface + internal) |>
    pivot_longer(c(surface, internal, sublim, total), names_to = "comp", values_to = "value") |>
    mutate(panel = "cum")

  fac <- function(x) factor(x, levels = names(PANELS), labels = PANELS)
  th$panel <- fac(th$panel); rate$panel <- fac(rate$panel); cum$panel <- fac(cum$panel)

  cum_comp  <- filter(cum, comp %in% c("surface", "internal", "sublim")) |>
    mutate(comp = factor(comp, levels = names(COMP_LAB)))
  cum_total <- filter(cum, comp == "total")

  # season-end totals (surface + internal) labelled on the cumulative panel
  ends <- cum_total |> group_by(season) |> slice_max(day, n = 1, with_ties = FALSE) |>
    ungroup() |> filter(value > 0.005)

  ggplot() +
    geom_line(data = th, aes(day, value), colour = INK, linewidth = 0.6) +
    geom_col(data = rate, aes(day, value, fill = comp), width = 1, position = "stack") +
    geom_line(data = cum_total, aes(day, value, group = season),
              colour = INK, linewidth = 0.5, alpha = 0.5) +
    geom_line(data = cum_comp, aes(day, value, colour = comp, linetype = comp,
                                   group = interaction(season, comp)), linewidth = 0.7) +
    geom_text(data = ends, aes(day, value, label = sprintf("%.2f m", value)),
              colour = MUTED, size = 3, hjust = 1.05, vjust = -0.5) +
    facet_grid(panel ~ ., scales = "free_y", switch = "y") +
    scale_fill_manual(values = COMP_COL, labels = COMP_LAB[c("surface", "internal")],
                      limits = c("surface", "internal")) +
    scale_colour_manual(values = COMP_COL, labels = COMP_LAB) +
    scale_linetype_manual(values = c(surface = "solid", internal = "solid", sublim = "22"),
                          labels = COMP_LAB) +
    scale_x_date(date_breaks = "1 year", date_labels = "%Y", expand = expansion(mult = 0.01)) +
    scale_y_continuous(expand = expansion(mult = c(0.03, 0.15))) +   # room for season labels
    guides(fill = "none") +
    labs(x = NULL, y = NULL,
         title = sprintf("%s - surface ablation through time", LAKES[[lk]]),
         subtitle = "Bars: daily melt. Lines: running total within each season (grey = surface + internal melt; label = season total).",
         caption = paste0("Implied sublimation = -latent_Q / (rho_ice * L_s) when latent_Q < 0; ",
                          "the model uses latent heat as energy only and does not remove this mass. ",
                          "Seasons start 1 ", if (lk %in% SEASONAL) "Oct" else "Jul", ".")) +
    theme_abl()
}

for (lk in lakes_found) save_fig(plot_lake(lk), sprintf("%s_ablation_timeseries.png", lk), h = 9)

# ---- 2. seasonal totals, all lakes -------------------------------------------
totals <- daily |>
  group_by(lake, season, season_lab) |>
  summarise(n_days = n(), surface = sum(surface), internal = sum(internal),
            sublim = sum(sublim), .groups = "drop") |>
  filter(n_days >= 300) |>                       # complete seasons only
  mutate(lake = factor(lake, levels = names(LAKES), labels = LAKES))

write_csv(totals, file.path(out_dir, "ablation_season_totals.csv"))

bars <- totals |>
  select(lake, season_lab, surface, internal) |>
  pivot_longer(c(surface, internal), names_to = "comp", values_to = "value") |>
  mutate(comp = factor(comp, levels = c("internal", "surface")))

p_tot <- ggplot(bars, aes(season_lab, value)) +
  geom_col(aes(fill = comp), width = 0.7, colour = "white", linewidth = 0.5) +
  geom_point(data = totals, aes(season_lab, sublim, shape = "sublim"),
             colour = COMP_COL[["sublim"]], size = 2.6, stroke = 1.1) +
  facet_wrap(~ lake, scales = "free_x") +
  scale_fill_manual(values = COMP_COL, labels = COMP_LAB[c("surface", "internal")],
                    breaks = c("surface", "internal")) +
  scale_shape_manual(values = c(sublim = 4), labels = COMP_LAB["sublim"]) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.08))) +
  labs(x = "Ablation season", y = "Ice lost per season (m)",
       title = "Seasonal ablation by lake",
       subtitle = "Bars: melt removed by the model. Crosses: sublimation implied by the latent heat flux (not removed).",
       caption = "Complete seasons only (>= 300 days of output).") +
  theme_abl() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

save_fig(p_tot, "ablation_season_totals.png")
message("Saved to ", out_dir)
