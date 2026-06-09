###### Compare multiple warming scenarios — all four lakes, side by side ########

### Authors
# Charlie Dougherty

# NOTES
# This is a sibling to Compare_All_Lakes_Synthetic_Forecast.R, but instead of
# running every lake under ONE shared warming-rate assumption, it runs every
# lake under an ARRAY of warming rates — e.g. warming_rates <- c(0, 0.02, 0.05,
# 0.10) — and lines all (lake x scenario) trajectories up for comparison.
#
# For each lake it:
#   1. Sources that lake's 00_<LAKE>_data_preparation.R  (builds `inputs`)
#   2. Re-runs prepare_lake_model_inputs() with an early start_filter and
#      n_years = "max" to pull a LONG record, then calls
#      generate_climatological_climate() ONCE to build that lake's mean-annual
#      "typical year" climatology and tile it forward to `horizon_year`
#      -- this step is the slow one, and it does NOT depend on warming_rate,
#      so it only needs to run once per lake, not once per (lake, scenario)
#   3. For EACH warming rate in `warming_rates`, applies that rate to the SAME
#      climatological forecast period via prepare_model_input(), runs
#      run_ice_model(), and stores the resulting ice-thickness trajectory
#
# It then assembles every (lake, warming_rate) trajectory into one long-format
# table, plots them faceted by lake / coloured by warming rate, and prints a
# summary table of final / mean / min / max thickness and total drift for
# every (lake, warming_rate) combination.
#
# Adjust `horizon_year`, `warming_rates`, and `climatology_start` below to
# explore different sets of "what if" warming scenarios across all four lakes
# at once. This is a thin orchestration layer over the lake-agnostic functions
# in R/TEST_Optimizations/functions.R — no lake-specific modeling code lives
# here.

source("R/TEST_Optimizations/libraries.R")
source("R/TEST_Optimizations/functions.R")

###################### Scenario assumptions ######################
# How far forward (calendar year) to tile each lake's climatology out to.
horizon_year <- 2100

# THE ARRAYS: every combination of (warming_rate, albedo_rate) gets run for
# every lake. Both follow the same linear-trend structure inside
# prepare_model_input():
#   T_air  = T_air  + warming_rate * (year - baseline_year)
#   albedo = albedo + albedo_rate  * (year - baseline_year)  [clamped to 0-1]
#
# warming_rate: K/yr added to T_air.
#   0    = no extra warming beyond the climatological baseline
#   +ve  = warming; -ve = cooling
#
# albedo_rate: unitless/yr added to albedo.
#   0    = no trend (albedo stays at the bootstrapped/climatological cycle)
#   +ve  = albedo increasing over time (more reflective -> less melt)
#   -ve  = albedo decreasing over time (darker surface -> more melt)
#
# To run every combination of the two arrays, set both; to vary only one
# dimension (e.g. just warming, no albedo trend), set albedo_rates <- c(0).
warming_rates <- c(0.00, 0.05)
albedo_rates  <- c(0.00, -0.05)   # set to e.g. c(0.00, -0.005) to layer albedo trends

# Set to FALSE to skip the (slower) per-lake diagnostic plots from
# generate_climatological_climate() -- this script's own comparison plots are
# unaffected either way.
plot_diagnostics <- FALSE

# How far back to pull each lake's long climatology record (see
# Compare_All_Lakes_Synthetic_Forecast.R for the full rationale).
climatology_start <- as.POSIXct("2017-01-01")

# Per-lake settings: which 00_ script to source (builds the short
# modeling-period `inputs` that 01_ would run the ice model on).
lake_specs <- list(
  ELB = list(prep_script = "R/ELB/00_ELB_data_preparation.R"),
  WLB = list(prep_script = "R/WLB/00_WLB_data_preparation.R"),
  LH  = list(prep_script = "R/LH/00_LH_data_preparation.R"),
  LF  = list(prep_script = "R/LF/00_LF_data_preparation.R")
)

###################### Step 1: build each lake's climatological forecast ONCE ######################
# `climate_forecast$future_physical` does not depend on warming_rate -- the
# warming trend is applied downstream, inside prepare_model_input(). So the
# expensive long-record load + climatology build happens exactly once per
# lake here, and gets reused for every warming-rate scenario in Step 2 below.
lake_climates <- list()

for (lk in names(lake_specs)) {

  spec <- lake_specs[[lk]]
  message("\n==================== Building climatology: ", lk, " ====================")

  source(spec$prep_script)
  lake_key  <- lk
  lake_name <- inputs$lake_name

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

  lake_climates[[lk]] <- list(
    lake_name        = lake_name,
    climate_forecast = climate_forecast
  )
}

###################### Step 2: run every (lake x warming_rate x albedo_rate) combination ######################
scenario_results <- list()

