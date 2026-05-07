# ============================================================
# CONSTANTS — define once, pass everywhere
# ============================================================
CONSTANTS <- list(
  # Thermodynamic
  sigma      = 5.67e-8,   # Stefan-Boltzmann (W/m²/K⁴)
  emissivity = 0.97,      # ice surface emissivity
  Tf         = 273.15,    # freezing point of water (K)
  L_f        = 334000,    # latent heat of fusion (J/kg)
  xLv        = 2.501e6,   # latent heat of vaporization (J/kg)
  xLs        = 2.834e6,   # latent heat of sublimation (J/kg)
  
  # Ice properties
  k          = 2.22,      # thermal conductivity (W/m/K)
  rho        = 917,       # density of ice (kg/m³)
  alpha      = 1.02e-6,   # thermal diffusivity (m²/s)
  
  # Atmospheric
  R          = 8.314,     # universal gas constant (J/mol/K)
  Ma         = 0.029,     # molar mass of air (kg/mol)
  Ca         = 1005,      # specific heat of air (J/kg/K)
  epsilon    = 0.622,     # ratio of molar masses water/dry air
  
  # Bulk transfer
  Ch         = 1.3e-3,    # sensible heat transfer coefficient
  Ce         = 1.3e-3,    # latent heat transfer coefficient
  Chi        = 0.43,      # fraction of SW absorbed at surface
  
  # Model grid
  dx         = 0.1,       # spatial step (m)
  dt         = 1/24,      # time step (days)
  L_initial  = 3.88       # initial ice thickness (m)
)

# ============================================================
# FILE PATHS — define once externally
# ============================================================
PATHS <- list(
  boym      = "~/path/to/mcmlter-clim_boym_15min-20250205.csv",
  hoem      = "~/path/to/mcmlter-clim_hoem_15min-20250205.csv",
  cohm      = "~/path/to/mcmlter-clim_cohm_15min-20250205.csv",
  tarm      = "~/path/to/mcmlter-clim_tarm_15min-20250205.csv",
  airt_elb  = "Data/air_temp_ELBBB.csv",
  airt_wlb  = "Data/air_temp_WLBBB.csv",
  ice       = "Data/mcmlter-lake-ice_thickness-20250218_0_2025.csv",
  albedo    = "Data/AlbedoModel.csv"
)


