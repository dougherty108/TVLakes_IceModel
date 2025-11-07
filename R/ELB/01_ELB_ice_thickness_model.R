###### Ice Thickness Model ########

### Authors
# Charlie Dougherty
# April 29, 2025


# NOTES
# This script models ice thickness at an adjustable vertical depth and timestep through time at East Lake Bonney, Taylor Valley, Antarctica
# Ice thickness is modeled by solving the heat equation in the vertical axis iteratively, and correcting for surface mass loss by modeling different
# surface fluxes.
# Data is provided primarily by the McMurdo Dry Valleys Long Term Ecological Research project, with albedo surface estimates coming from 
# derived surface sediment maps over the McMurdo Dry Valleys Lakes using Landsat 8 data. 


# Load necessary libraries
library(tidyverse)
library(lubridate)
library(progress)
library(suncalc) # might not need this one here


# call the data preparation script
source("R/ELB/00_ELB_data_preparation.R")

###################### PLOT INPUT DATA ######################
# plot input data to check for funny business
#rename depending on which scenario you are plugging in

time_series = future_physical

# Stefan–Boltzmann constant
sigma <- 5.67e-8  # W/m2/K4

# ice surface emissivity (approx.)
emissivity <- 0.97

# Compute LWR_out (assume surface at freezing point unless melted)
time_series <- time_series %>%
  mutate(
    LWR_out = emissivity * sigma * (T_air^4),  # outgoing longwave flux
    delta_T = T_air - lag(T_air)
  ) |> 
  rbind(time_series_actual)

L_initial <- 3.30       # Initial ice thickness (m) Ice thickness at 12/17/2016 ice to ice

series <- time_series |> 
  pivot_longer(cols = c(T_air, SW_in, LWR_in, LWR_out, pressure, albedo, relative_humidity, wind), 
               names_to = "variable", values_to = "data")

ggplot(series, aes(time, data)) + 
  geom_path(size = 0.5) + 
  xlab("Date") + ylab("Input Data") +
  facet_wrap(vars(variable), scales = "free") + 
  theme_linedraw(base_size = 15)


###################### MODEL BEGINS ######################
n_iterations = nrow(time_series)

# Initialize results tibble
results <- tibble(
  time = rep(as.POSIXct(NA), n_iterations),  # Initialize `time` as NA POSIXct
  #depth = numeric(n_iterations),             # Initialize `depth` as numeric
  #temperature = numeric(n_iterations),       # Initialize `temperature` as numeric
  depth = vector("list", n_iterations),        # list-column
  temperature = vector("list", n_iterations),  # list-column
  thickness = numeric(n_iterations),         # Initialize `thickness` as numeric
  LW_net = numeric(n_iterations),            # Net Longwave flux
  SW = numeric(n_iterations),                # Shortwave Radiation Flux
  SW_abs = numeric(n_iterations),            # Absorbed shortwave radiation
  sensible_Q = numeric(n_iterations), 
  latent_Q = numeric(n_iterations), 
  conductive_Q = numeric(n_iterations),
  surface_heat_flux = numeric(n_iterations),
  surface_loss = numeric(n_iterations),
  bottom_gain = numeric(n_iterations),
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
  
  if (!exists("LW_net") || length(LW_net) == 0) LW_net <- NA
  if (!exists("SW_abs") || length(SW_abs) == 0) SW_abs <- NA
  
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
  results$surface_loss[t_idx] <- dL_surface
  results$bottom_gain[t_idx] <- dL_bottom
  results$Iteration[t_idx] <- t_idx  
  
  pb$tick()
}

###################### plotting of results ######################
results |> 
  group_by(time) |> 
  summarize(thickness = max(thickness)) |> 
  ggplot(aes(x = time, y = thickness)) +
  geom_line(color = "darkgreen", size = 1) +
  labs(x = "Time", y = "Ice Thickness (m)"
  ) +
  geom_point(data = ice_thickness, aes(x = date_time, y = z_water_m)) + 
  ggtitle("East Lake Bonney", 
          subtitle = "Using synthetic VAR data past 2023.") +
  theme_linedraw(base_size = 20)