for (lk in names(lake_climates)) {

  lc <- lake_climates[[lk]]

  for (wr in warming_rates) {
    for (ar in albedo_rates) {

      message(sprintf("Running %s @ warming_rate = %.3f K/yr, albedo_rate = %.4f /yr ...", lk, wr, ar))

      ts_ready <- prepare_model_input(
        lc$climate_forecast$future_physical,
        warming_rate = wr,
        albedo_rate  = ar,
        constants    = lake_constants(lk)
      )

      results <- run_ice_model(
        ts_ready,
        constants     = lake_constants(lk),
        show_progress = FALSE
      )

      scenario_key <- paste(lk, sprintf("%.3f", wr), sprintf("%.4f", ar), sep = "_")
      scenario_results[[scenario_key]] <- list(
        lake         = lk,
        lake_name    = lc$lake_name,
        warming_rate = wr,
        albedo_rate  = ar,
        results      = results
      )
    }
  }
}
###################### Assemble a shared comparison table ######################
# One row per model timestep per (lake, warming_rate) scenario. `years_elapsed`
# lines every scenario up on a common "years since forecast start" axis so they
# can be plotted/compared directly even though each lake's forecast-start date
# differs (it's tied to where that lake's observed record ends).
scenario_df <- imap(scenario_results, function(sr, key) {
  res <- sr$results
  tibble(
    lake          = sr$lake,
    lake_name     = sr$lake_name,
    warming_rate  = sr$warming_rate,
    albedo_rate   = sr$albedo_rate,
    scenario      = sprintf("T+%.2f / α%+.4f", sr$warming_rate, sr$albedo_rate),
    time          = res$time,
    years_elapsed = as.numeric(difftime(res$time, min(res$time), units = "days")) / 365.25,
    thickness     = res$thickness
  )
}) |> bind_rows()

# `scenario_df` columns: lake, lake_name, warming_rate, scenario, time,
# years_elapsed, thickness — one row per model timestep per (lake, rate).

###################### Summary table: how does final/mean/min/max thickness ######################
###################### and total drift change across warming rates, per lake ######################
scenario_summary <- scenario_df |>
  group_by(lake, lake_name, warming_rate, albedo_rate) |>
  summarise(
    initial_thickness_m = first(thickness),
    final_thickness_m   = last(thickness),
    drift_m             = last(thickness) - first(thickness),
    mean_thickness_m    = mean(thickness, na.rm = TRUE),
    min_thickness_m     = min(thickness,  na.rm = TRUE),
    max_thickness_m     = max(thickness,  na.rm = TRUE),
    .groups = "drop"
  ) |>
  arrange(lake, warming_rate, albedo_rate)

message("\n==================== Warming-scenario summary (", horizon_year,
        " horizon, climatology from ", format(climatology_start), ") ====================")
message("warming_rate is in Kelvin/year added to T_air, compounding with elapsed forecast time")
print(scenario_summary, n = Inf)

###################### Comparison plot: every lake, every warming rate ######################
# Facet by lake (so each lake's own dynamics are easy to read), colour by
# warming rate (a perceptually-ordered sequential palette, since warming_rate
# is itself an ordered quantity -- "more red = more warming").
lake_colours <- c(ELB = "#3B8BD4", WLB = "#3BD48B", LH = "#E8593C", LF = "#9B59B6")

scenario_plot <- ggplot(scenario_df,
                        aes(x = years_elapsed, y = thickness,
                            colour = factor(warming_rate),  group = scenario)) +
  geom_line(linewidth = 0.6, alpha = 0.85) +
  facet_wrap(~lake_name, scales = "free_y") +
  scale_colour_viridis_d(name = "Warming rate\n(K/yr)", option = "plasma", end = 0.85) +
  labs(
    title    = sprintf("Forecast ice thickness under multiple warming scenarios — all four lakes (to %d)", horizon_year),
    subtitle = "",
    x        = "Years since forecast start",
    y        = "Ice thickness (m)"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.position = "bottom")

print(scenario_plot)

###################### Companion plot: final-thickness sensitivity to warming rate ######################
# A compact "how much does the END STATE move per unit of warming" view --
# one line per lake, x = warming rate, y = final thickness. Useful for seeing
# at a glance which lakes are most/least sensitive to the warming assumption.
sensitivity_plot <- scenario_summary |>
  ggplot(aes(x = warming_rate, y = final_thickness_m, colour = lake)) +
  geom_line(linewidth = 0.7) +
  geom_point(size = 2) +
  scale_colour_manual(values = lake_colours, labels = function(x) {
    sapply(x, function(lk) lake_climates[[lk]]$lake_name)
  }) +
  labs(
    title = sprintf("Final ice thickness (at %d) vs. assumed warming rate", horizon_year),
    x     = "Warming rate (K/yr added to T_air)",
    y     = "Final ice thickness (m)",
    colour = "Lake"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.position = "bottom")

print(sensitivity_plot)

# To explore a different set of scenarios (or a different forecast horizon /
# climatology window), just change `warming_rates` (or `horizon_year` /
# `climatology_start`) above and re-run -- `lake_climates`, `scenario_results`,
# `scenario_df`, `scenario_summary`, `scenario_plot`, and `sensitivity_plot`
# will all be rebuilt, with no per-lake or per-scenario code to edit.
