###### Climatological forecasting — West Lake Bonney (WLB) ########

### Authors
# Charlie Dougherty

# NOTES
# This script builds a "typical year" synthetic climate + albedo record for
# West Lake Bonney from a MEAN ANNUAL CLIMATOLOGY — i.e. for each (day-of-year,
# hour) it averages that same timestep-of-year across every year in WLB's
# full available met record (back into the 1990s, not just the short
# 2016/2017-onward window the ice model itself runs over) — and then simply
# repeats that climatological cycle forward as the forecast-period climate.
#
# This is the same approach used for ELB/LH/LF (replacing an earlier
# VAR-bootstrap forecasting design): instead of stochastically simulating
# year-to-year variability, we use the long-run "typical year" directly.
# That trades away some realistic variability for a much longer observational
# basis, simplicity, and transparency — a clean, low-noise baseline to layer
# climate scenarios on top of.
#
# The goal is unchanged: produce a realistic meteorological + albedo baseline
# that different climate scenarios (warming trends, offsets, etc. — see
# build_climate_scenario() / prepare_model_input()) can be layered onto, so
# we can see how WLB ice thickness responds to those scenarios.
#
# This driver is a thin wrapper around the lake-agnostic
# generate_climatological_climate() function in
# R/TEST_Optimizations/functions.R. All the climatology-building / tiling
# machinery lives there; only WLB-specific choices are made here.

source("R/TEST_Optimizations/libraries.R")
source("R/TEST_Optimizations/functions.R")

lake_key <- "WLB"

# Build (or rebuild) the model-ready inputs `inputs` that 01_ runs the ice
# model on. Adjust `n_years` in 00_WLB_data_preparation.R to change how many
# years the ice MODEL runs for — that is independent of the long climatology
# record built below.
source("R/WLB/00_WLB_data_preparation.R")

###################### Build a LONG record for the climatology ######################
# generate_climatological_climate() needs as much observed history as
# possible (the more years it can pool per (day-of-year, hour) cell, the
# more representative the "typical year" is). We re-run
# prepare_lake_model_inputs() with an early start_filter and n_years = "max"
# so it pulls and gap-fills WLB's entire available station record — using
# exactly the same lake-specific loading/interpolation logic as `inputs`
# above, just over a much longer span.
#
# NOTE: this re-loads/re-interpolates the full record and can take a little
# while longer than the normal (short) `inputs` build.
climatology_start <- as.POSIXct("1990-01-01")

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

###################### Adjustable forecasting choices ######################
# How far forward (calendar year) to tile the climatology out to.
horizon_year <- 2037

# Set to FALSE to skip the (slower) density / seasonal-cycle diagnostic plots.
plot_diagnostics <- TRUE

###################### Build the climatology + forecast ######################
climate_forecast <- generate_climatological_climate(
  lake_key         = lake_key,
  time_series      = long_inputs$time_series,
  horizon_year     = horizon_year,
  plot_diagnostics = plot_diagnostics
)

# `climate_forecast` now contains:
#   climate_forecast$climatology      — mean-annual cycle by (doy, hour),
#                                        plus per-cell SDs and the number of
#                                        distinct observed years pooled
#   climate_forecast$synthetic        — historical-period record reconstructed
#                                        from the climatology (same span as
#                                        long_inputs$time_series)
#   climate_forecast$future_physical  — forecast-period climate: the
#                                        climatology tiled forward from the
#                                        end of the long record out to
#                                        horizon_year
#   climate_forecast$diagnostics      — years pooled, record span, and
#                                        (if requested) comparison plots
#
# To explore "what if" climate scenarios on top of this typical-year
# baseline, pass climate_forecast$future_physical into
# build_climate_scenario() / prepare_model_input() and then run_ice_model()
# — e.g.:
#
#   scenario_ts <- prepare_model_input(
#     climate_forecast$future_physical,
#     warming_rate = 0.01,
#     constants    = lake_constants(lake_key)
#   )
#   scenario_results <- run_ice_model(scenario_ts, constants = lake_constants(lake_key))
#   plot_ice_model(scenario_results, title = inputs$lake_name,
#                  subtitle = sprintf("Forecast to %d | climatological 'typical year' + 1%% annual warming", horizon_year))

if (isTRUE(plot_diagnostics) && !is.null(climate_forecast$diagnostics$plots)) {
  print(climate_forecast$diagnostics$plots$seasonal_cycle)
}