# ============================================================
# prepare_elb_model_inputs
# ============================================================
prepare_elb_model_inputs <- function(
    BOYM, HOEM, COHM, TARM,
    airt_elb, airt_wlb,
    ice_thickness,
    albedo_orig,
    constants       = CONSTANTS,
    start_filter    = as.POSIXct("2016-12-21 00:00:00"),
    wlb_end_filter  = as.POSIXct("2023-11-01 00:00:00"),
    lwr_extend_to   = as.POSIXct("2025-01-31 23:45:00"),
    ice_start       = as.POSIXct("2016-12-01"),
    ice_end         = as.POSIXct("2024-02-01"),
    n_years         = 6.95,
    lake_name       = "East Lake Bonney"
) {
  
  dx     <- constants$dx
  dt     <- constants$dt
  dt_sec <- dt * 86400
  alpha  <- constants$alpha
  r      <- alpha * dt_sec / dx^2
  nt     <- (1 / dt) * n_years * 365
  
  if (r > 0.5) stop(sprintf(
    "Stability violation: r = %.4f > 0.5. Reduce dt or increase dx.", r
  ))
  
  # ---- 1. Filter station data ---------------------------------------------
  message("Filtering met station data...")
  parse_dt <- function(x) parse_date_time(x, orders = c("ymd HMS", "mdy HM", "mdy HMS", "ymd HM"))
  
  BOYM <- BOYM |> mutate(date_time = parse_dt(date_time)) |> filter(date_time > start_filter)
  HOEM <- HOEM |> mutate(date_time = parse_dt(date_time)) |> filter(date_time > start_filter)
  COHM <- COHM |> mutate(date_time = parse_dt(date_time)) |> filter(date_time > start_filter)
  TARM <- TARM |> mutate(date_time = parse_dt(date_time)) |> filter(date_time > start_filter)
  
  # ---- 2. Time spine ------------------------------------------------------
  start_time <- min(BOYM$date_time)
  time_model <- start_time + seq(0, by = dt_sec, length.out = nt)
  
  interp_to_model <- function(datetime_vec, value_vec, label = "") {
    out <- approx(
      x    = as.numeric(datetime_vec),
      y    = value_vec,
      xout = as.numeric(time_model),
      rule = 2
    )$y
    if (length(out) != length(time_model))
      stop(sprintf("Interpolation length mismatch: %s", label))
    out
  }
  
  # ---- 3. Air temperature (ELBBB gap-filled with WLBBB) -------------------
  message("Preparing air temperature...")
  
  airt_elb <- airt_elb |>
    mutate(date_time    = mdy_hm(date_time),
           airtemp_3m_K = surface_temp_C + 273.15)
  
  airt_wlb <- airt_wlb |>
    mutate(date_time    = mdy_hm(date_time),
           airtemp_3m_K = surface_temp_C + 273.15) |>
    filter(date_time < wlb_end_filter)
  
  air_temperature <- tibble(
    date_time = seq(min(airt_elb$date_time), max(airt_elb$date_time), by = "15 min")
  ) |>
    left_join(airt_elb |> select(date_time, airtemp_3m_K), by = "date_time") |>
    left_join(airt_wlb |> select(date_time, airtemp_3m_K_wlb = airtemp_3m_K), by = "date_time") |>
    mutate(airtemp_3m_K = coalesce(airtemp_3m_K, airtemp_3m_K_wlb)) |>
    select(date_time, airtemp_3m_K)
  
  airt_interp <- interp_to_model(air_temperature$date_time,
                                 air_temperature$airtemp_3m_K, "air temperature")
  
  # ---- 4. Shortwave radiation ---------------------------------------------
  message("Preparing shortwave radiation...")
  
  sw_raw <- BOYM |>
    select(date_time, swradin_wm2) |>
    left_join(TARM |> select(date_time, swradin_wm2_tarm = swradin_wm2), by = "date_time") |>
    mutate(swradin_wm2 = coalesce(swradin_wm2, swradin_wm2_tarm)) |>
    filter(swradin_wm2 > 0) |>
    select(date_time, swradin_wm2)
  
  sw_interp <- interp_to_model(sw_raw$date_time, sw_raw$swradin_wm2, "shortwave")
  
  # ---- 5. Incoming longwave -----------------------------------------------
  message("Preparing incoming longwave radiation...")
  
  lw_in_clim <- COHM |>
    select(date_time, lwradin2_wm2) |>
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
  
  # ---- 6. Outgoing longwave -----------------------------------------------
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
  
  # ---- 7. Pressure --------------------------------------------------------
  message("Preparing pressure...")
  
  hoem_pressure   <- HOEM |> mutate(bpress_Pa = bpress_mb * 100)
  pressure_interp <- interp_to_model(hoem_pressure$date_time,
                                     hoem_pressure$bpress_Pa, "pressure")
  
  # ---- 8. Wind ------------------------------------------------------------
  message("Preparing wind speed...")
  
  wind_raw <- BOYM |>
    select(date_time, wspd_ms) |>
    left_join(TARM |> select(date_time, wspd_ms_tarm = wspd_ms), by = "date_time") |>
    mutate(wspd_ms = coalesce(wspd_ms, wspd_ms_tarm)) |>
    select(date_time, wspd_ms)
  
  wind_interp <- interp_to_model(wind_raw$date_time, wind_raw$wspd_ms, "wind")
  
  # ---- 9. Relative humidity -----------------------------------------------
  message("Preparing relative humidity...")
  
  rh_raw <- BOYM |>
    select(date_time, rhh2o_3m_pct) |>
    left_join(TARM |> select(date_time, rhh2o_3m_pct_tarm = rhh2o_3m_pct), by = "date_time") |>
    mutate(rhh2o_3m_pct = coalesce(rhh2o_3m_pct, rhh2o_3m_pct_tarm)) |>
    select(date_time, rhh2o_3m_pct)
  
  rh_interp <- interp_to_model(rh_raw$date_time, rh_raw$rhh2o_3m_pct, "relative humidity")
  
  # ---- 10. Albedo ---------------------------------------------------------
  message("Preparing albedo...")
  
  albedo_clean <- albedo_orig |>
    filter(lake == lake_name) |>
    mutate(date = ymd(sed.date)) |>
    drop_na(albedo.predict.bb)
  
  albedo_15min <- tibble(
    time = seq(floor_date(min(albedo_clean$date), "15 minutes"),
               ceiling_date(max(albedo_clean$date), "15 minutes"),
               by = "15 mins")
  ) |>
    left_join(albedo_clean |> select(date, albedo.predict.bb),
              by = c("time" = "date")) |>
    arrange(time) |>
    fill(albedo.predict.bb, .direction = "down")
  
  albedo_interp <- interp_to_model(albedo_15min$time,
                                   albedo_15min$albedo.predict.bb, "albedo")
  
  # ---- 11. Ice thickness --------------------------------------------------
  message("Filtering ice thickness observations...")
  
  ice_thickness <- ice_thickness |>
    mutate(date_time = mdy_hm(date_time),
           z_water_m = z_water_m * -1) |>
    filter(location_name == lake_name,
           date_time > ice_start,
           date_time < ice_end)
  
  # ---- 12. Assemble -------------------------------------------------------
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
    relative_humidity = rh_interp
    # NOTE: delta_T and warming are NOT applied here.
    # Call prepare_model_input() before run_ice_model().
  ) |>
    drop_na(T_air)
  
  list(
    time_series   = time_series_ELB,
    ice_thickness = ice_thickness,
    time_model    = time_model,
    params        = list(alpha = alpha, r = r, dt = dt,
                         dx = dx, L_initial = constants$L_initial, nt = nt)
  )
}


