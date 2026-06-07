###### Compare all four lakes — climatological forecast -> ice thickness ########

### Authors
# Charlie Dougherty

# NOTES
# This script runs the full climatological-forecast -> ice-thickness-model
# pipeline for all four lakes (ELB, WLB, LH, LF) back to back, on the same
# climate-scenario assumptions, and plots/tabulates the results together so
# they can be compared directly.
#
# For each lake it:
#   1. Sources that lake's 00_<LAKE>_data_preparation.R  (builds `inputs`,
#      the short modeling-period record the ice model itself runs on)
#   2. Re-runs prepare_lake_model_inputs() with an early start_filter and
#      n_years = "max" to pull a LONG record (back into the 1990s) for that
#      lake, then calls generate_climatological_climate() to build a
#      mean-annual "typical year" climatology and tile it forward to
#      `horizon_year` as the forecast-period climate
#   3. Applies the SAME warming-rate scenario to each lake's forecast period
#      (climate_forecast$future_physical) via prepare_model_input()
#   4. Runs run_ice_model() and stores the resulting ice-thickness time series
#
# It then lines all four lakes' modeled ice thickness up on a shared time
# axis (years-from-forecast-start) and plots them together, plus prints a
# small summary table (mean / min / max thickness per lake).
#
# Adjust `horizon_year`, `warming_rate`, and `climatology_start` below to
# explore different "what if" climate scenarios across all four lakes at
# once. This is a thin orchestration layer over the lake-agnostic functions
# in R/TEST_Optimizations/functions.R — no lake-specific modeling code lives
# here.

source("R/TEST_Optimizations/libraries.R")
source("R/TEST_Optimizations/functions.R")

###################### Scenario assumptions (applied to every lake) ######################
# How far forward (calendar year) to tile each lake's climatology out to.
horizon_year <- 2050

# Compounding annual warming rate applied to T_air in the forecast period.
# Set to 0 for "no extra warming beyond the typical-year climatology itself";
# > 0 to layer a warming scenario on top of that climatological baseline
# (the comparison this script is built around).
warming_rate <- 0.00   # 1% per year

# Set to FALSE to skip the (slower) per-lake diagnostic plots from
# generate_climatological_climate() — the cross-lake comparison plot at the
# bottom of this script is unaffected either way.
plot_diagnostics <- FALSE

# How far back to pull each lake's long climatology record. Earlier = more
# years pooled per (day-of-year, hour) cell = a more representative "typical
# year" — but only as far back as each lake's met record actually goes
# (prepare_lake_model_inputs(..., n_years = "max") will simply use whatever
# is available after this filter is applied).
climatology_start <- as.POSIXct("2015-01-01")

# Per-lake settings: which 00_ script to source (builds the short
# modeling-period `inputs` that 01_ would run the ice model on).
lake_specs <- list(
  ELB = list(prep_script = "R/ELB/00_ELB_data_preparation.R"),
  WLB = list(prep_script = "R/WLB/00_WLB_data_preparation.R"),
  LH  = list(prep_script = "R/LH/00_LH_data_preparation.R"),
  LF  = list(prep_script = "R/LF/00_LF_data_preparation.R")
)

###################### Run the pipeline for each lake ######################
lake_results <- list()

for (lk in names(lake_specs)) {

  spec <- lake_specs[[lk]]
  message("\n==================== ", lk, " ====================")

  # 1. Build (or rebuild) this lake's short modeling-period inputs. Each 00_
  #    script defines `lake_key`/`inputs`/`station_data`/etc. as globals — we
  #    capture what we need immediately below, before the next lake's
  #    source() overwrites them.
  source(spec$prep_script)
  lake_key  <- lk
  lake_name <- inputs$lake_name

  # 2. Pull a LONG record for this lake (same loading/interpolation logic as
  #    `inputs`, just over a much longer span) and build its mean-annual
  #    "typical year" climatology, tiled forward to horizon_year.
  long_inputs <- prepare_lake_model_inputs(
    lake_key       = lake_key,
    station_data   = station_data,
    airt_primary   = airt_primary,
    airt_secondary = airt_secondary,
    ice_thickness  = ice_thickness,
    albedo_orig    = albedo_orig,
    start_filter   = climatology_start,
    n_years        = "max"
  )

  climate_forecast <- generate_climatological_climate(
    lake_key         = lake_key,
    time_series      = long_inputs$time_series,
    horizon_year     = horizon_year,
    plot_diagnostics = plot_diagnostics
  )

  # 3. Apply the shared warming-rate scenario to the climatological forecast
  #    period and run the ice model on it.
  ts_ready <- prepare_model_input(
    climate_forecast$future_physical,
    warming_rate = warming_rate,
    constants    = lake_constants(lake_key)
  )

  results <- run_ice_model(
    ts_ready,
    constants     = lake_constants(lake_key),
    show_progress = FALSE
  )

  lake_results[[lk]] <- list(
    lake_name        = lake_name,
    climate_forecast = climate_forecast,
    results          = results
  )
}

###################### Assemble a shared comparison table ######################
# Line every lake's forecast up on a common "years since forecast start" axis
# so they can be plotted/compared directly even though each lake's observed
# record (and therefore forecast start date) differs.
comparison_df <- imap(lake_results, function(lr, lk) {
  res <- lr$results
  tibble(
    lake          = lk,
    lake_name     = lr$lake_name,
    time          = res$time,
    years_elapsed = as.numeric(difftime(res$time, min(res$time), units = "days")) / 365.25,
    thickness     = res$thickness
  )
}) |> bind_rows()

