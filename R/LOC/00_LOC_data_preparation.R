######### Model input data prep — The Loch (LOC) ##########
#
# This script loads the raw Loch Vale weather station (LVWS) data that The
# Loch (Loch Vale, Rocky Mountain National Park, CO) needs and hands it to
# prepare_loc_model_inputs(), which applies every Loch-specific choice
# captured in LAKE_CONFIGS$LOC (start date, gap filling, constant albedo,
# Brutsaert LWR_in).
#
# The Loch uses its own prepare function because its forcing comes from a
# single station in a different format, but the returned `inputs` list has
# the same structure as the other lakes (time_series, ice_thickness in the
# MCM-LTER date_time / z_water_m format, time_model, params), so the 01_
# script follows the identical workflow.

source("R/functions/libraries.R")
source("R/functions/functions.R")

lake_key <- "LOC"

# ---- Adjustable run length --------------------------------------------------
# Number of years to run the model for. Set to NULL to use this lake's
# configured default (LAKE_CONFIGS$LOC$n_years == "max", i.e. all LVWS data).
n_years <- NULL

###################### Load raw met station data ######################
# Loch Vale weather station, hourly (UTC): airt, wnd_10, RH, lwrad_net,
# swrad, press.
LVWS <- read_csv("Data/LOC/lvws_met_20170101_20240909.csv",
                 na = c("", "NA", "NaN"), show_col_types = FALSE)

###################### Load ice thickness validation data ######################
# No ice-thickness observations for The Loch yet. When they exist, read them
# here (z_water_m in m, or date + thickness in cm like GL4) and pass them in
# place of NULL below.
loc_ice_raw <- NULL

###################### Assemble model-ready inputs ######################
inputs <- prepare_loc_model_inputs(
  met_data      = LVWS,
  ice_thickness = loc_ice_raw,
  n_years       = n_years
)

# Same alias the other 00_ scripts leave behind: the cleaned, model-period
# observations (empty for now, with the standard columns).
ice_thickness <- inputs$ice_thickness

# `inputs` now contains:
#   inputs$time_series   — model-ready climate time series (no warming applied)
#   inputs$ice_thickness — Loch ice-thickness observations (empty for now;
#                          location_name, location, date_time, z_water_m)
#   inputs$time_model    — model time spine
#   inputs$params        — alpha, r, dt, dx, L_initial, Chi, nt, n_years
#
# See R/LOC/01_LOC_ice_model.R for running and plotting the model.
