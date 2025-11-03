
# Load necessary libraries
library(tidyverse)
library(lubridate)
library(progress)
library(suncalc) # for sun angle estimates


#set working directory
setwd("~chdo4929")


###################### Load Time Series Data by Station ######################
# met station data can be found at the McMurdo Long Term Ecological Research website or on the Environmental Data Initiative

HOEM <- read_csv("~/Library/CloudStorage/OneDrive-UCB-O365/Documents/MCM-LTER_Met/met stations/mcmlter-clim_hoem_15min-20250205.csv") |> 
  mutate(date_time = ymd_hms(date_time)) |> 
  filter(date_time > '2016-12-11 00:00:00') |> 
  mutate(airtemp_3m_K = airtemp_3m_degc + 273.15)

COHM <- read_csv("~/Library/CloudStorage/OneDrive-UCB-O365/Documents/MCM-LTER_Met/met stations/mcmlter-clim_cohm_15min-20250205.csv") |> 
  mutate(date_time = ymd_hms(date_time)) |> 
  filter(date_time > '2016-12-11 00:00:00')

TARM <- read_csv("~/Library/CloudStorage/OneDrive-UCB-O365/Documents/MCM-LTER_Met/met stations/mcmlter-clim_tarm_15min-20250205.csv") |> 
  mutate(date_time = ymd_hms(date_time)) |> 
  filter(date_time > '2016-12-11 00:00:00') |> 
  mutate(airtemp_3m_K = airtemp_3m_degc + 273.15)

FRLM <- read_csv("~/Library/CloudStorage/OneDrive-UCB-O365/Documents/MCM-LTER_Met/met stations/mcmlter-clim_frlm_15min-20250205.csv") |> 
  mutate(date_time = ymd_hms(date_time)) |> 
  filter(date_time > '2016-12-11 00:00:00') |> 
  mutate(airtemp_3m_K = airtemp_3m_degc + 273.15)

EXEM <-  read_csv("~/Library/CloudStorage/OneDrive-UCB-O365/Documents/MCM-LTER_Met/met stations/mcmlter-clim_exem_15min-20250205.csv") |> 
  mutate(date_time = ymd_hms(date_time)) |> 
  filter(date_time > '2016-12-11 00:00:00') |> 
  mutate(airtemp_3m_K = airtemp_3m_degc + 273.15)

###################### Define Parameters ######################
L_initial <- 4.60       # Initial ice thickness (m) Ice thickness at 12/17/2016 ice to ice
dx <- 0.10              # Spatial step size (m)
nx = L_initial/dx       # Number of spatial steps
dt <-  1/24             # Time step for stability (in days)
nt <- (1/dt)*6.95*365.   # Number of time steps

sigma = 5.67e-8         # stefan boltzman constant
R = 8.314462            # Universal gas constant kg⋅m^2⋅s^-2⋅K^-1⋅mol^-1
Ma = 28.97              # Molecular Weight of Air kg/mol
Ca = 1.004              # Specific heat capacity of air J/g*K
Ch = 1.75e-3            # bulk transfer coefficient as defined in 1979 Parkinson and Washington
Ce = 1.75e-3            # bulk transfer coefficient as defined in 1979 Parkinson and Washington

epsilon = 0.97          # surface emissivity (for estimating LW if we ever get there)
S = 1367                # solar constant W m^-2
Tf = 273.16             # Temperature of water freezing (K)
xLv = 2.500e6           # Latent Heat of Evaporation (J/kg)
xLf = 3.34e5            # Latent Heat of Fusion (J/kg)

xLs = xLv + xLf         # Latent Heat of Sublimation
k <- 2.3                # Thermal conductivity of ice (W/m/K)
rho <- 917              # Density of ice (kg/m^3)
c <- 2100               # Specific heat capacity of ice (J/kg/K)
alpha <- k / (rho * c)  # Thermal diffusivity (m^2/s)
L_f <- xLf  
Chi = 0.4               # Solar Absorption constant (adustable)             


# Stability check: Ensure R < 0.5 for stability
r <- alpha * (dt * 86400) / dx^2  # dt is in days, so multiply by 86400 to convert to seconds
if (r > 0.5) stop("r > 0.5, solution may be unstable. Reduce dt or dx.")

###################### Separate data out into input parameters ######################
#preemptively set working directory back 
setwd("~/Documents/R-Repositories/TVLakes_IceModel")