# ============================================================
# build_climate_scenario
# — no warming or trends applied internally
# — offsets/adjustments only applied if explicitly passed in
# ============================================================
build_climate_scenario <- function(
    BOYM, HOEM, COHM,         # met station dataframes passed explicitly
    airt_elb,
    airt_wlb,
    albedo_df,
    constants      = CONSTANTS,
    wlb_end_filter = as.POSIXct("2023-11-01 00:00:00"),
    lake_name      = "East Lake Bonney",
    year_start     = 2017,
    year_end       = 2024,
    flat_offsets        = list(),   # empty by default — no warming unless specified
    seasonal_adjustments = list(),  # empty by default — no trends unless specified
    season_map = list(
      summer = c(12, 1, 2),
      autumn = c(3, 4, 5),
      winter = c(6, 7, 8),
      spring = c(9, 10, 11)
    ),
    unit_conversions = list(
      pressure = function(x) x * 100
    )
) {
  
  # ---- helper: hourly climatology -----------------------------------------
  make_hourly_climatology <- function(df, value_col) {
    df |>
      mutate(yday = yday(date_time), hour = hour(date_time)) |>
      group_by(yday, hour) |>
      summarize(value = mean(.data[[value_col]], na.rm = TRUE), .groups = "drop")
  }
  
  # ---- 1. Air temperature climatology (ELBBB gap-filled with WLBBB) -------
  message("Preparing air temperature climatology...")
  
  airt_elb <- airt_elb |>
    mutate(date_time    = mdy_hm(date_time),
           airtemp_3m_K = surface_temp_C + 273.15)
  
  airt_wlb <- airt_wlb |>
    mutate(date_time    = mdy_hm(date_time),
           airtemp_3m_K = surface_temp_C + 273.15) |>
    filter(date_time < wlb_end_filter)
  
  air_temperature <- tibble(
    date_time = seq(min(airt_elb$date_time), max(airt_elb$date_time), by = "15 min")
  ) |>
    left_join(airt_elb |> select(date_time, airtemp_3m_K), by = "date_time") |>
    left_join(airt_wlb |> select(date_time, airtemp_3m_K_wlb = airtemp_3m_K), by = "date_time") |>
    mutate(airtemp_3m_K = coalesce(airtemp_3m_K, airtemp_3m_K_wlb)) |>
    select(date_time, airtemp_3m_K)
  
  air_clim <- make_hourly_climatology(air_temperature, "airtemp_3m_K")
  
  # ---- 2. Met station climatologies ---------------------------------------
  message("Preparing met station climatologies...")
  
  data_sources <- list(
    sw_in    = list(df = BOYM, col = "swradin_wm2"),
    lwr_in   = list(df = COHM, col = "lwradin2_wm2"),
    lwr_out  = list(df = COHM, col = "lwradout2_wm2"),
    pressure = list(df = HOEM, col = "bpress_mb"),
    wind     = list(df = BOYM, col = "wspd_ms"),
    rh       = list(df = BOYM, col = "rhh2o_3m_pct")
  )
  
  met_climatologies <- imap(data_sources, function(src, var_name) {
    df  <- src$df
    col <- src$col
    if (var_name %in% names(unit_conversions)) {
      df <- df |> mutate(across(all_of(col), unit_conversions[[var_name]]))
    }
    make_hourly_climatology(df, col)
  })
  
  # ---- 3. Albedo climatology (physically parameterized seasonal curve) -----
  message("Preparing albedo climatology...")
  
  # Antarctic lake ice albedo:
  # - peaks in austral summer (late December / early January) 
  #   when fresh snow covers the ice surface
  # - troughs in austral winter (July/August)
  #   when bare, sediment-laden ice is exposed
  
  target_min <- 0.28
  target_max <- 0.67
  midpoint   <- (target_max + target_min) / 2   # 0.475
  amplitude  <- (target_max - target_min) / 2   # 0.195
  peak_yday  <- 8   # approximately January 8
  
  albedo_clim <- tibble(yday = 1:365) |>
    mutate(
      value = midpoint +
        amplitude       * cos(2 * pi * (yday - peak_yday) / 365) +
        amplitude * 0.1 * cos(4 * pi * (yday - peak_yday) / 365)
    ) |>
    # safety clip in case 2nd harmonic nudges values outside bounds
    mutate(value = pmax(target_min, pmin(target_max, value))) |>
    crossing(hour = 0:23)
  
  # ---- 4. Time spine ------------------------------------------------------
  message("Building time spine...")
  
  all_times <- map(year_start:year_end, function(yr) {
    seq.POSIXt(
      from = as.POSIXct(paste0(yr, "-01-01 00:00:00")),
      to   = as.POSIXct(paste0(yr, "-12-31 23:00:00")),
      by   = "1 hour"
    )
  }) |>
    unlist(use.names = FALSE) |>
    as.POSIXct(origin = "1970-01-01", tz = "UTC")
  
  time_df <- tibble(time = all_times, yday = yday(all_times), hour = hour(all_times))
  
  # ---- 5. Join climatologies onto time spine ------------------------------
  rename_map <- c(
    air_temp = "T_air",   sw_in = "SW_in",  lwr_in = "LWR_in",
    lwr_out  = "LWR_out", pressure = "pressure", wind = "wind",
    rh = "relative_humidity", albedo = "albedo"
  )
  
  result <- time_df |>
    left_join(air_clim,                   by = c("yday", "hour")) |> rename(T_air             = value) |>
    left_join(met_climatologies$sw_in,    by = c("yday", "hour")) |> rename(SW_in             = value) |>
    left_join(met_climatologies$lwr_in,   by = c("yday", "hour")) |> rename(LWR_in            = value) |>
    left_join(met_climatologies$lwr_out,  by = c("yday", "hour")) |> rename(LWR_out           = value) |>
    left_join(met_climatologies$pressure, by = c("yday", "hour")) |> rename(pressure          = value) |>
    left_join(met_climatologies$wind,     by = c("yday", "hour")) |> rename(wind              = value) |>
    left_join(met_climatologies$rh,       by = c("yday", "hour")) |> rename(relative_humidity = value) |>
    left_join(albedo_clim,                by = c("yday", "hour")) |> rename(albedo            = value)
  
  # ---- 6. Season column ---------------------------------------------------
  month_to_season <- imap(season_map, ~ tibble(month = .x, season = .y)) |> bind_rows()
  result <- result |>
    mutate(month = month(time)) |>
    left_join(month_to_season, by = "month")
  
  # ---- 7. Apply flat offsets (only if supplied) ---------------------------
  for (var_name in names(flat_offsets)) {
    col    <- rename_map[[var_name]]
    result <- result |>
      mutate(across(all_of(col), ~ .x + flat_offsets[[var_name]]))
  }
  
  # ---- 8. Apply seasonal adjustments (only if supplied) ------------------
  for (var_name in names(seasonal_adjustments)) {
    col    <- rename_map[[var_name]]
    adj    <- seasonal_adjustments[[var_name]]
    result <- result |>
      mutate(across(all_of(col), ~ .x + adj[season]))
  }
  
  # NOTE: no warming multiplier, no delta_T, no LWR_out recomputation here.
  # Call prepare_model_input() before passing to run_ice_model().
  result
}


