###### Ice Thickness Model ########

### Authors
# Charlie Dougherty
# September 19, 2025


# NOTES
# This script models ice thickness at an adjustable vertical depth and timestep through time at Lake Fryxell, Taylor Valley, Antarctica
# Ice thickness is modeled by solving the heat equation in the vertical axis iteratively, and correcting for surface mass loss by modeling different
# surface fluxes.
# Data is provided primarily by the McMurdo Dry Valleys Long Term Ecological Research project, with albedo surface estimates coming from 
# derived surface sediment maps over the McMurdo Dry Valleys Lakes using Landsat 8 data. 


# Load necessary libraries
library(tidyverse)
library(lubridate)
library(progress)
library(suncalc) # for sun angle estimates


#set working directory
setwd("~chdo4929")


###################### Load Time Series Data by Station ######################
# met station data can be found at the McMurdo Long Term Ecological Research website or on the Environmental Data Initiative
#BOYM <- read_csv("~/Library/CloudStorage/OneDrive-UCB-O365/Documents/MCM-LTER_Met/met stations/mcmlter-clim_boym_15min-20250205.csv") |> 
#  mutate(date_time = ymd_hms(date_time)) |> 
#  filter(date_time > '2016-12-11 00:00:00')

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
  filter(location_name == "Lake Fryxell") |> 
  filter(date_time > "2016-12-01" & date_time < "2024-02-01")


###################### ALBEDO DATA ######################
# Load and prepare the data
albedo_orig <- read_csv("Data/AlbedoModel.csv") |>  
  # mutate(sediment = sediment_abundance) |> 
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

###################### PLOT INPUT DATA ######################
series <- time_series |> 
  pivot_longer(cols = c(T_air, SW_in, LWR_in, LWR_out, pressure, albedo, relative_humidity, wind), 
               names_to = "variable", values_to = "data")

ggplot(series, aes(time, data)) + 
  geom_line(size = 1.5) + 
  xlab("Date") + ylab("Input Data") +
  facet_wrap(vars(variable), scales = "free") + 
  theme_linedraw(base_size = 15)


###################### MODEL BEGINS ######################
n_iterations <- nt

# Initialize results tibble
results <- tibble(
  time = rep(as.POSIXct(NA), n_iterations),  # Initialize `time` as NA POSIXct
  depth = numeric(n_iterations),             # Initialize `depth` as numeric
  temperature = numeric(n_iterations),       # Initialize `temperature` as numeric
  thickness = numeric(n_iterations),         # Initialize `thickness` as numeric
  LW_net = numeric(n_iterations),            # Net Longwave flux
  SW = numeric(n_iterations),                # Shortwave Radiation Flux
  SW_abs = numeric(n_iterations),            # Absorbed shortwave radiation
  sensible_Q = numeric(n_iterations), 
  latent_Q = numeric(n_iterations), 
  conductive_Q = numeric(n_iterations),
  surface_heat_flux = numeric(n_iterations),
  Iteration = numeric(n_iterations)          # Initialize `Iteration` as numeric
)

###################### Initialize temperature profile and ice thickness ######################
L = L_initial
prevL <- L_initial  # Initial ice thickness
depth <- seq(0, L, by = dx)  # Depth grid points
prevT <- seq(from = time_series$T_air[1], to = 273.15, length.out = length(depth))  # Linear initial gradient
dL_bottom.vec = NA # store these values for troubleshooting
dL_surface.vec = NA # store these values for troubleshooting


# add a progress bar because this stuff takes forever
pb <- progress_bar$new(
  format = "[:bar] :percent :elapsed | ETA: :eta",
  total = nrow(time_series), # Total iterations
  clear = FALSE
)

