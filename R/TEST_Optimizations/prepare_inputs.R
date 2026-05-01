# ---- File paths ----
path_boym     = "~/Library/CloudStorage/OneDrive-UCB-O365/Documents/MCM-LTER_Met/met stations/mcmlter-clim_boym_15min-20250205.csv"
path_hoem     = "~/Library/CloudStorage/OneDrive-UCB-O365/Documents/MCM-LTER_Met/met stations/mcmlter-clim_hoem_15min-20250205.csv"
path_cohm     = "~/Library/CloudStorage/OneDrive-UCB-O365/Documents/MCM-LTER_Met/met stations/mcmlter-clim_cohm_15min-20250205.csv"
path_tarm     = "~/Library/CloudStorage/OneDrive-UCB-O365/Documents/MCM-LTER_Met/met stations/mcmlter-clim_tarm_15min-20250205.csv"
path_airt_elb = "Data/air_temp_ELBBB.csv"
path_airt_wlb = "Data/air_temp_WLBBB.csv"
path_ice      = "Data/mcmlter-lake-ice_thickness-20250218_0_2025.csv"
path_albedo   = "Data/AlbedoModel.csv"

# ---- Temporal filters ----
start_filter  = as.POSIXct("2016-12-21 00:00:00")
wlb_end_filter = as.POSIXct("2023-11-01 00:00:00")
lwr_extend_to = as.POSIXct("2025-01-31 23:45:00")
ice_start     = as.POSIXct("2016-12-01")
ice_end       = as.POSIXct("2024-02-01")

# ---- Model parameters ----
L_initial     = 3.88    # initial ice thickness (m)
dx            = 0.10    # spatial step (m)
dt            = 1/24    # time step (days)
n_years       = 6.95    # number of years to run
alpha         = k / (rho * c)     # thermal diffusivity — computed from k/rho/c if NULL

# ---- Physical constants (kept here for the stability check) ----
k             = 2.3
rho           = 917
c             = 2100

# ---- Site filter ----
lake_name     = "East Lake Bonney"