# ============================================================
# prepare_model_input
# — single gateway between any input source and run_ice_model
# — warming trend applied HERE and nowhere else
# ============================================================
prepare_model_input <- function(
    time_series,
    warming_rate = 0,          # 0 = no trend; set > 0 for observed pathway
    constants    = CONSTANTS
) {
  sigma      <- constants$sigma
  emissivity <- constants$emissivity
  
  # Compute delta_T (always needed by model)
  time_series <- time_series |>
    arrange(time) |>
    mutate(delta_T = T_air - lag(T_air))
  
  # Recompute LWR_out from Stefan-Boltzmann only if not already present
  # (observed pathway already has measured LWR_out)
  if (!"LWR_out" %in% names(time_series)) {
    time_series <- time_series |>
      mutate(LWR_out = (emissivity * sigma * T_air^4)*0.95)
  }
  
  # Apply compounding warming — ONLY here, ONLY if warming_rate > 0
  if (warming_rate > 0) {
    baseline_year <- min(year(time_series$time))
    time_series <- time_series |>
      mutate(
        T_air = T_air + warming_rate * (year(time) - baseline_year)
      )
  }
  
  time_series |> drop_na(delta_T)
}


run_ice_model <- function(
    time_series,
    constants     = CONSTANTS,
    show_progress = TRUE
) {
  # Unpack constants
  dx         <- constants$dx
  dt         <- constants$dt
  alpha      <- constants$alpha
  k          <- constants$k
  rho        <- constants$rho
  L_f        <- constants$L_f
  sigma      <- constants$sigma
  emissivity <- constants$emissivity
  Chi        <- constants$Chi
  Ch         <- constants$Ch
  Ce         <- constants$Ce
  Ca         <- constants$Ca
  Ma         <- constants$Ma
  R          <- constants$R
  epsilon    <- constants$epsilon
  xLv        <- constants$xLv
  xLs        <- constants$xLs
  Tf         <- constants$Tf
  L_initial  <- constants$L_initial
  
  dt_sec <- dt * 86400
  r      <- alpha * dt_sec / dx^2
  n_iter <- nrow(time_series)
  
  # Validate required columns
  required_cols <- c("time", "T_air", "SW_in", "LWR_in", "LWR_out",
                     "albedo", "pressure", "wind", "delta_T", "relative_humidity")
  missing <- setdiff(required_cols, names(time_series))
  if (length(missing) > 0)
    stop("time_series is missing columns: ", paste(missing, collapse = ", "),
         "\nDid you run prepare_model_input() first?")
  
  # Extract to plain vectors
  v_T_air  <- time_series$T_air
  v_SW_in  <- time_series$SW_in
  v_LWR_in <- time_series$LWR_in
  v_LWR_out<- time_series$LWR_out
  v_albedo <- time_series$albedo
  v_press  <- time_series$pressure
  v_wind   <- time_series$wind
  v_dT     <- time_series$delta_T
  v_rh     <- time_series$relative_humidity
  v_time   <- time_series$time
  
  # Pre-allocate outputs
  out_thickness    <- numeric(n_iter)
  out_LW_net       <- numeric(n_iter)
  out_SW           <- numeric(n_iter)
  out_SW_abs       <- numeric(n_iter)
  out_sensible_Q   <- numeric(n_iter)
  out_latent_Q     <- numeric(n_iter)
  out_conductive_Q <- numeric(n_iter)
  out_surface_flux <- numeric(n_iter)
  out_surface_loss <- numeric(n_iter)
  out_bottom_gain  <- numeric(n_iter)
  out_depth        <- vector("list", n_iter)
  out_temperature  <- vector("list", n_iter)
  
  # Initialise state
  prevL      <- L_initial
  depth      <- seq(0, L_initial, by = dx)
  prevT      <- seq(from = v_T_air[1], to = Tf, length.out = length(depth))
  dL_surface <- 0
  dL_bottom  <- 0
  
  if (show_progress) {
    pb <- progress_bar$new(
      format = "[:bar] :percent :elapsed | ETA: :eta",
      total  = n_iter, clear = FALSE
    )
  }
  
  for (t_idx in seq_len(n_iter)) {
    
    T_air   <- v_T_air[t_idx]
    SW_in   <- v_SW_in[t_idx]
    LWR_in  <- v_LWR_in[t_idx]
    LWR_out <- v_LWR_out[t_idx]
    albedo  <- v_albedo[t_idx]
    press   <- v_press[t_idx]
    wind    <- v_wind[t_idx]
    delta_T <- v_dT[t_idx]
    rh      <- v_rh[t_idx]
    
    n_nodes <- length(prevT)
    newT    <- prevT
    
    # -- 4b. Heat diffusion -------------------------------------------------
    if (n_nodes >= 3) {
      interior <- 2:(n_nodes - 1)
      newT[interior] <- prevT[interior] +
        r * (prevT[interior + 1] - 2 * prevT[interior] + prevT[interior - 1])
    }
    
    # catch any NAs introduced by diffusion (e.g. from NA forcing values)
    if (any(is.na(newT))) newT <- prevT
    
    # -- 4c. Boundary conditions --------------------------------------------
    if (n_nodes >= 2) {
      newT[1]       <- T_air
      newT[n_nodes] <- Tf
    } else if (n_nodes == 1) {
      newT[1] <- T_air
    }
    
    # -- 4d. Radiative fluxes -----------------------------------------------
    SW_abs <- (1 - Chi) * SW_in * (1 - albedo)
    LW_net <- LWR_in - LWR_out
    
    # -- 4e. Sensible heat flux ---------------------------------------------
    rho_air <- (press * Ma) * 0.1 / (R * T_air)
    Qh      <- rho_air * Ca * Ch * delta_T * wind
    
    # -- 4f. Latent heat flux (phase-dependent) -----------------------------
    if (length(newT) > 0 && newT[1] >= Tf) {
      A <- 6.1121; B <- 17.502; C <- 240.97; xLatent <- xLv
    } else {
      A <- 6.1115; B <- 22.452; C <- 272.55; xLatent <- xLs
    }
    
    T_ref       <- T_air - Tf
    ea          <- ((rh / 100) * A * exp((B * T_ref) / (C + T_ref))) / 100
    rho_air_lat <- press * Ma / (R * T_air) * (1 + (epsilon - 1) * (ea / press))
    es0         <- if (length(newT) > 0 && newT[1] >= Tf) {
      (A * exp(0)) / 100
    } else {
      (A * exp((B * T_ref) / (C + T_ref))) / 100
    }
    Ql <- rho_air_lat * xLatent * Ce * (0.622 / press) * (ea - es0) * wind
    
    # -- 4g. Conductive flux ------------------------------------------------
    Qc <- if (length(prevT) >= 1) k * (prevT[1] - T_air) / dx else 0
    
    # -- 4h. Net surface flux and mass balance ------------------------------
    surface_flux <- SW_abs + (LW_net - Qc) + Qh + Ql
    
    dL_surface <- 0
    if (!is.na(surface_flux) && surface_flux > 0) {
      dL_surface <- surface_flux * dt_sec / (rho * L_f)
    }
    
    newL <- prevL - dL_surface
    
    dL_bottom <- 0
    if (!is.na(newL) && newL > 0 && n_nodes >= 2) {
      Q_bottom  <- -k * (newT[n_nodes - 1] - newT[n_nodes]) / dx
      dL_bottom <- Q_bottom * dt_sec / (rho * L_f)
      newL      <- newL + dL_bottom
    }
    
    newL <- max(0, newL)
    
    # -- 4i. Regrid temperature profile to new thickness -------------------
    if (newL > 0 && prevL > 0 && length(newT) >= 2 && !all(is.na(newT))) {
      newdepth <- seq(0, newL, by = dx)
      old_grid <- seq(0, prevL, length.out = length(depth))
      
      if (length(unique(old_grid)) >= 2 && length(newdepth) >= 2) {
        # normal case: interpolate onto new grid
        newT <- approx(
          x    = old_grid,
          y    = newT,
          xout = seq(0, newL, length.out = length(newdepth)),
          rule = 2
        )$y
      } else {
        # ice too thin to interpolate — hold mean temperature
        newT <- rep(mean(newT, na.rm = TRUE), length(newdepth))
      }
      
    } else if (newL <= 0) {
      # no ice remaining
      newdepth <- NA_real_
      newT     <- numeric(0)
      
    } else {
      # newT was all NA or length < 2 — reset to linear gradient as fallback
      newdepth <- seq(0, newL, by = dx)
      newT     <- seq(from = T_air, to = Tf, length.out = length(newdepth))
    }
    
    # -- 4j. Advance state --------------------------------------------------
    prevT <- newT
    prevL <- newL
    depth <- newdepth
    
    # -- 4k. Store outputs --------------------------------------------------
    out_thickness[t_idx]    <- prevL
    out_LW_net[t_idx]       <- LW_net
    out_SW[t_idx]           <- SW_in
    out_SW_abs[t_idx]       <- SW_abs
    out_sensible_Q[t_idx]   <- Qh
    out_latent_Q[t_idx]     <- Ql
    out_conductive_Q[t_idx] <- Qc
    out_surface_flux[t_idx] <- surface_flux
    out_surface_loss[t_idx] <- dL_surface
    out_bottom_gain[t_idx]  <- dL_bottom
    out_depth[[t_idx]]      <- depth
    out_temperature[[t_idx]]<- prevT
    
    if (show_progress) pb$tick()
  }
  
  tibble(
    time              = v_time,
    thickness         = out_thickness,
    LW_net            = out_LW_net,
    SW                = out_SW,
    SW_abs            = out_SW_abs,
    sensible_Q        = out_sensible_Q,
    latent_Q          = out_latent_Q,
    conductive_Q      = out_conductive_Q,
    surface_heat_flux = out_surface_flux,
    surface_loss      = out_surface_loss,
    bottom_gain       = out_bottom_gain,
    depth             = out_depth,
    temperature       = out_temperature
  )
}