# add steps to save the individual flux values
###################### Simulation loop ######################
for (t_idx in 1:nrow(time_series)) {
  
  #store results for time step
  results$time[t_idx] <- time_series$time[t_idx]
  results$depth[t_idx] <- depth
  results$temperature[t_idx] <- prevT
  results$thickness[t_idx] <- prevL
  results$LW_net[t_idx] <- LW_net
  results$SW_abs[t_idx] <- SW_abs
  results$SW[t_idx] <- SW_in
  results$sensible_Q[t_idx] <- Qh
  results$latent_Q[t_idx] <- Ql
  results$conductive_Q[t_idx] <- Qc
  results$surface_heat_flux[t_idx] <- surface_flux
  results$Iteration[t_idx] <- t_idx  
  
  #ice thickness
  newL = prevL # Copy current thickness
  newT <- prevT  # Copy the current temperature profile
  
  # Extract current air temperature, shortwave radiation, longwave radiation, and time step
  T_air <- time_series$T_air[t_idx]
  SW_in <- time_series$SW_in[t_idx]
  LWR_in <- time_series$LWR_in[t_idx]
  LWR_out <- time_series$LWR_out[t_idx]
  albedo <- (time_series$albedo[t_idx])
  press <- (time_series$pressure[t_idx])
  wind <- (time_series$wind[t_idx])
  delta_T <- (time_series$delta_T[t_idx])
  rh <- (time_series$relative_humidity[t_idx])
  
  # Update temperature profile using the 1D heat diffusion equation
  for (i in 2:length(prevT)) {
    newT[i] <- prevT[i] + alpha * ((dt * 86400) / dx^2) * (prevT[i + 1] - 2 * prevT[i] + prevT[i - 1])
  }
  
  # Apply boundary conditions
  newT[1] <- T_air  # Surface temperature equals air temperature
  newT[length(prevT)] <- 273.15  # Bottom temperature equals freezing point of water
  
  # Calculate absorbed shortwave radiation (with albedo)
  SW_abs <- (1-Chi)*SW_in * (1 - albedo)
  
  # Net longwave radiation (incoming - outgoing)
  LW_net <- (LWR_in - LWR_out)
  
  #calculate sensible heat flux
  rho_air = (press*Ma)*0.1 / (R*T_air)
  
  #sensible heat flux
  Qh = rho_air*(Ca)*Ch*(delta_T)*wind
  
  #latent heat flux
  #Don't know how to find delta_Q: relative humidity difference between air and ice surface
  # currently, the below code is creating massive flux values, which is wrong. 
  
  if (newT[1] >= Tf) {
    A = 6.1121
    B = 17.502
    C = 240.97
    
    # energy to evaporate water
    xLatent = xLv
    
    #Compute atmospheric vapor pressure from relative humidity data
    ea = ((rh/100)* A * exp((B * (T_air - Tf))/(C + (T_air - Tf))))/100
    
    # compute the density of air slightly conflicts with what we have above
    rho_air = press * Ma/(R * T_air) * (1 + (epsilon - 1) * (ea/press))
    
    # Water vapor pressure at the surface assuming surface is the 
    # below freezing
    es0 = (A * exp((B * (Tf - Tf))/(C + (Tf - Tf))))/100
    
    Ql = rho_air*(xLatent)*Ce*(0.622/press)*(ea - es0)*wind
  }
  
  if (newT[1] < Tf) {
    A = 6.1115
    B = 22.452
    C = 272.55
    xLatent = xLs # Energy to sublimate ice
    
    # Compute atmospheric vapor pressure from relative humidity data
    ea = ((rh/100) * A * exp((B * (T_air - Tf))/(C + (T_air - Tf)))) / 100
    
    rho_air = press * Ma/(R * T_air) * (1 + (epsilon - 1) * (ea/press))
    
    #Compute the water vapor pressure at the surface assuming surface
    # is same temp as air
    es0 = (A * exp((B * (T_air - Tf))/(C + (T_air - Tf)))) / 100
    
    Ql = rho_air*(xLatent)*Ce*(0.622/press)*(ea - es0)*wind
  }
  
  Qc = (k * (prevT[1] - T_air) / dx)
  
  # Surface heat flux (absorbed shortwave, net longwave, conductive heat flux, sensible heat flux, and latent heat flux)
  surface_flux <- SW_abs + (LW_net - Qc) + Qh + Ql 
  
  # Calculate melting at the surface (and ablation)
  if (!is.na(surface_flux) && surface_flux > 0) {
    dL_surface <- surface_flux * (dt * 86400) / (rho * L_f)
    newL <- newL - dL_surface
  }
  
  # Calculate freezing/melting at the bottom
  if (!is.na(newL) && newL > 0) {
    Q_bottom <- -k * (newT[length(newT) - 1] - newT[length(newT)]) / dx
    dL_bottom <- Q_bottom * (dt * 86400) / (rho * L_f)
    newL <- newL + dL_bottom
  }
  
  dL_surface.vec[t_idx] = dL_surface
  dL_bottom.vec[t_idx] = dL_bottom
  
  # Ensure ice thickness remains positive
  newL <- max(0, newL)
  
  # Adjust spatial resolution if thickness changes
  if (newL > 0) {
    # nx <- 30  # Ensure at least 15 layers
    dx <- 0.1  # Recalculate spatial step size
    newdepth <- seq(0, newL, by = dx)  # Update depth values
    newT <- approx(seq(0, prevL, length.out = length(depth)), newT, seq(0, newL, length.out = length(newdepth)), rule = 2)$y  # Interpolate
  } else {
    newT <- rep(0, nx)  # Reset temperature profile if no ice
    depth <- NA  # No depth when no ice
  }
  
  # Update prevT
  prevT <- newT
  prevL = newL
  depth = newdepth
  
  pb$tick()
}

