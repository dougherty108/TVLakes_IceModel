###### Ice Thickness Model — Green Lake 4 (GL4) ########

### Authors
# Charlie Dougherty

# NOTES
# This script models ice thickness at an adjustable vertical depth and timestep
# through time at Green Lake 4, Niwot Ridge, Colorado. Ice thickness is
# modeled by solving the heat equation in the vertical axis iteratively, and
# correcting for surface/bottom mass balance via the surface energy fluxes.
#
# GL4 is seasonally frozen (LAKE_CONFIGS$GL4$seasonally_frozen = TRUE), so
# run_ice_model() switches between an "ice" phase and an "open_water"
# mixed-layer phase that nucleates new ice in autumn. Results therefore carry
# two extra columns vs the Antarctic lakes: `phase` and `T_water`.
#
# Data is provided by the Niwot Ridge Long Term Ecological Research project
# (D1 met station and GL4 ice thickness).
#
# This driver is a thin wrapper around the lake-agnostic functions in
# R/functions/functions.R: prepare_model_input(), run_ice_model(),
# lake_constants(), and plot_ice_model(). All GL4-specific choices live in
# LAKE_CONFIGS$GL4 and were already applied when `inputs` was built in
# 00_GL4_data_preparation.R.

source("R/functions/libraries.R")
source("R/functions/functions.R")

lake_key <- "GL4"

# Build (or rebuild) the model-ready inputs. Adjust `n_years` in
# 00_GL4_data_preparation.R to change how many years the model runs for.
source("R/GL4/00_GL4_data_preparation.R")

###################### Apply warming trend (observed pathway) ######################
# Set warming_rate = 0 for no trend, or > 0 to apply a compounding annual
# warming trend to T_air (and recompute LWR_out / delta_T as needed).
warming_rate <- 0.000   # 0.3% per year

ts_ready_GL4 <- prepare_model_input(
  inputs$time_series,
  warming_rate = warming_rate,
  constants    = lake_constants(lake_key)
)

###################### Run the ice thickness model ######################
results_GL4 <- run_ice_model(
  ts_ready_GL4,
  constants = lake_constants(lake_key)
)

###################### Plot results vs. observations ######################
plot_ice_model(
  results_GL4,
  ice_thickness = inputs$ice_thickness,
  title         = inputs$lake_name,
  subtitle      = sprintf("%.1f-year run | %.1f%% annual warming applied to T_air",
                          inputs$params$n_years, warming_rate * 100)
)

# write output to model_outputs folder
#write_csv(results_GL4, "Data/model_outputs/GL4_2014_2025_output.csv")

# quick plot to compare modeled ice thickness to measured ice thickness
results_GL4_v2 = results_GL4 |> 
  mutate(date_time = time)

GL4_ice = read_csv("Data/GL4/gl4_ice_thickness.nc.data.csv") |> 
  mutate(date_time = as.POSIXct(mdy(date_time), tz = "UTC"))

gl4_overlap = GL4_ice |> 
  left_join(results_GL4_v2, by = join_by(date_time)) |> 
  mutate(month = month(date_time)) |> 
  drop_na(time)

ggplot(gl4_overlap, aes(thickness.x / 100, thickness.y)) + 
  geom_point(aes(color = as.character(month))) + 
  #geom_smooth(method = "lm") + 
  xlab("NWT Measured Ice Thickness (m)") + ylab("Modeled Ice Thickness (m)") + 
  ggtitle("Modeled Ice Thickness vs. Measured Ice Thickness") + 
  geom_abline(intercept = 0, slope = 1, color = "red", linetype = "dashed", linewidth = 1) + 
  theme_bw()