# select air temperature data from Lake Bonney Met, and gapfill holes with Lake Hoare
# this step is mainly to gather a time series for gap filling other portions of the script. Air temperature data is sourced 
# the East Lake Bonney Permanent Monitoring Station (ELBBB)

###################### AIR TEMPERATURE DATA ######################
## load air temperature data from East Lake Bonney Lake Monitoring Station (unpublished data)

#time_model = start_time + seq(0, by = dt* 86400, length.out = nt)  # Convert dt from days to seconds
start_time <- min(FRLM$date_time)

# Generate model time steps (POSIXct format)
time_model <- start_time + seq(0, by = dt * 86400, length.out = nt)  # Convert dt from days to seconds


air_temperature <- read_csv("Data/air_temp_LFBB.csv") |> 
  mutate(date_time = mdy_hm(date_time), 
         airtemp_3m_K = surftemp_degc + 273.15)

# load air temperature data from the East Lake Bonney Lake Monitoring Station, to fill gaps in the LFBB record
elbbb_airtemp <- read_csv('Data/air_temp_ELBBB.csv') |> 
  mutate(date_time = mdy_hm(date_time), 
         airtemp_3m_K = surface_temp_C + 273.15) |> 
  filter(date_time < "2023-11-01 00:00:00")

# Define the full sequence of timestamps at 15-minute intervals
full_timestamps <- data.frame(date_time = seq(from = min(air_temperature$date_time), 
                                              to = max(air_temperature$date_time), 
                                              by = "15 min"))

# Merge with original data and fill missing values with NA
air_temp_gaps <- full_timestamps |> 
  left_join(air_temperature, by = "date_time")

# fill gaps in record at East Lake Bonney with data from West Lake Bonney
air_temperature <- air_temp_gaps |> 
  mutate(airtemp_3m_K = ifelse(is.na(airtemp_3m_K), elbbb_airtemp$airtemp_3m_K, airtemp_3m_K))

###################### SHORTWAVE RADIATION DATA ######################
# select incoming shortwave radiation data from Lake Bonney Met and fill gaps. Gaps are first filled with data from the 
# next nearest station (Taylor Glacier Met), but failing that, an empirical equation defined in Obryk et al, 2016 is used. 
shortwave_radiation_initial <- FRLM |> 
  dplyr::select(metlocid, date_time, swradin_wm2) |> 
  mutate(swradin_wm2 = ifelse(is.na(swradin_wm2), EXEM$swradin_wm2, swradin_wm2)) # replace empty shortwave data with TARM, nearest met station

# create an artificial shortwave object
# Coordinates of East Lobe Bonney Blue Box
latitude <- -77.13449
longitude <- 162.449716

artificial_shortwave <- tibble(
  date_time = time_model, 
  zenith = 90 - getSunlightPosition(time_model, lat = latitude, lon = longitude)$altitude, #convert to zenith by subtracting the altitude from 90 degrees. 
  sw = S*cos(zenith)*3.0) # multiplied by 3 to make data better match historical mean.

shortwave_radiation <- shortwave_radiation_initial |> 
  left_join(artificial_shortwave, by = "date_time") |>    # Join on date_time
  mutate(swradin_wm2 = ifelse(is.na(swradin_wm2), sw, swradin_wm2)) |>   # Fill missing values
  dplyr::select(-sw)  |> # Remove extra column
  filter(swradin_wm2 > 0)


###################### OUTGOING (UPWELLING) LONGWAVE RADIATION DATA ######################
# select outgoing longwave radiation data from  Bonney Lake Glacier Met 
outgoing_longwave_radiation_initial <- COHM |> 
  dplyr::select(metlocid, date_time, lwradout2_wm2) |> 
  mutate(yday = yday(date_time), 
         hour = hour(date_time))

annual_mean_outgoing_longwave <- COHM |> 
  dplyr::select(metlocid, date_time, lwradout_wm2, lwradout2_wm2) |> 
  mutate(yday = yday(date_time), 
         j_day = julian(date_time), 
         hour = hour(date_time), 
         year = year(date_time)) |> 
  group_by(yday, hour) |> 
  summarize(mean_lwout = mean(lwradout_wm2, na.rm = T), 
            mean_lwout2 = mean(lwradout2_wm2, na.rm = T))

outgoing_longwave_radiation <- outgoing_longwave_radiation_initial |> 
  left_join(annual_mean_outgoing_longwave) |>    # Join on date_time
  mutate(lwradout2_wm2 = ifelse(is.na(lwradout2_wm2), mean_lwout2, lwradout2_wm2))  # Fill missing value


