######### model input data prep ##########

#set working directory
setwd("~chdo4929")


###################### Load Time Series Data by Station ######################
# met station data can be found at the McMurdo Long Term Ecological Research website or on the Environmental Data Initiative
BOYM <- read_csv("~/Library/CloudStorage/OneDrive-UCB-O365/Documents/MCM-LTER_Met/met stations/mcmlter-clim_boym_15min-20250205.csv") |> 
  mutate(date_time = ymd_hms(date_time)) |> 
  filter(date_time > '2016-12-21 00:00:00')

HOEM <- read_csv("~/Library/CloudStorage/OneDrive-UCB-O365/Documents/MCM-LTER_Met/met stations/mcmlter-clim_hoem_15min-20250205.csv") |> 
  mutate(date_time = ymd_hms(date_time)) |> 
  filter(date_time > '2016-12-21 00:00:00') |> 
  mutate(airtemp_3m_K = airtemp_3m_degc + 273.15)

COHM <- read_csv("~/Library/CloudStorage/OneDrive-UCB-O365/Documents/MCM-LTER_Met/met stations/mcmlter-clim_cohm_15min-20250205.csv") |> 
  mutate(date_time = ymd_hms(date_time)) |> 
  filter(date_time > '2016-12-21 00:00:00')

TARM <- read_csv("~/Library/CloudStorage/OneDrive-UCB-O365/Documents/MCM-LTER_Met/met stations/mcmlter-clim_tarm_15min-20250205.csv") |> 
  mutate(date_time = ymd_hms(date_time)) |> 
  filter(date_time > '2016-12-21 00:00:00') |> 
  mutate(airtemp_3m_K = airtemp_3m_degc + 273.15)

###################### Define Parameters ######################
L_initial <- 3.88       # Initial ice thickness (m) Ice thickness at 12/17/2016 ice to ice
dx <- 0.10             # Spatial step size (m)
nx = L_initial/dx       # Number of spatial steps
dt <-  1/24             # Time step for stability (in days)
nt <- (1/dt)*24*365.   # Number of time steps

# Stability check: Ensure R < 0.5 for stability
r <- alpha * (dt * 86400) / dx^2  # dt is in days, so multiply by 86400 to convert to seconds
if (r > 0.5) stop("r > 0.5, solution may be unstable. Reduce dt or dx.")

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


###################### Separate data out into input parameters ######################
#preemptively set working directory back 
setwd("~/Documents/R-Repositories/TVLakes_IceModel")

# select air temperature data from Lake Bonney Met, and gapfill holes with Lake Hoare
# this step is mainly to gather a time series for gap filling other portions of the script. Air temperature data is sourced 
# the East Lake Bonney Permanent Monitoring Station (ELBBB)

###################### AIR TEMPERATURE DATA ######################
## load air temperature data from East Lake Bonney Lake Monitoring Station (unpublished data)

#time_model = start_time + seq(0, by = dt* 86400, length.out = nt)  # Convert dt from days to seconds
start_time <- min(BOYM$date_time)

# Generate model time steps (POSIXct format)
time_model <- start_time + seq(0, by = dt * 86400, length.out = nt)  # Convert dt from days to seconds


air_temperature <- read_csv("Data/air_temp_ELBBB.csv") |> 
  mutate(date_time = mdy_hm(date_time), 
         airtemp_3m_K = surface_temp_C + 273.15)

# load air temperature data from the West Lake Bonney Lake Monitoring Station, to fill gaps in the ELBBB record
wlbbb_airtemp <- read_csv('Data/air_temp_WLBBB.csv') |> 
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
  mutate(airtemp_3m_K = ifelse(is.na(airtemp_3m_K), wlbbb_airtemp$airtemp_3m_K, airtemp_3m_K))

