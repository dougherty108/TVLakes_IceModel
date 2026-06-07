###### Ice Thickness Model — West Lake Bonney (WLB) ########

### Authors
# Charlie Dougherty

# NOTES
# This script models ice thickness at an adjustable vertical depth and timestep
# through time at West Lake Bonney, Taylor Valley, Antarctica. Ice thickness is
# modeled by solving the heat equation in the vertical axis iteratively, and
# correcting for surface/bottom mass balance via the surface energy fluxes.
#
# This driver is a thin wrapper around the lake-agnostic functions in
# R/TEST_Optimizations/functions.R: prepare_model_input(), run_ice_model(),
# lake_constants(), and plot_ice_model(). All WLB-specific choices live in
# LAKE_CONFIGS$WLB and were already applied when `inputs` was built in
# 00_WLB_data_preparation.R.
 
source("R/TEST_Optimizations/libraries.R")
source("R/TEST_Optimizations/functions.R")

lake_key <- "WLB"

# Build (or rebuild) the model-ready inputs. Adjust `n_years` in
# 00_WLB_data_preparation.R to change how many years the model runs for.
source("R/WLB/00_WLB_data_preparation.R")

###################### Apply warming trend (observed pathway) ######################
# Set warming_rate = 0 for no trend, or > 0 to apply a compounding annual
# warming trend to T_air (and recompute LWR_out / delta_T as needed).
warming_rate <- 0.000   # 0.3% per year

ts_ready <- prepare_model_input(
  inputs$time_series,
  warming_rate = warming_rate,
  constants    = lake_constants(lake_key)
)

###################### Run the ice thickness model ######################
results <- run_ice_model(
  ts_ready,
  constants = lake_constants(lake_key)
)

###################### Plot results vs. observations ######################
plot_ice_model(
  results,
  ice_thickness = inputs$ice_thickness,
  title         = inputs$lake_name,
  subtitle      = sprintf("%.1f-year run | %.1f%% annual warming applied to T_air",
                          inputs$params$n_years, warming_rate * 100)
)