############# INCOMING (DOWNWELLING) LONGWAVE RADIATION DATA ######################
# select incoming longwave radiation data from Commonwealth Glacier Met
incoming_longwave_radiation_initial <- COHM |> 
  dplyr::select(metlocid, date_time, lwradin2_wm2, lwradin_wm2)

# Determine the last timestamp
last_timestamp <- max(incoming_longwave_radiation_initial$date_time)

# Generate new timestamps up to 2025 at the same 15-minute interval
new_timestamps <- seq.POSIXt(from = last_timestamp + 15*60, 
                             to = as.POSIXct("2025-01-31 23:45:00"), 
                             by = "15 min")

# Create an empty dataframe with new timestamps and NA for other columns
new_df <- data.frame(date_time = new_timestamps)

# Bind the old and new dataframes
incoming_longwave_radiation_initial <- bind_rows(incoming_longwave_radiation_initial, new_df) |> 
  mutate(yday = yday(date_time), 
         hour = hour(date_time))

# create an artificial dataset taking the historical mean of incoming longwave radiation on each day
# and using that to gap fill instead of using the modeled data (bad data)
annual_mean_incoming_longwave <- COHM |> 
  dplyr::select(metlocid, date_time, lwradin_wm2, lwradin2_wm2) |> 
  mutate(yday = yday(date_time), 
         j_day = julian(date_time), 
         hour = hour(date_time), 
         year = year(date_time)) |> 
  group_by(yday, hour) |> 
  summarize(mean_lwin = mean(lwradin_wm2, na.rm = T), 
            mean_lwin2 = mean(lwradin2_wm2, na.rm = T))

#join to fill gaps
incoming_longwave_radiation <- incoming_longwave_radiation_initial |> 
  left_join(annual_mean_incoming_longwave) |>    # Join on date_time
  mutate(lwradin2_wm2 = ifelse(is.na(lwradin2_wm2), mean_lwin2, lwradin2_wm2)) |>   # Fill missing values
  dplyr::select(-c(mean_lwin2, mean_lwin))   # Remove extra column 


###################### AIR PRESSURE DATA ######################
# Air pressure is collected at Lake Hoare Meteorological Station
air_pressure = HOEM |> 
  mutate(bpress_Pa = bpress_mb*100) |>  # air pressure was initially in mbar, needs to be in Pascal. 
  dplyr::select(metlocid, date_time, bpress_Pa)


###################### WIND SPEED DATA ######################
wind_speed = FRLM |> 
  dplyr::select(metlocid, date_time, wspd_ms) |>  # wind speed is in meters per second
  mutate(wspd_ms = ifelse(is.na(wspd_ms), EXEM$wspd_ms, wspd_ms)) # fill in lost wind values from TARM, next nearest met station


###################### RELATIVE HUMIDITY DATA ######################
# load relative humidity data
relative_humidity <- FRLM |> 
  dplyr::select(metlocid, date_time, rhh2o_3m_pct, rhice_3m_pct) |> 
  mutate(rhh2o_3m_pct = ifelse(is.na(rhh2o_3m_pct), EXEM$rhh2o_3m_pct, rhh2o_3m_pct))


###################### ICE THICKNESS DATA ######################
# load ice thickness data and manipulate for easier plotting
ice_thickness <- read_csv("Data/mcmlter-lake-ice_thickness-20250218_0_2025.csv") |>
  mutate(date_time = mdy_hm(date_time), 
         z_water_m = z_water_m*-1) |> 
  filter(location_name == "Lake Fryxell" & 
           str_starts(location, pattern = "O")) |> 
  filter(date_time > "2016-12-01" & date_time < "2024-02-01")


###################### ALBEDO DATA ######################
# Load and prepare the data
albedo_orig <- read_csv("Data/AlbedoModel.csv") |>  
  filter(lake == "Lake Fryxell") |> 
  mutate(date = ymd(sed.date),  # or ymd() if no time data is present, adjust as needed
         month = month(sed.date), 
         year = year(sed.date)) |> 
  drop_na(albedo.predict.bb)

# Generate 15-minute intervals across the full date range
start_time <- floor_date(min(albedo_orig$date), unit = "15 minutes")
end_time <- ceiling_date(max(albedo_orig$date), unit = "15 minutes")
time_15min <- tibble(time = seq(from = start_time, to = end_time, by = "15 mins"))