###################### SHORTWAVE RADIATION DATA ######################
# select incoming shortwave radiation data from Lake Bonney Met and fill gaps. Gaps are first filled with data from the 
# next nearest station (Taylor Glacier Met), but failing that, an empirical equation defined in Obryk et al, 2016 is used. 
shortwave_radiation_initial <- BOYM |> 
  dplyr::select(metlocid, date_time, swradin_wm2) |> 
  mutate(swradin_wm2 = ifelse(is.na(swradin_wm2), TARM$swradin_wm2, swradin_wm2)) # replace empty shortwave data with TARM, nearest met station

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
wind_speed = BOYM |> 
  dplyr::select(metlocid, date_time, wspd_ms) |>  # wind speed is in meters per second
  mutate(wspd_ms = ifelse(is.na(wspd_ms), TARM$wspd_ms, wspd_ms)) # fill in lost wind values from TARM, next nearest met station


###################### RELATIVE HUMIDITY DATA ######################
# load relative humidity data
relative_humidity <- BOYM |> 
  dplyr::select(metlocid, date_time, rhh2o_3m_pct, rhice_3m_pct) |> 
  mutate(rhh2o_3m_pct = ifelse(is.na(rhh2o_3m_pct), TARM$rhh2o_3m_pct, rhh2o_3m_pct))


###################### ICE THICKNESS DATA ######################
# load ice thickness data and manipulate for easier plotting
ice_thickness <- read_csv("Data/mcmlter-lake-ice_thickness-20250218_0_2025.csv") |>
  mutate(date_time = mdy_hm(date_time), 
         z_water_m = z_water_m*-1) |> 
  filter(location_name == "East Lake Bonney") |> 
  filter(date_time > "2016-12-01" & date_time < "2024-02-01")


