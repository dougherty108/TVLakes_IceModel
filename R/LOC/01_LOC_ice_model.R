###### Ice Thickness Model — The Loch (LOC) ########

### Authors
# Charlie Dougherty

# NOTES
# This script models ice thickness at an adjustable vertical depth and timestep
# through time at The Loch, Loch Vale, Rocky Mountain National Park, Colorado.
# Ice thickness is modeled by solving the heat equation in the vertical axis
# iteratively, and correcting for surface/bottom mass balance via the surface
# energy fluxes.
#
# The Loch is seasonally frozen (LAKE_CONFIGS$LOC$seasonally_frozen = TRUE),
# so run_ice_model() switches between an "ice" phase and an "open_water"
# mixed-layer phase that nucleates new ice in autumn. Results carry two extra
# columns vs the Antarctic lakes: `phase` and `T_water`, which give the
# modelled ice-on / ice-off dates.
#
# Forcing data: Loch Vale weather station (LVWS). There are no ice-thickness
# observations for The Loch yet, so the plot shows the model only.
#
# This driver is a thin wrapper around the lake-agnostic functions in
# R/TEST_Optimizations/functions.R: prepare_model_input(), run_ice_model(),
# lake_constants(), and plot_ice_model(). All Loch-specific choices live in
# LAKE_CONFIGS$LOC and were already applied when `inputs` was built in
# 00_LOC_data_preparation.R.

source("R/TEST_Optimizations/libraries.R")
source("R/TEST_Optimizations/functions.R")

lake_key <- "LOC"

# Build (or rebuild) the model-ready inputs. Adjust `n_years` in
# 00_LOC_data_preparation.R to change how many years the model runs for.
source("R/LOC/00_LOC_data_preparation.R")

###################### Apply warming trend (observed pathway) ######################
# Set warming_rate = 0 for no trend, or > 0 to apply a compounding annual
# warming trend to T_air (and recompute LWR_out / delta_T as needed).
warming_rate <- 0.000   # 0.3% per year

ts_ready_LOC <- prepare_model_input(
  inputs$time_series,
  warming_rate = warming_rate,
  constants    = lake_constants(lake_key)
)

###################### Run the ice thickness model ######################
results_LOC <- run_ice_model(
  ts_ready_LOC,
  constants = lake_constants(lake_key)
)

###################### Plot results vs. observations ######################
plot_ice_model(
  results_LOC,
  ice_thickness = inputs$ice_thickness,   # empty until Loch observations exist
  title         = inputs$lake_name,
  subtitle      = sprintf("%.1f-year run | %.1f%% annual warming applied to T_air",
                          inputs$params$n_years, warming_rate * 100)
)

# write output to model_outputs folder
write_csv(results_LOC, "Data/model_outputs/LOC_2017_2024_output.csv")
