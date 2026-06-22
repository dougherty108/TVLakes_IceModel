######## GL4 (Green Lake 4, Niwot Ridge) — data preparation ##################
#
# Loads and prepares meteorological and ice-thickness data for Green Lake 4.
# GL4 is a seasonally frozen alpine lake; the model runs year-round, cycling
# between open-water and ice-covered phases.
#
# Data sources (NWT LTER, D1 station):
#   met  : Data/gl4/d-1cr23x-cr1000.10minute.ml.data.csv   (10-min intervals)
#   ice  : Data/gl4/gl4_ice_thickness.nc.data.csv           (cm, monthly-ish)
#
# All heavy lifting is done by prepare_gl4_model_inputs() in functions.R.
# The outputs produced here mirror the schema used by the Antarctic 00_ scripts:
#   inputs$lake_key, inputs$lake_name, inputs$time_series, inputs$ice_thickness,
#   inputs$constants
# so that downstream scripts (01_, Compare_*, etc.) need no GL4-specific code.
###############################################################################

source("R/TEST_Optimizations/libraries.R")
source("R/TEST_Optimizations/functions.R")

# ---- File paths (relative to project root) ----------------------------------
met_csv <- "Data/gl4/d-1cr23x-cr1000.10minute.ml.data.csv"
ice_csv <- "Data/gl4/gl4_ice_thickness.nc.data.csv"

# ---- Prepare inputs ---------------------------------------------------------
# start_filter: D1 station data begins 2013-12-31; skip the partial first day.
# n_years = "max" uses all available data (through 2025).
inputs <- prepare_gl4_model_inputs(
  met_csv      = met_csv,
  ice_csv      = ice_csv,
  lake_configs = LAKE_CONFIGS,
  constants    = CONSTANTS,
  start_filter = as.POSIXct("2014-01-01 00:00:00", tz = "UTC"),
  n_years      = "max"
)

# ---- Convenience aliases (same names expected by downstream scripts) ---------
lake_key      <- inputs$lake_key       # "GL4"
lake_name     <- inputs$lake_name      # "Green Lake 4"
time_series   <- inputs$time_series
ice_thickness <- inputs$ice_thickness
gl4_constants <- inputs$constants      # lake_constants("GL4") result

# ---- Quick sanity checks ----------------------------------------------------
message(sprintf(
  "[GL4] %d hourly rows | %s – %s",
  nrow(time_series),
  format(min(time_series$time, na.rm = TRUE), "%Y-%m-%d"),
  format(max(time_series$time, na.rm = TRUE), "%Y-%m-%d")
))
message(sprintf(
  "[GL4] %d ice-thickness observations | range %.2f – %.2f m",
  nrow(ice_thickness),
  min(ice_thickness$thickness, na.rm = TRUE),
  max(ice_thickness$thickness, na.rm = TRUE)
))

# ---- Optional: plot raw met forcing -----------------------------------------
if (exists("plot_raw") && isTRUE(plot_raw)) {
  vars_to_plot <- c("T_air", "SW_in", "LWR_in", "wind",
                    "relative_humidity", "pressure", "albedo")
  p_raw <- time_series |>
    pivot_longer(cols = any_of(vars_to_plot),
                 names_to = "variable", values_to = "value") |>
    ggplot(aes(x = time, y = value)) +
    geom_line(linewidth = 0.3, alpha = 0.7, colour = "#3B8BD4") +
    facet_wrap(~variable, scales = "free_y", ncol = 2) +
    labs(title = "GL4 — raw hourly forcing",
         x = NULL, y = NULL) +
    theme_minimal(base_size = 11)
  print(p_raw)
}

# ---- Optional: plot ice thickness observations ------------------------------
if (exists("plot_ice_obs") && isTRUE(plot_ice_obs)) {
  p_ice <- ggplot(ice_thickness, aes(x = time, y = thickness)) +
    geom_point(colour = "#E8593C", size = 2) +
    geom_line(colour = "#E8593C", linewidth = 0.5, alpha = 0.6) +
    labs(title = "GL4 — observed ice thickness (cm → m)",
         x = NULL, y = "Ice thickness (m)") +
    theme_minimal(base_size = 12)
  print(p_ice)
}