prepare_elb_model_inputs <- function(
    
  # ---- Already-loaded met station dataframes ----
  BOYM,
  HOEM,
  COHM,
  TARM,
  
  # ---- Already-loaded ancillary dataframes ----
  airt_elb,        # air_temp_ELBBB.csv loaded externally
  airt_wlb,        # air_temp_WLBBB.csv loaded externally
  ice_thickness,   # ice thickness observations loaded externally
  albedo_orig,     # AlbedoModel.csv loaded externally
  
  # ---- Temporal filters ----
  start_filter    = as.POSIXct("2016-12-21 00:00:00"),
  wlb_end_filter  = as.POSIXct("2023-11-01 00:00:00"),
  lwr_extend_to   = as.POSIXct("2025-01-31 23:45:00"),
  ice_start       = as.POSIXct("2016-12-01"),
  ice_end         = as.POSIXct("2024-02-01"),
  
  # ---- Model parameters ----
  L_initial = 3.88,
  dx        = 0.10,
  dt        = 1/24,
  n_years   = 6.95,
  alpha     = NULL,
  
  # ---- Physical constants (for stability check) ----
  k   = 2.3,
  rho = 917,
  c   = 2100,
  
  # ---- Site filter ----
  lake_name = "East Lake Bonney"
  
) {
  
  # ---- 0. Derived model parameters ----------------------------------------
  if (is.null(alpha)) alpha <- k / (rho * c)
  
  nt     <- (1 / dt) * n_years * 365
  dt_sec <- dt * 86400
  r      <- alpha * dt_sec / dx^2
  
  if (r > 0.5) stop(sprintf(
    "Stability violation: r = %.4f > 0.5. Reduce dt (currently %.4f days) or increase dx (currently %.2f m).",
    r, dt, dx
  ))
  
  # ---- 1. Apply temporal filter to station data ---------------------------
  message("Filtering met station data...")
  
  BOYM <- BOYM |> mutate(date_time = ymd_hms(date_time)) |> filter(date_time > start_filter)
  HOEM <- HOEM |> mutate(date_time = ymd_hms(date_time)) |> filter(date_time > start_filter)
  COHM <- COHM |> mutate(date_time = ymd_hms(date_time)) |> filter(date_time > start_filter)
  TARM <- TARM |> mutate(date_time = ymd_hms(date_time)) |> filter(date_time > start_filter)
  
  # ---- 2. Build model time spine ------------------------------------------
  start_time <- min(BOYM$date_time)
  time_model <- start_time + seq(0, by = dt_sec, length.out = nt)
  
  # ---- 3. Helper: interpolate any raw series to model time ----------------
  interp_to_model <- function(datetime_vec, value_vec, label = "") {
    out <- approx(
      x    = as.numeric(datetime_vec),
      y    = value_vec,
      xout = as.numeric(time_model),
      rule = 2
    )$y
    if (length(out) != length(time_model))
      stop(sprintf("Interpolation length mismatch for: %s", label))
    out
  }
  
  # ---- 4. Air temperature -------------------------------------------------
  message("Preparing air temperature...")
  
  airt_elb <- airt_elb |>
    mutate(date_time    = mdy_hm(date_time),
           airtemp_3m_K = surface_temp_C + 273.15)
  
  airt_wlb <- airt_wlb |>
    mutate(date_time    = mdy_hm(date_time),
           airtemp_3m_K = surface_temp_C + 273.15) |>
    filter(date_time < wlb_end_filter)
  
  full_ts <- tibble(
    date_time = seq(min(airt_elb$date_time), max(airt_elb$date_time), by = "15 min")
  )
  
  air_temperature <- full_ts |>
    left_join(airt_elb, by = "date_time") |>
    left_join(airt_wlb |> select(date_time, airtemp_3m_K_wlb = airtemp_3m_K),
              by = "date_time") |>
    mutate(airtemp_3m_K = coalesce(airtemp_3m_K, airtemp_3m_K_wlb)) |>
    select(date_time, airtemp_3m_K)
  
  airt_interp <- interp_to_model(air_temperature$date_time,
                                 air_temperature$airtemp_3m_K, "air temperature")
  
  # ---- 5. Shortwave radiation ---------------------------------------------
  message("Preparing shortwave radiation...")
  
  sw_raw <- BOYM |>
    select(date_time, swradin_wm2) |>
    left_join(TARM |> select(date_time, swradin_wm2_tarm = swradin_wm2), by = "date_time") |>
    mutate(swradin_wm2 = coalesce(swradin_wm2, swradin_wm2_tarm)) |>
    filter(swradin_wm2 > 0) |>
    select(date_time, swradin_wm2)
  
  sw_interp <- interp_to_model(sw_raw$date_time, sw_raw$swradin_wm2, "shortwave")
  
  # ---- 6. Longwave radiation (incoming) -----------------------------------
  message("Preparing incoming longwave radiation...")
  
  lw_in_clim <- COHM |>
    select(date_time, lwradin_wm2, lwradin2_wm2) |>
    mutate(yday = yday(date_time), hour = hour(date_time)) |>
    group_by(yday, hour) |>
    summarize(mean_lwin2 = mean(lwradin2_wm2, na.rm = TRUE), .groups = "drop")
  
  lw_in_extended <- COHM |>
    select(date_time, lwradin2_wm2) |>
    bind_rows(tibble(
      date_time    = seq.POSIXt(max(COHM$date_time) + 15 * 60, lwr_extend_to, by = "15 min"),
      lwradin2_wm2 = NA_real_
    )) |>
    mutate(yday = yday(date_time), hour = hour(date_time)) |>
    left_join(lw_in_clim, by = c("yday", "hour")) |>
    mutate(lwradin2_wm2 = coalesce(lwradin2_wm2, mean_lwin2)) |>
    select(date_time, lwradin2_wm2)
  
  lwr_in_interp <- interp_to_model(lw_in_extended$date_time,
                                   lw_in_extended$lwradin2_wm2, "LWR in")
  
  # ---- 7. Longwave radiation (outgoing) -----------------------------------
  message("Preparing outgoing longwave radiation...")
  
  lw_out_clim <- COHM |>
    select(date_time, lwradout2_wm2) |>
    mutate(yday = yday(date_time), hour = hour(date_time)) |>
    group_by(yday, hour) |>
    summarize(mean_lwout2 = mean(lwradout2_wm2, na.rm = TRUE), .groups = "drop")
  
  lw_out_filled <- COHM |>
    select(date_time, lwradout2_wm2) |>
    mutate(yday = yday(date_time), hour = hour(date_time)) |>
    left_join(lw_out_clim, by = c("yday", "hour")) |>
    mutate(lwradout2_wm2 = coalesce(lwradout2_wm2, mean_lwout2)) |>
    select(date_time, lwradout2_wm2)
  
  lwr_out_interp <- interp_to_model(lw_out_filled$date_time,
                                    lw_out_filled$lwradout2_wm2, "LWR out")
  
  # ---- 8. Pressure --------------------------------------------------------
  message("Preparing pressure...")
  
  hoem_pressure  <- HOEM |> mutate(bpress_Pa = bpress_mb * 100)
  pressure_interp <- interp_to_model(hoem_pressure$date_time,
                                     hoem_pressure$bpress_Pa, "pressure")
  
  # ---- 9. Wind speed ------------------------------------------------------
  message("Preparing wind speed...")
  
  wind_raw <- BOYM |>
    select(date_time, wspd_ms) |>
    left_join(TARM |> select(date_time, wspd_ms_tarm = wspd_ms), by = "date_time") |>
    mutate(wspd_ms = coalesce(wspd_ms, wspd_ms_tarm)) |>
    select(date_time, wspd_ms)
  
  # ---- 10. Relative humidity ----------------------------------------------
  message("Preparing relative humidity...")
  
  rh_raw <- BOYM |>
    select(date_time, rhh2o_3m_pct) |>
    left_join(TARM |> select(date_time, rhh2o_3m_pct_tarm = rhh2o_3m_pct), by = "date_time") |>
    mutate(rhh2o_3m_pct = coalesce(rhh2o_3m_pct, rhh2o_3m_pct_tarm)) |>
    select(date_time, rhh2o_3m_pct)
  
  rh_interp <- interp_to_model(rh_raw$date_time, rh_raw$rhh2o_3m_pct, "relative humidity")
  
  # ---- 11. Albedo ---------------------------------------------------------
  message("Preparing albedo...")
  
  albedo_orig <- albedo_orig |>
    filter(lake == lake_name) |>
    mutate(date = ymd(sed.date)) |>
    drop_na(albedo.predict.bb)
  
  albedo_15min <- tibble(
    time = seq(
      floor_date(min(albedo_orig$date),   "15 minutes"),
      ceiling_date(max(albedo_orig$date), "15 minutes"),
      by = "15 mins"
    )
  ) |>
    left_join(albedo_orig |> select(date, albedo.predict.bb),
              by = c("time" = "date")) |>
    arrange(time) |>
    fill(albedo.predict.bb, .direction = "down")
  
  albedo_interp <- interp_to_model(albedo_15min$time,
                                   albedo_15min$albedo.predict.bb, "albedo")
  
  # ---- 12. Ice thickness (filter to validation window) --------------------
  message("Filtering ice thickness observations...")
  
  ice_thickness <- ice_thickness |>
    mutate(date_time = mdy_hm(date_time),
           z_water_m = z_water_m * -1) |>
    filter(location_name == lake_name,
           date_time > ice_start,
           date_time < ice_end)
  
  # ---- 13. Assemble and return --------------------------------------------
  message("Assembling time series...")
  
  time_series_ELB <- tibble(
    time              = time_model,
    T_air             = airt_interp,
    SW_in             = sw_interp,
    LWR_in            = lwr_in_interp,
    LWR_out           = lwr_out_interp,
    albedo            = albedo_interp,
    pressure          = pressure_interp,
    wind              = wind_interp,
    relative_humidity = rh_interp,
    delta_T           = T_air - lag(T_air)
  ) |>
    drop_na(delta_T)
  
  list(
    time_series   = time_series_ELB,
    ice_thickness = ice_thickness,
    time_model    = time_model,
    params        = list(
      alpha     = alpha,
      r         = r,
      dt        = dt,
      dx        = dx,
      L_initial = L_initial,
      nt        = nt
    )
  )
}


# ---- Load raw data (run once) ----
BOYM      <- read_csv(path_boym)
HOEM      <- read_csv(path_hoem)
COHM      <- read_csv(path_cohm)
TARM      <- read_csv(path_tarm)
airt_elb  <- read_csv(path_airt_elb)
airt_wlb  <- read_csv(path_airt_wlb)
ice_raw   <- read_csv(path_ice)
albedo_raw <- read_csv(path_albedo)

# ---- Run preparation ----
inputs <- prepare_elb_model_inputs(
  BOYM          = BOYM,
  HOEM          = HOEM,
  COHM          = COHM,
  TARM          = TARM,
  airt_elb      = airt_elb,
  airt_wlb      = airt_wlb,
  ice_thickness = ice_raw,
  albedo_orig   = albedo_raw
)

# ---- Run model ----
results <- run_ice_model(inputs$time_series)

