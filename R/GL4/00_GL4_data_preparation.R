######### Model input data prep — Green Lake 4 (GL4) ##########
#
# This script loads the raw D1 met station and ice-thickness data that Green
# Lake 4 (Niwot Ridge, CO) needs and hands them to prepare_gl4_model_inputs(),
# which applies every GL4-specific choice captured in LAKE_CONFIGS$GL4 (start
# date, sensor coalescing, gap filling, constant albedo, Brutsaert LWR_in).
#
# GL4 uses its own prepare function because its forcing comes from a single
# NWT LTER station in a different format, but the returned `inputs` list has
# the same structure as the Antarctic lakes (time_series, ice_thickness in the
# MCM-LTER date_time / z_water_m format, time_model, params), so the 01_ script
# follows the identical workflow.

source("R/functions/libraries.R")
source("R/functions/functions.R")

lake_key <- "GL4"

# ---- Adjustable run length --------------------------------------------------
# Number of years to run the model for. Set to NULL to use this lake's
# configured default (LAKE_CONFIGS$GL4$n_years == "max", i.e. all D1 data).
n_years <- NULL

###################### Load raw met station data ######################
# NWT LTER D1 station, 10-minute CR1000 logger data (see LAKE_CONFIGS$GL4).
D1 <- read_csv("Data/GL4/d-1cr23x-cr1000.10minute.ml.data.csv",
               na = c("", "NA", "NaN"), show_col_types = FALSE)

###################### Load ice thickness validation data ######################
# NWT LTER GL4 ice thickness (cm). Reformatted inside
# prepare_gl4_model_inputs() to the MCM-LTER schema (date_time, z_water_m in m).
gl4_ice_raw <- read_csv("Data/GL4/gl4_ice_thickness.nc.data.csv",
                        show_col_types = FALSE)

###################### Assemble model-ready inputs ######################
inputs <- prepare_gl4_model_inputs(
  met_data      = D1,
  ice_thickness = gl4_ice_raw,
  n_years       = n_years
)

# Same alias the Antarctic 00_ scripts leave behind: the cleaned, model-period
# observations (date_time, z_water_m) — NOT the raw cm file.
ice_thickness <- inputs$ice_thickness

# `inputs` now contains:
#   inputs$time_series   — model-ready climate time series (no warming applied)
#   inputs$ice_thickness — GL4 ice-thickness validation observations
#                          (location_name, location, date_time, z_water_m)
#   inputs$time_model    — model time spine
#   inputs$params        — alpha, r, dt, dx, L_initial, Chi, nt, n_years
#
# See R/GL4/01_GL4_ice_model.R for running and plotting the model.