###################### plotting of results ######################
results |> 
  group_by(time) |> 
  summarize(thickness = max(thickness)) |> 
  ggplot(aes(x = time, y = thickness)) +
  geom_line(color = "darkblue", size = 1) +
  labs(x = "Time", y = "Ice Thickness (m)"
  ) +
  geom_point(data = ice_thickness, aes(x = date_time, y = z_water_m)) + 
  ggtitle("Lake Fryxell") +  
  theme_linedraw(base_size = 20)

### pivot results dataframe for plotting of all the fluxes through time
result_flux = results |> 
  pivot_longer(cols = c(temperature, thickness, LW_net, SW, SW_abs, sensible_Q, latent_Q, 
                        conductive_Q, surface_heat_flux), 
               names_to = "flux", 
               values_to = "value")

ggplot(result_flux, aes(time, value, color = flux)) + 
  geom_path() + 
  facet_wrap(~flux, scales = "free")

## 
results_year_max = results |> 
  mutate(year = year(time), 
         date = as.Date(time)) |> 
  group_by(year) |> 
  slice_max(order_by = thickness, n = 1) |> 
  select(year, date) |> 
  ungroup()

results_year_min = results |> 
  mutate(year = year(time), 
         date = as.Date(time)) |> 
  group_by(year) |> 
  slice_min(order_by = thickness, n = 1) |> 
  select(year, date) |> 
  ungroup() |> print()

#troubleshooting plots, to find distance of change at top and bottom
plot(dL_bottom.vec)
plot(dL_surface.vec)

####### Comparing outputs ##########
#setwd("/Users/charliedougherty/Documents/R-Repositories/MCM-LTER-MS")

# load file
GEE_corrected <- results |> 
  group_by(time) |> 
  summarize(thickness = max(thickness)) |> 
  mutate(time = ymd_hms(time)) |> 
  filter(thickness > 0)

summary(GEE_corrected$thickness)
# ice thickness data
ice_thick <- read_csv("Data/mcmlter-lake-ice_thickness-20250218_0_2025.csv") |>
  mutate(date_time = mdy_hm(date_time), 
         z_water_m = z_water_m*-1) |> 
  filter(location_name == "East Lake Bonney", 
  ) |> 
  filter(str_detect(string = location, pattern = "Inside")) |> 
  filter(date_time > "2016-12-01" & date_time < "2025-02-01") |> 
  group_by(date_time) |> 
  summarize(mean_thickness = mean(z_water_m, na.rm = T))

summary(ice_thick$mean_thickness)

# plot modeled ice thickness against the measured thickness
ggplot() + 
  geom_line(data = GEE_corrected, aes(x = time, y = thickness), linewidth = 1.25) + 
  geom_point(data = ice_thick, aes(x = date_time, y = mean_thickness), color = "red") +
  xlab("Time") + ylab("Ice Thickness (m)") + 
  ggtitle("East Lake Bonney Ice Thickness", 
          subtitle = "modeled vs. measured") +
  theme_linedraw(base_size = 20)

#ggsave("plots/manuscript/chapter 2/measured_vs_modeled.png", 
#       dpi = 300, height = 8, width = 12)

modeled_daily <- GEE_corrected |> 
  mutate(time = ymd_hms(time), 
         date_time = date(time)) |> 
  group_by(date_time) |> 
  summarize(modeled_thickness = mean(thickness)) 


### join two datasets together to compare dates
comp <- ice_thick |> 
  left_join(modeled_daily, by = join_by(date_time)) |> 
  group_by(date_time) |> 
  mutate(difference = modeled_thickness - mean_thickness)

# different summary breakdowns
summary(comp$mean_thickness)
summary(comp$modeled_thickness)
summary(comp$difference)

#plot modeled and measured against each other
ggplot(comp, aes(mean_thickness, modeled_thickness)) + 
  geom_point(size = 2.5, shape = 1) + 
  geom_abline(size = 1.5) + 
  xlab("Measured Ice Thickness") + ylab("Modeled Ice Thickness") + 
  theme_linedraw(base_size = 20)

linear_model = lm(modeled_thickness ~mean_thickness, data = comp)

summary(linear_model)

thickness_pivot <- comp |> 
  pivot_longer(cols = c(modeled_thickness, mean_thickness), 
               names_to = "measurement_type", values_to = "thickness") |> 
  select(date_time, measurement_type, thickness)
