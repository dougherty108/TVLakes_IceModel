######### Model input data prep — West Lake Bonney (WLB) ##########
#
# This script loads the raw station, air-temperature, ice-thickness, and
# albedo data that West Lake Bonney needs and hands them to
# prepare_lake_model_inputs(), which applies every WLB-specific choice
# captured in LAKE_CONFIGS (start date, station combination, air-temperature
# gap-fill pair, albedo/ice filters, clear-sky shortwave fallback, etc).
#
# To run a different lake, change `lake_key` and the stations/files loaded
# below — the modeling code in functions.R does not need to change.

source("R/TEST_Optimizations/libraries.R")
source("R/TEST_Optimizations/functions.R")
library(suncalc)   # WLB gap-fills shortwave with a clear-sky sun-angle estimate

lake_key <- "WLB"

# ---- Adjustable run length --------------------------------------------------
# Number of years to run the model for. Set to NULL to use this lake's
# configured default (LAKE_CONFIGS$WLB$n_years == 6.95). Override here to run
# the model for a longer or shorter period (e.g. forecasting experiments).
n_years <- NULL

###################### Load raw met station data ######################
# Met station data is published by the McMurdo Dry Valleys LTER / EDI.
# WLB needs: BOYM, HOEM, COHM, TARM (see LAKE_CONFIGS$WLB$stations_needed).
# Raw, unfiltered tibbles are passed in — prepare_lake_model_inputs() parses
# date_time and applies the lake-specific start-date filter internally.
met_dir <- "~/Library/CloudStorage/OneDrive-UCB-O365/Documents/MCM-LTER_Met/met stations"

BOYM <- read_csv(file.path(met_dir, "mcmlter-clim_boym_15min-20250205.csv"))
HOEM <- read_csv(file.path(met_dir, "mcmlter-clim_hoem_15min-20250205.csv"))
COHM <- read_csv(file.path(met_dir, "mcmlter-clim_cohm_15min-20250205.csv"))
TARM <- read_csv(file.path(met_dir, "mcmlter-clim_tarm_15min-20250205.csv"))

station_data <- list(BOYM = BOYM, HOEM = HOEM, COHM = COHM, TARM = TARM)

###################### Load primary/secondary air-temperature data ######################
# WLB air temperature is sourced from the West Lake Bonney Blue Box (WLBBB),
# gap-filled with the East Lake Bonney Blue Box (ELBBB).
airt_primary   <- read_csv("Data/air_temp_WLBBB.csv")
airt_secondary <- read_csv("Data/air_temp_ELBBB.csv")

###################### Load ice thickness validation + albedo data ######################
ice_thickness <- read_csv("Data/mcmlter-lake-ice_thickness-20250218_0_2025.csv")
albedo_orig   <- read_csv("Data/AlbedoModel.csv")

###################### Assemble model-ready inputs ######################
# Note: WLB's shortwave radiation is gap-filled with a clear-sky estimate
# derived from sun angle (LAKE_CONFIGS$WLB$shortwave$use_artificial == TRUE),
# and its ice-thickness validation data is restricted to the "Inside" mooring
# (LAKE_CONFIGS$WLB$ice_loc_filter) — both handled internally below.
inputs <- prepare_lake_model_inputs(
  lake_key       = lake_key,
  station_data   = station_data,
  airt_primary   = airt_primary,
  airt_secondary = airt_secondary,
  ice_thickness  = ice_thickness,
  albedo_orig    = albedo_orig,
  n_years        = n_years
)

# `inputs` now contains:
#   inputs$time_series   — model-ready climate time series (no warming applied)
#   inputs$ice_thickness — WLB ice-thickness validation observations (Inside mooring)
#   inputs$time_model    — model time spine
#   inputs$params        — alpha, r, dt, dx, L_initial, Chi, nt, n_years
#
# See R/WLB/01_WLB_ice_thickness_model.R for running and plotting the model.