# `comparison_df` columns: lake, lake_name, time, years_elapsed, thickness
# — one row per model timestep per lake.

###################### Summary table: mean/min/max thickness per lake, plus ######################
###################### how many years went into each lake's climatology    ######################
summary_table <- comparison_df |>
  group_by(lake, lake_name) |>
  summarise(
    mean_thickness_m = mean(thickness, na.rm = TRUE),
    min_thickness_m  = min(thickness,  na.rm = TRUE),
    max_thickness_m  = max(thickness,  na.rm = TRUE),
    .groups = "drop"
  ) |>
  left_join(
    imap(lake_results, function(lr, lk) tibble(lake = lk, n_years_pooled = lr$climate_forecast$diagnostics$n_years_pooled)) |> bind_rows(),
    by = "lake"
  )

message("\n==================== Forecast ice-thickness summary (", horizon_year,
        " horizon, ", warming_rate * 100, "%/yr warming, climatology from ", format(climatology_start), ") ====================")
print(summary_table)

###################### Comparison plot: all four lakes on one axis ######################
lake_colours <- c(ELB = "#3B8BD4", WLB = "#3BD48B", LH = "#E8593C", LF = "#9B59B6")

comparison_plot <- ggplot(comparison_df, aes(x = years_elapsed, y = thickness, colour = lake)) +
  geom_line(linewidth = 0.6, alpha = 0.85) +
  scale_colour_manual(values = lake_colours, labels = function(x) {
    sapply(x, function(lk) lake_results[[lk]]$lake_name)
  }) +
  labs(
    title    = sprintf("Forecast ice thickness — all four lakes (climatological 'typical year' to %d)", horizon_year),
    subtitle = sprintf("%.1f%% annual warming applied on top of each lake's mean-annual climatology", warming_rate * 100),
    x        = "Years since forecast start",
    y        = "Ice thickness (m)",
    colour   = "Lake"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.position = "bottom")

print(comparison_plot)

###################### Input-data plot: each lake's forcing, side by side ######################
# Before reading too much into *why* the four thickness trajectories differ,
# it helps to see what's actually driving each one. Every lake's forecast run
# above is driven by its own climatological "typical year" — the same
# mean-annual (day-of-year, hour) cycle, pooled from `climatology_start`
# onward, that gets tiled forward into `future_physical`. Plotting that one
# representative annual cycle per lake (rather than the whole tiled,
# multi-decade `future_physical` series, which would just repeat it) makes
# the four lakes' forcing directly comparable at a glance — e.g. does ELB's
# climatological air temperature run colder/warmer than LF's? Is one lake's
# albedo cycle systematically different? Those kinds of input-data
# differences are often the most direct explanation for why the resulting
# ice-thickness trajectories diverge (see also the real-vs-climatology
# sanity check in Synthetic_vs_Observed_Sanity_Check.R, which digs into
# whether each lake's climatology is internally consistent in the first place).
input_vars <- c("T_air", "SW_in", "LWR_in", "LWR_out",
                "albedo", "pressure", "wind", "relative_humidity")

input_var_labels <- c(
  T_air             = "Air temperature (K)",
  SW_in             = "Shortwave in (W m⁻²)",
  LWR_in            = "Longwave in (W m⁻²)",
  LWR_out           = "Longwave out (W m⁻²)",
  albedo            = "Albedo (0–1)",
  pressure          = "Pressure (Pa)",
  wind              = "Wind speed (m s⁻¹)",
  relative_humidity = "Relative humidity (%)"
)

input_data_df <- imap(lake_results, function(lr, lk) {
  lr$climate_forecast$climatology |>
    mutate(day_frac = doy + hour / 24) |>
    select(day_frac, all_of(input_vars)) |>
    mutate(lake = lk, lake_name = lr$lake_name)
}) |> bind_rows() |>
  pivot_longer(cols = all_of(input_vars), names_to = "variable", values_to = "value") |>
  mutate(variable = factor(variable, levels = input_vars, labels = input_var_labels[input_vars]))

# `input_data_df` columns: day_frac (day-of-year + fractional hour), lake,
# lake_name, variable, value — one row per (lake, variable, day-of-year/hour)
# climatological cell. This is the SAME table each lake's own
# `climate_forecast$diagnostics$plots$seasonal_cycle` is built from — here
# we just overlay all four on shared axes instead of faceting one at a time.

input_data_plot <- ggplot(input_data_df, aes(x = day_frac, y = value, colour = lake)) +
  geom_line(linewidth = 0.5, alpha = 0.85) +
  facet_wrap(~variable, scales = "free_y") +
  scale_colour_manual(values = lake_colours, labels = function(x) {
    sapply(x, function(lk) lake_results[[lk]]$lake_name)
  }) +
  labs(
    title    = "Climatological 'typical year' input data — all four lakes",
    subtitle = sprintf("Mean-annual meteorological/albedo cycle (pooled from %s onward) — the forcing each lake's forecast run above is driven by",
                       format(climatology_start, "%Y")),
    x        = "Day of year",
    y        = NULL,
    colour   = "Lake"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

print(input_data_plot)

# To compare under a *different* warming scenario (or a different
# climatology window), just change `warming_rate` (or `horizon_year` /
# `climatology_start`) above and re-run — `lake_results`, `comparison_df`,
# `summary_table`, `comparison_plot`, `input_data_df`, and `input_data_plot`
# will all be rebuilt for the new scenario, with no per-lake code to edit.

