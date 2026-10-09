###### Ice Thickness Model — Lake Fryxell (LF) ########

### Authors
# Charlie Dougherty

# NOTES
# This script models ice thickness at an adjustable vertical depth and timestep
# through time at Lake Fryxell, Taylor Valley, Antarctica. Ice thickness is
# modeled by solving the heat equation in the vertical axis iteratively, and
# correcting for surface/bottom mass balance via the surface energy fluxes.
#
# This driver is a thin wrapper around the lake-agnostic functions in
# R/functions/functions.R: prepare_model_input(), run_ice_model(),
# lake_constants(), and plot_ice_model(). All LF-specific choices live in
# LAKE_CONFIGS$LF and were already applied when `inputs` was built in
# 00_LF_data_preparation.R.
#
# NOTE: the legacy LF data-prep ran the model for 20 years while the other
# three lakes ran for 6.95. LAKE_CONFIGS$LF$n_years is currently set to 6.95
# for consistency — set n_years in 00_LF_data_preparation.R if you want to
# reproduce the original 20-year run.

source("R/functions/libraries.R")
source("R/functions/functions.R")

lake_key <- "LF"

# Build (or rebuild) the model-ready inputs. Adjust `n_years` in
# 00_LF_data_preparation.R to change how many years the model runs for.
source("R/LF/00_LF_data_preparation.R")

###################### Apply warming trend (observed pathway) ######################
# Set warming_rate = 0 for no trend, or > 0 to apply a compounding annual
# warming trend to T_air (and recompute LWR_out / delta_T as needed).
warming_rate <- 0.000   # adjustable

ts_ready_LF <- prepare_model_input(
  inputs$time_series,
  warming_rate = warming_rate,
  constants    = lake_constants(lake_key)
)

###################### Run the ice thickness model ######################
results_LF <- run_ice_model(
  ts_ready_LF,
  constants = lake_constants(lake_key)
)

###################### Plot results vs. observations ######################
plot_ice_model(
  results_LF,
  ice_thickness = inputs$ice_thickness,
  title         = inputs$lake_name,
  subtitle      = sprintf("%.1f-year run | %.1f%% annual warming applied to T_air",
                          inputs$params$n_years, warming_rate * 100)
)

# write output to model_outputs folder
write_csv(results_LF, "Data/model_outputs/LF_2017_2024_output.csv")