# Join 15-minute grid with original data
albedo1 <- time_15min |> 
  left_join(albedo_orig |> select(date, albedo.predict.bb), by = c("time" = "date")) |> 
  arrange(time) |> 
  fill(albedo.predict.bb, .direction = "down")


###################### Interpolate Data to match model time steps #####################

#Interpolate air temperature to match the model time steps
airt_interp <- approx(
  x = as.numeric(air_temperature$date_time),  # Convert date_time to numeric for interpolation
  y = air_temperature$airtemp_3m_K,
  xout = as.numeric(time_model),   # Interpolate at model time steps
  rule = 2                         # Use constant extrapolation for out-of-bound values
)$y

# Interpolate shortwave radiation to match the model time steps
sw_interp <- approx(
  x = as.numeric(shortwave_radiation$date_time),  # Convert date_time to numeric for interpolation
  y = shortwave_radiation$swradin_wm2,
  xout = as.numeric(time_model),   # Interpolate at model time steps
  rule = 2                         # Use constant extrapolation for out-of-bound values
)$y

# Interpolate longwave radiation to match the model time steps
LWR_in_interp <- approx(
  x = as.numeric(incoming_longwave_radiation$date_time),  # Convert date_time to numeric for interpolation
  y = incoming_longwave_radiation$lwradin2_wm2,
  xout = as.numeric(time_model),   # Interpolate at model time steps
  rule = 2                         # Use constant extrapolation for out-of-bound values
)$y

# longwave outgoign interpolate
LWR_out_interp <- approx(
  x = as.numeric(outgoing_longwave_radiation$date_time),  # Convert date_time to numeric for interpolation
  y = outgoing_longwave_radiation$lwradout2_wm2,
  xout = as.numeric(time_model),   # Interpolate at model time steps
  rule = 2                         # Use constant extrapolation for out-of-bound values
)$y

#reshape albedo (use this for the GEE dataset)
albedo_interp <- approx(
  x = as.numeric(albedo1$time),                     # Original dates as numeric
  y = albedo1$albedo.predict.bb,                   # Albedo means to interpolate
  xout = as.numeric(time_model),                   # Target times as numeric
  rule = 2                                         # Constant extrapolation for out-of-bound values
)$y

#pressure interpolate
pressure_interp <- approx(
  x = as.numeric(air_pressure$date_time),  # Convert date_time to numeric for interpolation
  y = air_pressure$bpress_Pa,
  xout = as.numeric(time_model),   # Interpolate at model time steps
  rule = 2                         # Use constant extrapolation for out-of-bound values
)$y

#wind interpolate
wind_interp <- approx(
  x = as.numeric(wind_speed$date_time),  # Convert date_time to numeric for interpolation
  y = wind_speed$wspd_ms,
  xout = as.numeric(time_model),   # Interpolate at model time steps
  rule = 2                         # Use constant extrapolation for out-of-bound values
)$y

#relative humidity interpolate
relative_humidity_interp <- approx(
  x = as.numeric(relative_humidity$date_time),
  y = relative_humidity$rhh2o_3m_pct, 
  xout = as.numeric(time_model),
  rule = 2
)$y

# Check if lengths of interpolated data match the time model
if (length(airt_interp) != length(time_model) | 
    length(sw_interp) != length(time_model) | 
    length(LWR_in_interp) != length(time_model) |
    length(LWR_out_interp) != length(time_model) |
    length(albedo_interp) != length(time_model) |
    length(pressure_interp) != length(time_model) |
    length(wind_interp) != length(time_model) |
    length(relative_humidity_interp) != length(time_model)
) {
  stop("Length of interpolated data does not match the model time steps!")
}


###################### Create the time series tibble for model time ######################
time_series <- tibble(
  time = time_model,                           # Model time steps
  T_air = airt_interp,                         # Interpolated air temperature Kelvin
  SW_in = sw_interp,                           # Interpolated shortwave radiation w/m2
  LWR_in = LWR_in_interp,                      # Interpolated incoming longwave radiation w/m2
  LWR_out = LWR_out_interp,                    # Interpolated outgoing longwave radiation w/m2
  albedo = albedo_interp,
  pressure = pressure_interp,                  # Interpolated air pressure, Pa
  wind = wind_interp,                          # interpolated wind speed, m/s
  delta_T = T_air - lag(T_air),                # difference in air temperature, for later flux calculation
  relative_humidity = relative_humidity_interp # relative humidity
) |> 
  drop_na(delta_T) # removes the first row where the difference in temperatures yields NA
