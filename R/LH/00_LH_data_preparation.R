######### Model input data prep — Lake Hoare (LH) ##########
#
# This script loads the raw station, air-temperature, ice-thickness, and
# albedo data that Lake Hoare needs and hands them to
# prepare_lake_model_inputs(), which applies every LH-specific choice
# captured in LAKE_CONFIGS (start date, station combination, air-temperature
# gap-fill pair, albedo/ice filters, clear-sky shortwave fallback, etc).
#
# To run a different lake, change `lake_key` and the stations/files loaded
# below — the modeling code in functions.R does not need to change.

source("R/TEST_Optimizations/libraries.R")
source("R/TEST_Optimizations/functions.R")
library(suncalc)   # LH gap-fills shortwave with a clear-sky sun-angle estimate

lake_key <- "LH"

# ---- Adjustable run length --------------------------------------------------
# Number of years to run the model for. Set to NULL to use this lake's
# configured default (LAKE_CONFIGS$LH$n_years == 6.95). Override here to run
# the model for a longer or shorter period (e.g. forecasting experiments).
n_years <- NULL

###################### Load raw met station data ######################
# Met station data is published by the McMurdo Dry Valleys LTER / EDI.
# LH needs: HOEM, COHM, TARM, FRLM (see LAKE_CONFIGS$LH$stations_needed).
# Raw, unfiltered tibbles are passed in — prepare_lake_model_inputs() parses
# date_time and applies the lake-specific start-date filter internally.
met_dir <- "~/Library/CloudStorage/OneDrive-UCB-O365/Documents/MCM-LTER_Met/met stations"

HOEM <- read_csv(file.path(met_dir, "mcmlter-clim_hoem_15min-20250205.csv"))
COHM <- read_csv(file.path(met_dir, "mcmlter-clim_cohm_15min-20250205.csv"))
TARM <- read_csv(file.path(met_dir, "mcmlter-clim_tarm_15min-20250205.csv"))
FRLM <- read_csv(file.path(met_dir, "mcmlter-clim_frlm_15min-20250205.csv"))

station_data <- list(HOEM = HOEM, COHM = COHM, TARM = TARM, FRLM = FRLM)

###################### Load primary/secondary air-temperature data ######################
# LH air temperature is sourced from the Lake Hoare Blue Box (LHBB),
# gap-filled with the Lake Fryxell Blue Box (LFBB).
airt_primary   <- read_csv("Data/air_temp_LHBB.csv")
airt_secondary <- read_csv("Data/air_temp_LFBB.csv")

###################### Load ice thickness validation + albedo data ######################
ice_thickness <- read_csv("Data/mcmlter-lake-ice_thickness-20250218_0_2025.csv")
albedo_orig   <- read_csv("Data/AlbedoModel.csv")

###################### Assemble model-ready inputs ######################
# Note: LH's shortwave radiation is gap-filled with a clear-sky estimate
# derived from sun angle (LAKE_CONFIGS$LH$shortwave$use_artificial == TRUE) —
# handled internally below.
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
#   inputs$ice_thickness — Lake Hoare ice-thickness validation observations
#   inputs$time_model    — model time spine
#   inputs$params        — alpha, r, dt, dx, L_initial, Chi, nt, n_years
#
# See R/LH/01_LH_ice_thickness_model.R for running and plotting the model.
