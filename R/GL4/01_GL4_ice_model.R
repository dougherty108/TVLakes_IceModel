######## GL4 (Green Lake 4, Niwot Ridge) — seasonal ice model run ############
#
# Runs the 1-D ice thickness model on GL4. Because GL4 is a seasonally frozen
# lake (seasonally_frozen = TRUE in LAKE_CONFIGS), run_ice_model() cycles
# between:
#   • "ice" phase   : standard 1-D conductive ice model
#   • "open_water"  : mixed-layer energy balance; nucleates ice when T_water
#                     reaches Tf while the surface is losing heat
#
# The model output includes two extra columns vs perennial lakes:
#   phase   — "ice" | "open_water" at each timestep
#   T_water — mixed-layer temperature (K); NA during ice phase
#
# Before running this script, source 00_GL4_data_preparation.R (or just run
# it interactively — this script re-sources it automatically).
###############################################################################

source("R/TEST_Optimizations/libraries.R")
source("R/TEST_Optimizations/functions.R")
source("R/GL4/00_GL4_data_preparation.R")

# ---- Scenario assumptions ---------------------------------------------------
warming_rate <- 0.00   # K/yr added to T_air; 0 = historical forcing unchanged
albedo_rate  <- 0.00   # /yr added to albedo; 0 = constant ice albedo from config

# ---- Prepare model input ----------------------------------------------------
# prepare_model_input() applies optional warming/albedo trends and adds the
# delta_T column required by run_ice_model(). gl4_constants carries
# seasonally_frozen = TRUE and albedo_ice from LAKE_CONFIGS$GL4.
ts_ready <- prepare_model_input(
  time_series  = time_series,
  warming_rate = warming_rate,
  albedo_rate  = albedo_rate,
  constants    = gl4_constants
)

# ---- Run the model ----------------------------------------------------------
message("\n[GL4] Running seasonal ice model...")
results <- run_ice_model(
  ts_ready,
  constants     = gl4_constants,
  show_progress = TRUE
)

message(sprintf(
  "[GL4] Done. %d timesteps | ice-on fraction: %.1f%%",
  nrow(results),
  100 * mean(results$phase == "ice", na.rm = TRUE)
))

# ---- Plot: ice thickness + phase + T_water ----------------------------------
# Panel 1: ice thickness coloured by phase
p_thickness <- results |>
  mutate(phase = if_else(is.na(phase), "ice", phase)) |>
  ggplot(aes(x = time, y = thickness, colour = phase)) +
  geom_line(linewidth = 0.5, alpha = 0.85) +
  scale_colour_manual(
    values = c(ice = "#3B8BD4", open_water = "#E8593C"),
    labels = c(ice = "Ice", open_water = "Open water"),
    name   = "Phase"
  ) +
  # Overlay observed ice thickness as points
  geom_point(
    data    = ice_thickness |> filter(time >= min(results$time),
                                      time <= max(results$time)),
    aes(x = time, y = thickness),
    inherit.aes = FALSE,
    colour = "black", shape = 21, fill = "white", size = 2.5, stroke = 0.8
  ) +
  labs(
    title    = "GL4 — modelled ice thickness (line) vs observed (points)",
    subtitle = sprintf("warming_rate = %.2f K/yr  |  albedo = %.2f (constant)",
                       warming_rate, gl4_constants$albedo_ice),
    x        = NULL,
    y        = "Ice thickness (m)"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.position = "bottom")

# Panel 2: mixed-layer water temperature (open-water phase only)
p_T_water <- results |>
  filter(!is.na(T_water)) |>
  ggplot(aes(x = time, y = T_water - 273.15)) +
  geom_line(linewidth = 0.5, colour = "#E8593C", alpha = 0.8) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey50") +
  labs(
    x = NULL,
    y = "Mixed-layer T (°C)"
  ) +
  theme_minimal(base_size = 13)

# Panel 3: net surface heat flux
p_flux <- results |>
  ggplot(aes(x = time, y = surface_heat_flux)) +
  geom_line(linewidth = 0.3, colour = "grey40", alpha = 0.7) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "black") +
  labs(x = NULL, y = "Surface flux (W m⁻²)") +
  theme_minimal(base_size = 13)

gl4_plot <- p_thickness / p_T_water / p_flux +
  plot_annotation(
    title = "GL4 Green Lake 4 — seasonal freeze-thaw model",
    theme = theme(plot.title = element_text(size = 15, face = "bold"))
  )

print(gl4_plot)

# ---- Summary statistics per calendar year -----------------------------------
annual_summary <- results |>
  mutate(year = lubridate::year(time)) |>
  group_by(year) |>
  summarise(
    mean_thickness_m   = mean(thickness,  na.rm = TRUE),
    max_thickness_m    = max(thickness,   na.rm = TRUE),
    ice_on_fraction    = mean(phase == "ice", na.rm = TRUE),
    mean_T_water_degC  = mean(T_water - 273.15, na.rm = TRUE),
    .groups = "drop"
  )

message("\n[GL4] Annual summary:")
print(annual_summary, n = Inf)