plot_scenario <- function(
    scenario_df,
    variables      = c("T_air", "SW_in", "LWR_in", "LWR_out",
                       "pressure", "wind", "relative_humidity", "albedo"),
    baseline_df    = NULL,
    baseline_label = "Baseline",
    scenario_label = "Scenario",
    smooth         = "month",
    output         = "print",   # "print", "patchwork", or "list"
    scenario_colour = "#E8593C",
    baseline_colour = "#3B8BD4"
) {
  
  # ---- metadata: display label and y-axis unit per variable ---------------
  var_meta <- tribble(
    ~col,               ~label,                     ~units,
    "T_air",            "Air temperature",          "K",
    "SW_in",            "Shortwave in",             "W m⁻²",
    "LWR_in",           "Longwave in",              "W m⁻²",
    "LWR_out",          "Longwave out",             "W m⁻²",
    "pressure",         "Atmospheric pressure",     "Pa",
    "wind",             "Wind speed",               "m s⁻¹",
    "relative_humidity","Relative humidity",        "%",
    "albedo",           "Albedo",                   "0–1"
  ) |>
    filter(col %in% variables)
  
  # ---- helper: smooth to chosen temporal resolution -----------------------
  aggregate_ts <- function(df, cols) {
    if (smooth == "none") return(df)
    df |>
      mutate(period = floor_date(time, switch(smooth,
                                              day   = "day",
                                              week  = "week",
                                              month = "month"
      ))) |>
      group_by(period) |>
      summarize(across(all_of(cols), ~ mean(.x, na.rm = TRUE)),
                .groups = "drop") |>
      rename(time = period)
  }
  
  # ---- shared theme -------------------------------------------------------
  scen_theme <- function() {
    theme_minimal(base_size = 11) +
      theme(
        plot.title       = element_text(size = 10, face = "bold",
                                        margin = margin(b = 4)),
        axis.text.x      = element_text(size = 8),
        axis.text.y      = element_text(size = 8),
        panel.grid.minor = element_blank(),
        panel.grid.major = element_line(colour = "grey92"),
        legend.position  = "bottom",
        legend.text      = element_text(size = 9)
      )
  }
  
  # ---- build one panel per variable ---------------------------------------
  make_panel <- function(var_col, meta) {
    
    # only keep columns that exist in the df (LWR_out may be absent
    # from scenario df if not yet run through prepare_model_input)
    if (!var_col %in% names(scenario_df)) {
      message(sprintf("Skipping '%s' — column not found in scenario_df.", var_col))
      return(NULL)
    }
    
    agg_scen <- aggregate_ts(scenario_df |> select(time, all_of(var_col)),
                             var_col)
    
    p <- ggplot(agg_scen, aes(x = time, y = .data[[var_col]]))
    
    if (!is.null(baseline_df) && var_col %in% names(baseline_df)) {
      agg_base <- aggregate_ts(baseline_df |> select(time, all_of(var_col)),
                               var_col)
      p <- p +
        geom_line(data  = agg_base,
                  aes(x = time, y = .data[[var_col]], colour = baseline_label),
                  linewidth = 0.5, alpha = 0.8) +
        geom_line(aes(colour = scenario_label),
                  linewidth = 0.7, alpha = 0.9) +
        scale_colour_manual(
          name   = NULL,
          values = setNames(c(baseline_colour, scenario_colour),
                            c(baseline_label,  scenario_label))
        )
    } else {
      p <- p +
        geom_line(colour = scenario_colour, linewidth = 0.7, alpha = 0.9)
    }
    
    p +
      labs(title = meta$label, x = NULL, y = meta$units) +
      scen_theme()
  }
  
  # ---- build all panels ---------------------------------------------------
  panels <- map2(
    var_meta$col,
    split(var_meta, seq_len(nrow(var_meta))),
    make_panel
  ) |>
    setNames(var_meta$col) |>
    purrr::compact()   # drop any NULLs from skipped variables
  
  if (length(panels) == 0) {
    message("No panels to display — check that variable names match column names.")
    return(invisible(NULL))
  }
  
  if (output == "list") return(panels)
  
  # ---- assemble with patchwork --------------------------------------------
  combined <- wrap_plots(panels, ncol = 2) +
    plot_annotation(
      title    = paste("Climate forcing:", scenario_label),
      subtitle = paste(
        "Smoothed to:", smooth,
        "| Years:", year(min(scenario_df$time, na.rm = TRUE)),
        "\u2013", year(max(scenario_df$time, na.rm = TRUE))
      ),
      theme = theme(
        plot.title    = element_text(size = 13, face = "bold"),
        plot.subtitle = element_text(size = 9,  colour = "grey50")
      )
    )
  
  if (output == "patchwork") return(combined)
  
  print(combined)
  invisible(panels)
}