###################### ALBEDO DATA ######################
# Load and prepare the data
albedo_orig <- read_csv("Data/AlbedoModel.csv") |>  
  # mutate(sediment = sediment_abundance) |> 
  filter(lake == "East Lake Bonney") |> 
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
time_series_interp <- tibble(
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
  drop_na(delta_T)  # removes the first row where the difference in temperatures yields NA


######################### Synthentic Meteorological Dataset Creation ############################

# Synthetic multivariate climate time series using VAR + residual bootstrap
# Input expected: a tibble named `time_series_interp` with columns:
# time, T_air (K), SW_in, LWR_in, LWR_out, albedo, pressure (Pa), wind (m/s), delta_T, relative_humidity
#
# Author: ChatGPT
# Date: 11/6/2025
#
# Required packages:
required_pkgs <- c("tidyverse","lubridate","zoo","vars","copula","ggplot2","reshape2","gridExtra","scales")
new_pkgs <- required_pkgs[!(required_pkgs %in% installed.packages()[,"Package"])]
if(length(new_pkgs)) install.packages(new_pkgs)
library(tidyverse); library(lubridate); library(zoo); library(vars)
library(copula); library(ggplot2); library(reshape2); library(gridExtra); library(scales)

# ---------------------------
# 1. Prepare and sanity-check
# ---------------------------
# Ensure your tibble is present
if(!exists("time_series_interp")) stop("time_series_interp object not found. Please load it before running this script.")

df <- time_series_interp %>%
  arrange(time) %>%
  mutate(time = as.POSIXct(time, tz = "UTC")) # adjust tz if needed

# Check for NA's and optionally interpolate or remove (here we stop if many NA)
na_count <- sum(is.na(df))
message("Total NA values in dataset: ", na_count)
if(na_count > 0) {
  message("You have NA values. It's recommended to fill or remove them before modelling.")
  # simple linear interpolation for small gaps (uncomment to enable):
  # df <- df %>% mutate(across(where(is.numeric), ~ na.approx(., x = time, na.rm = FALSE)))
}

# ---------------------------
# 2. Transform variables
# ---------------------------
eps <- 1e-6
logit <- function(x) { qlogis(pmin(pmax(x, eps), 1 - eps)) }
inv_logit <- function(x) { plogis(x) }

df_trans <- df %>%
  mutate(
    # convert RH from percent to fraction & clamp
    relative_humidity_frac = relative_humidity / 100,
    relative_humidity_frac = pmin(pmax(relative_humidity_frac, 0.0001), 0.9999),
    
    # convert to logit scale
    rh_t = qlogis(relative_humidity_frac),
    
    # albedo 0–1 clamp and logit
    albedo_clamped = pmin(pmax(albedo, 0.0001), 0.9999),
    albedo_t = qlogis(albedo_clamped),
    
    # wind transform
    wind_t = sqrt(pmax(wind, 0)),
    
    # leave radiative + temperature + pressure mostly untouched
    T_air_t = T_air,
    SW_in_t  = SW_in,
    LWR_in_t = LWR_in,
    pressure_t = pressure
  ) %>%
  dplyr::select(
    time,
    T_air_t, SW_in_t, LWR_in_t,
    albedo_t, pressure_t, wind_t, rh_t
  )



# ---------------------------
# 3. Compute seasonal cycle (hour of day + day of year) and anomalies
# ---------------------------
# We'll compute a seasonal climatology by (hour-of-day, day-of-year) to capture diurnal + annual
df_trans <- df_trans %>%
  mutate(
    hour = hour(time),
    doy = yday(time)
  )

# compute mean seasonal cycle for each variable as mean over (doy, hour)
vars_t <- c("T_air_t","SW_in_t","LWR_in_t","albedo_t","pressure_t","wind_t","rh_t")

seasonal_means <- df_trans %>%
  mutate(
    doy = yday(time),
    hour = hour(time)
  ) %>%
  group_by(doy, hour) %>%      # <--- IMPORTANT CHANGE
  summarise(
    T_air_t_seasonal    = mean(T_air_t, na.rm = TRUE),
    SW_in_t_seasonal    = mean(SW_in_t, na.rm = TRUE),
    LWR_in_t_seasonal   = mean(LWR_in_t, na.rm = TRUE),
    albedo_t_seasonal   = mean(albedo_t, na.rm = TRUE),
    pressure_t_seasonal = mean(pressure_t, na.rm = TRUE),
    wind_t_seasonal     = mean(wind_t, na.rm = TRUE),
    rh_t_seasonal       = mean(rh_t, na.rm = TRUE),
    .groups = "drop"
  )

# join back to get anomalies
df_anom <- df_trans %>%
  left_join(seasonal_means, by = c("doy","hour"), suffix = c("","_seas")) %>%
  mutate(across(all_of(vars_t), ~ . - get(paste0(cur_column(), "_seas")), .names = "anom_{col}"))

# Build matrix of anomalies for VAR
anom_names <- paste0("anom_", vars_t)
Y <- df_anom %>%
  dplyr::select(all_of(anom_names)) %>%
  as.matrix()

# remove rows with any NA in Y
na_rows <- apply(Y, 1, function(x) any(is.na(x)))
if(any(na_rows)) {
  warning(sum(na_rows), " rows contain NA in anomalies. These will be removed for VAR fitting.")
  Y_fit <- Y[!na_rows, ]
  df_fit <- df_anom[!na_rows, ]
} else {
  Y_fit <- Y
  df_fit <- df_anom
}

# ---------------------------
# 4. Fit VAR (select lag)
# ---------------------------
max_lag <- 48  # adjust depending on data frequency / memory (48 for up to 2-day memory if hourly)
lag_sel <- VARselect(Y_fit, lag.max = max_lag, type = "const")
message("Lag selection results:"); print(lag_sel$selection)

p_choice <- as.integer(lag_sel$selection["AIC(n)"])  # choose AIC-selected lag
if(is.na(p_choice)) p_choice <- 1
message("Selected VAR lag p = ", p_choice)

var_model <- VAR(Y_fit, p = p_choice, type = "const")
summary(var_model)

# Extract residuals (for bootstrap) and their covariance
resids <- residuals(var_model)   # matrix (n_obs - p) x nvars
Sigma_res <- cov(resids, use = "pairwise.complete.obs")

# ---------------------------
# 5. Synthetic simulation function
#    - recursive using model coefficients and bootstrap sampling of residuals
# ---------------------------
simulate_VAR_bootstrap <- function(var_model, n_sim, init_y = NULL, resids = NULL, seed = NULL) {
  # var_model: fitted VAR object (vars::VAR)
  # n_sim: number of steps to simulate
  # init_y: initial p observations matrix (p x nvar). If NULL, use last p from model data
  # resids: matrix of residuals to bootstrap from
  # returns: matrix n_sim x nvar synthetic anomalies
  if(!is.null(seed)) set.seed(seed)
  p <- var_model$p
  k <- ncol(var_model$y)   # number of variables
  coefs_list <- var_model$varresult
  # Build coefficient arrays:
  # companion style easier to apply: we will extract coef matrices A1..Ap and const
  A_mats <- array(0, dim = c(k,k,p))
  const_vec <- numeric(k)
  for(i in seq_len(k)) {
    co <- coef(coefs_list[[i]])
    # names are like "const", "L1.var1", etc
    const_vec[i] <- co["const"]
    # extract lag coefficients for this equation
    for(l in 1:p) {
      # coef names for lag l: paste0("L",l,".", var names)
      lag_names <- paste0("L", l, ".", colnames(var_model$y))
      A_mats[i,,l] <- co[lag_names]
    }
  }
  # transpose A_mats to have A_l matrices of shape k x k
  A_list <- lapply(1:p, function(l) t(A_mats[,,l]))
  # initial values
  if(is.null(init_y)) {
    # get last p observations used in fit
    Y_full <- var_model$y  # matrix used in fit (nobs x k)
    init_indices <- (nrow(Y_full) - p + 1):nrow(Y_full)
    init_y <- Y_full[init_indices, , drop = FALSE]
  }
  if(is.null(resids)) stop("resids (bootstrap residuals) must be provided")
  # Prepare storage
  Ysim <- matrix(0, nrow = n_sim, ncol = k)
  # rolling state: store last p observations, newest last row
  state <- init_y
  for(t in 1:n_sim) {
    # deterministic part
    mu_t <- const_vec
    for(l in 1:p) {
      mu_t <- mu_t + A_list[[l]] %*% state[nrow(state) - (l-1), ]
    }
    # sample residual
    e_t <- resids[sample(nrow(resids), 1), ]
    new_y <- as.vector(mu_t + e_t)
    # append
    Ysim[t, ] <- new_y
    # update state: drop first, append new
    if(p > 1) state <- rbind(state[-1, , drop = FALSE], new_y) else state <- matrix(new_y, nrow=1)
  }
  colnames(Ysim) <- colnames(var_model$y)
  return(Ysim)
}

# decide simulation length
n_obs <- nrow(df)   # produce same length as original by default
n_sim <- n_obs

library(MTS)

# Suppose you have k variables and p lags
k <- ncol(df_var)
p <- lag_order

sim_data <- VARMAsim(n = n_steps, ar = lapply(1:p, function(i) coef(var_model)[[i]]),
                     sigma = cov(residuals(var_model)))

sim_anom <- as.data.frame(sim_data$series)
colnames(sim_anom) <- colnames(df_var)


# If you prefer Gaussian residuals, you can generate with mvrnorm:
# sim_anom_gauss <- simulate_VAR_gaussian(...)  (not implemented here)

# ---------------------------
# 6. Reconstruct physical variables
# ---------------------------
# sim_anom is n_sim x k with column names matching var_model$y (which matches var names in Y_fit)
# We need to map them back to original rows with seasonal cycle and inverse transforms.

# Build a tibble to hold simulated anomalies aligned to the original df rows
sim_anom_df <- as_tibble(sim_anom)
# Ensure ordering of columns corresponds to anom_names; var_model$y column names might be the same
# var_model$y colnames should be anom_names; check:
if(!all(colnames(var_model$y) %in% anom_names)) {
  warning("VAR column names differ from expected anomaly names. Attempting to align by position.")
}

# We'll take the same time index as df (even if some rows were removed during fitting).
# For rows that were excluded (NA rows), we'll fill with NA or simulated values — simplest: return full-length sim by aligning indices.
sim_full <- df_anom %>%
  dplyr::select(time, doy, hour) %>%
  mutate(row_id = row_number()) %>%
  # attach simulated anomalies in order (if df had NA rows removed during fit, simulation used contiguous fit rows)
  mutate(sim_index = row_number())  # one-to-one

# If we removed rows during VAR fitting, we must align simulated output with original df rows:
if(any(na_rows)) {
  # we simulated n_sim = nrow(df), but the VAR used only rows where !na_rows; our simulate_VAR_bootstrap used init from fitted data and
  # simulated n_sim steps; to be cautious, we'll take the first n_sim simulated rows and map them to the original time order.
  # For simplicity, map sequentially: (user can refine if they want strict mapping)
  # Attach by position:
  sim_full <- sim_full %>%
    bind_cols(as_tibble(sim_anom)[1:nrow(sim_full), , drop = FALSE])
} else {
  sim_full <- sim_full %>%
    bind_cols(as_tibble(sim_anom)[1:nrow(sim_full), , drop = FALSE])
}

# Now add back seasonal means for each variable
# bring seasonal_means into sim_full by (doy,hour)
sim_full <- sim_full %>%
  left_join(seasonal_means, by = c("doy","hour"))

# For each variable, compute simulated physical value = anomaly_sim + seasonal_mean
# anom names are anom_<var>
recon <- sim_full
for(v in vars_t) {
  anom_col <- paste0("anom_", v)
  seas_col <- paste0(v, "_seasonal")   # seasonal_means columns used suffix "_seas" earlier
  out_col  <- paste0(v, "_sim_recon")
  # the seasonal mean column exists as column named like "T_air_t_seas" in sim_full
  recon[[out_col]] <- recon[[anom_col]] + recon[[seas_col]]
}

# Now invert transforms to original physical variables
# recall transforms:
# rh_t = logit(relative_humidity)  -> inv_logit
# albedo_t = logit(albedo) -> inv_logit
# wind_t = sqrt(wind) -> square
# T_air_t was unchanged

# Create final synthetic tibble
sigma_sb <- 5.670374419e-8  # Stefan-Boltzmann constant

synthetic <- tibble(
  time = recon$time,
  T_air = recon$T_air_t_sim_recon,      # Kelvin
  SW_in = recon$SW_in_t_sim_recon,
  LWR_in = recon$LWR_in_t_sim_recon,
  #LWR_out_raw = recon$LWR_out_t_sim_recon,  # we'll optionally replace with physics-based calc below
  albedo = pmin(pmax(inv_logit(recon$albedo_t_sim_recon), 0), 1),
  pressure = recon$pressure_t_sim_recon,
  wind = (recon$wind_t_sim_recon)^2,     # inverse sqrt -> square
  relative_humidity = pmin(pmax(inv_logit(recon$rh_t_sim_recon), 0), 1)
) %>% mutate(
  # delta_T relative to previous time
  delta_T = T_air - lag(T_air)
)

# ---------------------------
# 7. (Optional) Recompute LWR_out physically for thermodynamic consistency
#    Use emissivity estimated from original data: emissivity = mean(LWR_out / (sigma * T^4))
#    Then recompute LWR_out_sim = emissivity * sigma * T_sim^4
# ---------------------------
orig_emissivity <- mean((df$LWR_out) / (sigma_sb * (df$T_air)^4), na.rm = TRUE)
message("Estimated mean emissivity from original data: ", signif(orig_emissivity,4))
# limit emissivity to sensible bounds
orig_emissivity <- pmin(pmax(orig_emissivity, 0.4), 1.0)

synthetic <- synthetic %>%
  mutate(
    LWR_out = orig_emissivity * sigma_sb * (T_air)^4
  )

# We keep LWR_out computed physically, but keep the raw simulated as well if you want to compare:
#synthetic <- synthetic %>% relocate(LWR_out_raw, .after = LWR_out)

# ---------------------------
# 8. Enforce simple physical constraints
# ---------------------------
synthetic <- synthetic %>%
  mutate(
    albedo = pmin(pmax(albedo, 0), 1),
    relative_humidity = pmin(pmax(relative_humidity, 0), 1),
    wind = pmax(wind, 0),
    pressure = pmax(pressure, 1)  # ensure positive (Pa)
  )

# ---------------------------
# 9. Quick diagnostics & plots
# ---------------------------
# Combine original and synthetic
plot_vars <- c("T_air","SW_in","LWR_in","LWR_out","albedo","wind","relative_humidity")

orig_plot_df <- df %>%
  dplyr::select(time, all_of(plot_vars)) %>%
  pivot_longer(-time, names_to = "variable", values_to = "value") %>%
  mutate(source = "orig")

synth_plot_df <- synthetic %>%
  dplyr::select(time, all_of(plot_vars)) %>%
  pivot_longer(-time, names_to = "variable", values_to = "value") %>%
  mutate(source = "synth")

combined_df <- bind_rows(orig_plot_df, synth_plot_df)

# Split by variable
plot_list <- lapply(unique(combined_df$variable), function(var_name) {
  df_sub <- combined_df %>% filter(variable == var_name)
  ggplot(df_sub, aes(x = value, fill = source, colour = source)) +
    geom_density(alpha = 0.2, size = 0.5) +
    ggtitle(var_name) +
    theme_minimal()
})

# Show first 4 density plots
library(gridExtra)
grid.arrange(grobs = plot_list[1:4], ncol = 2)

# ACF for T_air original vs synthetic
acf_orig <- acf(na.omit(df$T_air), plot = FALSE)
acf_synth <- acf(na.omit(synthetic$T_air), plot = FALSE)
# You can plot these in RStudio etc.; we'll produce a simple overlay plot using ggplot
acf_df <- tibble(lag = acf_orig$lag, orig = acf_orig$acf, synth = acf_synth$acf) %>%
  pivot_longer(-lag, names_to = "series", values_to = "acf")
ggplot(acf_df, aes(x = lag, y = acf, colour = series)) + geom_line() + ggtitle("ACF: T_air original vs synthetic")

# Cross-correlation heatmap (original vs synthetic) using Pearson cor across variables
orig_mat <- df %>% select(all_of(plot_vars)) %>% drop_na() %>% as.matrix()
synth_mat <- synthetic %>% select(all_of(plot_vars)) %>% drop_na() %>% as.matrix()
cor_orig <- cor(orig_mat, use = "pairwise.complete.obs")
cor_synth <- cor(synth_mat, use = "pairwise.complete.obs")

m1 <- melt(cor_orig); names(m1) <- c("Var1","Var2","Corr"); m1$source <- "orig"
m2 <- melt(cor_synth); names(m2) <- c("Var1","Var2","Corr"); m2$source <- "synth"
m_comb <- bind_rows(m1,m2)

ggplot(m_comb, aes(x = Var1, y = Var2, fill = Corr)) +
  geom_tile() + facet_wrap(~source) +
  scale_fill_gradient2(low = "blue", mid = "white", high = "red", limits = c(-1,1)) +
  theme_minimal() + theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  ggtitle("Correlation matrices: original vs synthetic")

# ---------------------------
# 10. Save output
# ---------------------------
# final synthetic tibble is `synthetic`
# attach to workspace and optionally save to disk:
assign("synthetic_time_series", synthetic, envir = .GlobalEnv)
message("Created 'synthetic_time_series' tibble in the global environment.")
# write csv if desired
# write_csv(synthetic, "synthetic_time_series.csv")

# ---------------------------
# Notes & next steps
# ---------------------------
# - The script uses residual bootstrap to retain non-Gaussian residual behaviour.
# - If you want to better preserve tail dependencies across variables, consider:
#     * fitting a copula to VAR residuals and sampling from that copula
#     * running the VAR on principal components, or combining VAR + copula on marginals
# - If your data have trends or nonstationarity, consider differencing or VECM instead of VAR.
# - If you need conditional scenarios (e.g., force warmer mean), add a shift to seasonal means before reconstruction.
# - If you want multiple ensemble members, call simulate_VAR_bootstrap multiple times with different seeds.
#
# End of script