plot_ice_model <- function(
    results,
    ice_thickness     = NULL,        # optional observed validation df
    datetime_col      = "date_time", # datetime column name in ice_thickness
    observed_col      = "z_water_m", # thickness column name in ice_thickness
    title             = "East Lake Bonney",
    subtitle          = NULL,
    plot_thickness    = TRUE,
    plot_fluxes       = TRUE,
    plot_temp_profile = TRUE,
    flux_vars         = c("SW_abs", "LW_net", "sensible_Q", "latent_Q",
                          "conductive_Q", "surface_heat_flux"),
    smooth            = "day",       # "none", "day", "week", "month"
    model_colour      = "#2166ac",
    observed_colour   = "#d6604d",
    output            = "print"      # "print", "patchwork", or "list"
) {
  
  plots <- list()
  
  # ---- helper: smooth to chosen temporal resolution -----------------------
  smooth_df <- function(df, value_cols) {
    if (smooth == "none") return(df)
    df |>
      mutate(period = floor_date(time, switch(smooth,
                                              day   = "day",
                                              week  = "week",
                                              month = "month"
      ))) |>
      group_by(period) |>
      summarize(across(all_of(value_cols), ~ mean(.x, na.rm = TRUE)),
                .groups = "drop") |>
      rename(time = period)
  }
  
  # ---- shared theme -------------------------------------------------------
  ice_theme <- function() {
    theme_minimal(base_size = 12) +
      theme(
        plot.title        = element_text(size = 11, face = "bold",
                                         margin = margin(b = 4)),
        panel.grid.minor  = element_blank(),
        panel.grid.major  = element_line(colour = "grey92"),
        axis.text.x       = element_text(size = 9),
        axis.text.y       = element_text(size = 9),
        legend.position   = "bottom",
        legend.text       = element_text(size = 9)
      )
  }
  
  # ======================================================================
  # Panel 1: Ice thickness
  # ======================================================================
  if (plot_thickness) {
    
    thick_df <- results |>
      select(time, thickness) |>
      smooth_df("thickness")
    
    p_thick <- ggplot(thick_df, aes(x = time, y = thickness)) +
      geom_line(colour = model_colour, linewidth = 0.8) +
      labs(title = "Ice thickness", x = NULL, y = "Thickness (m)") +
      ice_theme()
    
    if (!is.null(ice_thickness)) {
      obs <- ice_thickness |>
        rename(time = all_of(datetime_col),
               obs  = all_of(observed_col)) |>
        filter(!is.na(time), !is.na(obs))
      
      p_thick <- p_thick +
        geom_point(data = obs, aes(x = time, y = obs),
                   colour = observed_colour, size = 1.2, alpha = 0.7)
    }
    
    plots$thickness <- p_thick
  }
  
  # ======================================================================
  # Panel 2: Surface energy fluxes
  # ======================================================================
  if (plot_fluxes) {
    
    flux_labels <- c(
      SW_abs            = "Absorbed SW (W m\u207b\u00b2)",
      LW_net            = "Net LW (W m\u207b\u00b2)",
      sensible_Q        = "Sensible heat (W m\u207b\u00b2)",
      latent_Q          = "Latent heat (W m\u207b\u00b2)",
      conductive_Q      = "Conductive heat (W m\u207b\u00b2)",
      surface_heat_flux = "Net surface flux (W m\u207b\u00b2)",
      surface_loss      = "Surface melt (m)",
      bottom_gain       = "Bottom growth (m)"
    )
    
    available_flux <- intersect(flux_vars, names(results))
    
    if (length(available_flux) > 0) {
      flux_df <- results |>
        select(time, all_of(available_flux)) |>
        smooth_df(available_flux) |>
        pivot_longer(-time, names_to = "variable", values_to = "value") |>
        mutate(variable = factor(variable,
                                 levels = available_flux,
                                 labels = flux_labels[available_flux]))
      
      p_flux <- ggplot(flux_df, aes(x = time, y = value)) +
        geom_line(colour = model_colour, linewidth = 0.5, alpha = 0.85) +
        geom_hline(yintercept = 0, linetype = "dashed",
                   colour = "grey60", linewidth = 0.4) +
        facet_wrap(~ variable, scales = "free_y", ncol = 2) +
        labs(title = paste("Surface energy fluxes \u2014", smooth, "mean"),
             x = NULL, y = NULL) +
        ice_theme() +
        theme(strip.text = element_text(size = 9))
      
      plots$fluxes <- p_flux
    } else {
      message("No matching flux columns found in results — skipping flux panel.")
    }
  }
  
  # ======================================================================
  # Panel 3: Temperature profile snapshots
  # ======================================================================
  if (plot_temp_profile) {
    
    # filter to rows where depth/temperature profiles are non-empty
    valid_rows <- results |>
      filter(map_lgl(depth, ~ length(.x) > 1 && !all(is.na(.x))))
    
    if (nrow(valid_rows) >= 2) {
      snap_idx   <- round(seq(1, nrow(valid_rows), length.out = 6))
      snap_times <- valid_rows$time[snap_idx]
      
      profile_df <- valid_rows |>
        filter(time %in% snap_times) |>
        select(time, depth, temperature) |>
        mutate(
          depth       = map(depth,       as.numeric),
          temperature = map(temperature, as.numeric)
        ) |>
        unnest(cols = c(depth, temperature)) |>
        filter(!is.na(depth), !is.na(temperature)) |>
        mutate(label = format(time, "%Y-%m-%d"))
      
      p_profile <- ggplot(profile_df,
                          aes(x = temperature - 273.15, y = -depth,
                              colour = label, group = label)) +
        geom_path(linewidth = 0.7) +
        scale_colour_brewer(palette = "Blues", direction = 1, name = NULL) +
        labs(title = "Temperature profile snapshots",
             x     = "Temperature (\u00b0C)",
             y     = "Depth (m)") +
        ice_theme()
      
      plots$temp_profile <- p_profile
    } else {
      message("Not enough valid profile snapshots to plot — skipping temp profile panel.")
    }
  }
  
  # ======================================================================
  # Assemble and return
  # ======================================================================
  n <- length(plots)
  
  if (n == 0) {
    message("No panels to display.")
    return(invisible(NULL))
  }
  
  if (output == "list") return(plots)
  
  combined <- if (plot_thickness && n > 1) {
    bottom_plots <- plots[names(plots) != "thickness"]
    plots$thickness /
      wrap_plots(bottom_plots, ncol = if (length(bottom_plots) == 1) 1 else 2) +
      plot_layout(heights = c(2, 3))
  } else {
    wrap_plots(plots, ncol = 1)
  }
  
  combined <- combined +
    plot_annotation(
      title    = title,
      subtitle = subtitle %||% paste(
        "Smoothing:", smooth,
        "| Years:", year(min(results$time, na.rm = TRUE)),
        "\u2013",   year(max(results$time, na.rm = TRUE))
      ),
      theme = theme(
        plot.title    = element_text(size = 14, face = "bold"),
        plot.subtitle = element_text(size = 9,  colour = "grey50")
      )
    )
  
  if (output == "patchwork") return(combined)
  
  print(combined)
  invisible(plots)
}
