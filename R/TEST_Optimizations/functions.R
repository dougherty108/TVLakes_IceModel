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
  S          = 1367,      # solar constant (W/m^2) — used for artificial/clear-sky SW fallback
  
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
  frlm      = "~/path/to/mcmlter-clim_frlm_15min-20250205.csv",
  exem      = "~/path/to/mcmlter-clim_exem_15min-20250205.csv",
  airt_elb  = "Data/air_temp_ELBBB.csv",
  airt_wlb  = "Data/air_temp_WLBBB.csv",
  airt_lh   = "Data/air_temp_LHBB.csv",
  airt_lf   = "Data/air_temp_LFBB.csv",
  ice       = "Data/mcmlter-lake-ice_thickness-20250218_0_2025.csv",
  albedo    = "Data/AlbedoModel.csv"
)

# ============================================================
# LAKE_CONFIGS — single source of truth for what makes each
# modeling scenario "bespoke":
#   - lake_name            : filter value for ice-thickness & albedo tables
#   - L_initial / Chi      : lake-specific model parameters (overrides CONSTANTS)
#   - start_filter         : met-record start date that lines up with the
#                            ice-to-ice thickness measurement used for L_initial
#   - n_years              : length of the model run (years)
#   - base_station         : station whose record anchors the model time spine
#   - stations_needed      : met stations that must be supplied in `station_data`
#   - air_temp             : primary/secondary station + the (lake-specific)
#                            column name holding surface temperature in °C
#   - shortwave/wind/humidity : primary station to use, secondary station to
#                            gap-fill from, and (for SW) whether to fall back
#                            on a clear-sky estimate built from sun angle
#   - coords               : lat/lon used for the clear-sky SW fallback
#   - ice_loc_filter       : optional extra filter on the `location` column of
#                            the ice-thickness validation data (e.g. WLB only
#                            uses the "Inside" mooring; LF only uses sites
#                            beginning with "O")
# ============================================================
LAKE_CONFIGS <- list(

  ELB = list(
    lake_name       = "East Lake Bonney",
    L_initial       = 3.88,   # ice-to-ice thickness on 2016-12-17
    Chi             = 0.40,
    start_filter    = as.POSIXct("2016-12-21 00:00:00"),
    n_years         = 6.95,
    base_station    = "BOYM",
    stations_needed = c("BOYM", "HOEM", "COHM", "TARM"),
    air_temp  = list(primary_col = "surface_temp_C", secondary_col = "surface_temp_C"),
    shortwave = list(primary = "BOYM", secondary = "TARM", use_artificial = FALSE),
    wind      = list(primary = "BOYM", secondary = "TARM"),
    humidity  = list(primary = "BOYM", secondary = "TARM"),
    coords         = list(lat = -77.13449, lon = 162.449716),
    ice_loc_filter = NULL
  ),

  WLB = list(
    lake_name       = "West Lake Bonney",
    L_initial       = 3.39,   # ice-to-ice thickness on 2016-12-17
    Chi             = 0.30,
    start_filter    = as.POSIXct("2016-12-23 00:00:00"),
    n_years         = 6.95,
    base_station    = "BOYM",
    stations_needed = c("BOYM", "HOEM", "COHM", "TARM"),
    air_temp  = list(primary_col = "surface_temp_C", secondary_col = "surface_temp_C"),
    shortwave = list(primary = "BOYM", secondary = "TARM", use_artificial = TRUE),
    wind      = list(primary = "BOYM", secondary = "TARM"),
    humidity  = list(primary = "BOYM", secondary = "TARM"),
    coords         = list(lat = -77.13449, lon = 162.449716),
    ice_loc_filter = function(df) dplyr::filter(df, str_detect(location, "Inside"))
  ),

  LH = list(
    lake_name       = "Lake Hoare",
    L_initial       = 3.50,   # ice-to-ice thickness on 2016-12-17
    Chi             = 0.40,
    start_filter    = as.POSIXct("2016-12-14 00:00:00"),
    n_years         = 6.95,
    base_station    = "HOEM",
    stations_needed = c("HOEM", "COHM", "TARM", "FRLM"),
    air_temp  = list(primary_col = "surftemp_degC", secondary_col = "surftemp_degc"),
    shortwave = list(primary = "HOEM", secondary = "FRLM", use_artificial = TRUE),
    wind      = list(primary = "HOEM", secondary = "FRLM"),
    humidity  = list(primary = "HOEM", secondary = "FRLM"),
    coords         = list(lat = -77.13449, lon = 162.449716),
    ice_loc_filter = NULL
  ),

  LF = list(
    lake_name       = "Lake Fryxell",
    L_initial       = 4.60,   # ice-to-ice thickness on 2016-12-17
    Chi             = 0.40,
    start_filter    = as.POSIXct("2016-12-11 00:00:00"),
    n_years         = 6.95,   # NOTE: legacy 00_LF_data_preparation.R used 20 — see message at end of refactor
    base_station    = "FRLM",
    stations_needed = c("HOEM", "COHM", "TARM", "FRLM", "EXEM"),
    air_temp  = list(primary_col = "surftemp_degc", secondary_col = "surface_temp_C"),
    shortwave = list(primary = "FRLM", secondary = "EXEM", use_artificial = TRUE),
    wind      = list(primary = "FRLM", secondary = "EXEM"),
    humidity  = list(primary = "FRLM", secondary = "EXEM"),
    coords         = list(lat = -77.13449, lon = 162.449716),
    ice_loc_filter = function(df) dplyr::filter(df, str_starts(location, "O"))
  )
)


# ============================================================
# lake_constants
# — returns CONSTANTS with lake-specific overrides (L_initial,
#   Chi) applied. Pass the result to run_ice_model() so each
#   scenario uses its own ice-thickness start point and solar
#   absorption fraction without duplicating the constants list.
# ============================================================
lake_constants <- function(lake_key, lake_configs = LAKE_CONFIGS, constants = CONSTANTS) {
  cfg <- lake_configs[[lake_key]]
  if (is.null(cfg)) stop(sprintf(
    "Unknown lake_key '%s'. Valid options: %s",
    lake_key, paste(names(lake_configs), collapse = ", ")
  ))
  modifyList(constants, list(L_initial = cfg$L_initial, Chi = cfg$Chi))
}


# ============================================================
# prepare_lake_model_inputs
# — lake-agnostic replacement for prepare_elb_model_inputs().
#   Driven entirely by LAKE_CONFIGS so the same function can
#   assemble model-ready inputs for ELB, WLB, LH, or LF: it
#   selects the right start date, met-station combination,
#   air-temperature gap-filling pair, albedo lake filter, and
#   ice-thickness validation subset for whichever lake_key is
#   requested.
#
#   station_data : named list of raw met station tibbles, e.g.
#                  list(BOYM = BOYM, HOEM = HOEM, COHM = COHM,
#                       TARM = TARM, FRLM = FRLM, EXEM = EXEM)
#                  — only the stations in cfg$stations_needed
#                  must be present for a given lake.
#   airt_primary / airt_secondary : raw (unparsed) air-temperature
#                  station tibbles to gap-fill against each other,
#                  e.g. ELBBB + WLBBB for ELB, LFBB + ELBBB for LF.
# ============================================================
prepare_lake_model_inputs <- function(
    lake_key,
    station_data,
    airt_primary,
    airt_secondary,
    ice_thickness,
    albedo_orig,
    n_years           = NULL,   # adjustable run length (years); NULL = use LAKE_CONFIGS
                                 # default; pass "max" to auto-size the run to span this
                                 # lake's full filtered station record (e.g. for building
                                 # long climatological baselines — see
                                 # generate_climatological_climate())
    lake_configs      = LAKE_CONFIGS,
    constants         = CONSTANTS,
    coords            = list(lat = -77.13449, lon = 162.449716),
    start_filter      = NULL,   # override cfg$start_filter, e.g. to pull a much longer
                                # historical record (back into the 1990s) for climatology
                                # purposes; NULL = use this lake's configured start date
    secondary_air_end = as.POSIXct("2023-11-01 00:00:00"),
    lwr_extend_to     = as.POSIXct("2025-01-31 23:45:00"),
    ice_start         = as.POSIXct("2016-12-01"),
    ice_end           = as.POSIXct("2024-02-01")
) {

  cfg <- lake_configs[[lake_key]]
  if (is.null(cfg)) stop(sprintf(
    "Unknown lake_key '%s'. Valid options: %s",
    lake_key, paste(names(lake_configs), collapse = ", ")
  ))

  message(sprintf("Preparing model inputs for %s (%s)...", cfg$lake_name, lake_key))

  coords <- cfg$coords %||% coords

  # n_years is adjustable at call time — pass it explicitly to run the model
  # for a longer/shorter period than the lake's default (e.g. for forecasting
  # experiments), or pass "max" to size the run to this lake's entire filtered
  # station record. Falls back to the lake's configured default, then 6.95.
  n_years_arg <- n_years %||% cfg$n_years %||% 6.95

  # start_filter is adjustable at call time too — pass an early date (e.g.
  # as.POSIXct("1990-01-01")) to pull a much longer historical record than
  # this lake's normal modeling start date. Falls back to cfg$start_filter.
  eff_start_filter <- start_filter %||% cfg$start_filter

  dx      <- constants$dx
  dt      <- constants$dt
  dt_sec  <- dt * 86400
  alpha   <- constants$alpha
  r       <- alpha * dt_sec / dx^2

  if (r > 0.5) stop(sprintf(
    "Stability violation: r = %.4f > 0.5. Reduce dt or increase dx.", r
  ))

  # ---- 1. Filter station data to the (possibly overridden) start date -----
  message(sprintf("Filtering met station data from %s...", format(eff_start_filter)))
  parse_dt <- function(x) parse_date_time(x, orders = c("ymd HMS", "mdy HM", "mdy HMS", "ymd HM"))

  missing_stations <- setdiff(cfg$stations_needed, names(station_data))
  if (length(missing_stations) > 0) stop(sprintf(
    "prepare_lake_model_inputs(): station_data is missing required stations for %s: %s",
    lake_key, paste(missing_stations, collapse = ", ")
  ))

  stations <- map(station_data[cfg$stations_needed], function(df) {
    df |> mutate(date_time = parse_dt(date_time)) |> filter(date_time > eff_start_filter)
  })

  # ---- 2. Time spine -------------------------------------------------------
  start_time <- min(stations[[cfg$base_station]]$date_time)

  if (identical(n_years_arg, "max")) {
    # Auto-size the run length to span this lake's entire filtered station
    # record (handy for building long climatological baselines — the model
    # grid then covers as much observed history as is actually available,
    # rather than a fixed/guessed number of years).
    end_time  <- max(stations[[cfg$base_station]]$date_time)
    span_days <- as.numeric(difftime(end_time, start_time, units = "days"))
    nt        <- floor(span_days / dt)
    n_years   <- span_days / 365
    message(sprintf("  ...n_years = \"max\": sizing run to the full filtered record (~%.1f years: %s -> %s)",
                    n_years, format(start_time), format(end_time)))
  } else {
    n_years <- n_years_arg
    nt      <- (1 / dt) * n_years * 365
  }

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

  # ---- 3. Air temperature (primary station gap-filled with secondary) -----
  message("Preparing air temperature...")

  airt_primary <- airt_primary |>
    mutate(date_time    = mdy_hm(date_time),
           airtemp_3m_K = .data[[cfg$air_temp$primary_col]] + 273.15)

  airt_secondary <- airt_secondary |>
    mutate(date_time    = mdy_hm(date_time),
           airtemp_3m_K = .data[[cfg$air_temp$secondary_col]] + 273.15) |>
    filter(date_time < secondary_air_end)

  air_temperature <- tibble(
    date_time = seq(min(airt_primary$date_time), max(airt_primary$date_time), by = "15 min")
  ) |>
    left_join(airt_primary   |> select(date_time, airtemp_3m_K), by = "date_time") |>
    left_join(airt_secondary |> select(date_time, airtemp_3m_K_alt = airtemp_3m_K), by = "date_time") |>
    mutate(airtemp_3m_K = coalesce(airtemp_3m_K, airtemp_3m_K_alt)) |>
    select(date_time, airtemp_3m_K)

  airt_interp <- interp_to_model(air_temperature$date_time,
                                 air_temperature$airtemp_3m_K, "air temperature")

  # ---- 4. Shortwave radiation (primary gap-filled with secondary, -----------
  # ----    optionally backstopped by a clear-sky estimate from sun angle) ----
  message("Preparing shortwave radiation...")

  sw_primary_df   <- stations[[cfg$shortwave$primary]]
  sw_secondary_df <- stations[[cfg$shortwave$secondary]]

  sw_raw <- sw_primary_df |>
    select(date_time, swradin_wm2) |>
    left_join(sw_secondary_df |> select(date_time, swradin_wm2_alt = swradin_wm2), by = "date_time") |>
    mutate(swradin_wm2 = coalesce(swradin_wm2, swradin_wm2_alt)) |>
    select(date_time, swradin_wm2)

  if (isTRUE(cfg$shortwave$use_artificial)) {
    message("  ...gap-filling shortwave with a clear-sky estimate from sun angle")
    artificial_shortwave <- tibble(
      date_time = time_model,
      zenith    = 90 - suncalc::getSunlightPosition(time_model, lat = coords$lat, lon = coords$lon)$altitude,
      sw        = constants$S * cos(zenith) * 3.0   # x3 empirical scaling to match historical mean
    )
    sw_raw <- sw_raw |>
      left_join(artificial_shortwave |> select(date_time, sw), by = "date_time") |>
      mutate(swradin_wm2 = coalesce(swradin_wm2, sw)) |>
      select(date_time, swradin_wm2)
  }

  sw_raw <- sw_raw |> filter(swradin_wm2 > 0)

  sw_interp <- interp_to_model(sw_raw$date_time, sw_raw$swradin_wm2, "shortwave")

  # ---- 5. Incoming longwave (always sourced from COHM) --------------------
  message("Preparing incoming longwave radiation...")

  COHM <- stations$COHM

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

  # ---- 6. Outgoing longwave (always sourced from COHM) --------------------
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

  # ---- 7. Pressure (always sourced from HOEM) ------------------------------
  message("Preparing pressure...")

  hoem_pressure   <- stations$HOEM |> mutate(bpress_Pa = bpress_mb * 100)
  pressure_interp <- interp_to_model(hoem_pressure$date_time,
                                     hoem_pressure$bpress_Pa, "pressure")

  # ---- 8. Wind (lake-specific primary/secondary stations) -----------------
  message("Preparing wind speed...")

  wind_primary_df   <- stations[[cfg$wind$primary]]
  wind_secondary_df <- stations[[cfg$wind$secondary]]

  wind_raw <- wind_primary_df |>
    select(date_time, wspd_ms) |>
    left_join(wind_secondary_df |> select(date_time, wspd_ms_alt = wspd_ms), by = "date_time") |>
    mutate(wspd_ms = coalesce(wspd_ms, wspd_ms_alt)) |>
    select(date_time, wspd_ms)

  wind_interp <- interp_to_model(wind_raw$date_time, wind_raw$wspd_ms, "wind")

  # ---- 9. Relative humidity (lake-specific primary/secondary stations) ----
  message("Preparing relative humidity...")

  rh_primary_df   <- stations[[cfg$humidity$primary]]
  rh_secondary_df <- stations[[cfg$humidity$secondary]]

  rh_raw <- rh_primary_df |>
    select(date_time, rhh2o_3m_pct) |>
    left_join(rh_secondary_df |> select(date_time, rhh2o_3m_pct_alt = rhh2o_3m_pct), by = "date_time") |>
    mutate(rhh2o_3m_pct = coalesce(rhh2o_3m_pct, rhh2o_3m_pct_alt)) |>
    select(date_time, rhh2o_3m_pct)

  rh_interp <- interp_to_model(rh_raw$date_time, rh_raw$rhh2o_3m_pct, "relative humidity")

  # ---- 10. Albedo (filtered to this lake) ----------------------------------
  message("Preparing albedo...")

  albedo_clean <- albedo_orig |>
    filter(lake == cfg$lake_name) |>
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

  # ---- 11. Ice thickness validation data (lake- and site-specific) --------
  message("Filtering ice thickness observations...")

  ice_thickness_clean <- ice_thickness |>
    mutate(date_time = mdy_hm(date_time),
           z_water_m = z_water_m * -1) |>
    filter(location_name == cfg$lake_name,
           date_time > ice_start,
           date_time < ice_end)

  if (!is.null(cfg$ice_loc_filter)) {
    ice_thickness_clean <- cfg$ice_loc_filter(ice_thickness_clean)
  }

  # ---- 12. Assemble ---------------------------------------------------------
  message("Assembling time series...")

  time_series_out <- tibble(
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
    lake_key      = lake_key,
    lake_name     = cfg$lake_name,
    time_series   = time_series_out,
    ice_thickness = ice_thickness_clean,
    time_model    = time_model,
    params        = list(alpha = alpha, r = r, dt = dt, dx = dx,
                         L_initial = cfg$L_initial, Chi = cfg$Chi,
                         nt = nt, n_years = n_years)
  )
}


# ============================================================
# build_climate_scenario
# — lake-agnostic, LAKE_CONFIGS-driven climate scenario builder
# — no warming or trends applied internally
# — offsets/adjustments only applied if explicitly passed in
#
#   station_data : named list of raw met station tibbles (only the
#                  stations in cfg$stations_needed must be present),
#                  e.g. list(BOYM = BOYM, HOEM = HOEM, COHM = COHM,
#                            TARM = TARM, FRLM = FRLM, EXEM = EXEM)
#   airt_primary / airt_secondary : raw air-temperature station
#                  tibbles to gap-fill against each other (same
#                  pairing used in prepare_lake_model_inputs())
# ============================================================
build_climate_scenario <- function(
    lake_key,
    station_data,
    airt_primary,
    airt_secondary,
    albedo_df,
    lake_configs      = LAKE_CONFIGS,
    constants         = CONSTANTS,
    secondary_air_end = as.POSIXct("2023-11-01 00:00:00"),
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

  cfg <- lake_configs[[lake_key]]
  if (is.null(cfg)) stop(sprintf(
    "Unknown lake_key '%s'. Valid options: %s",
    lake_key, paste(names(lake_configs), collapse = ", ")
  ))

  message(sprintf("Building climate scenario for %s (%s)...", cfg$lake_name, lake_key))

  missing_stations <- setdiff(cfg$stations_needed, names(station_data))
  if (length(missing_stations) > 0) stop(sprintf(
    "build_climate_scenario(): station_data is missing required stations for %s: %s",
    lake_key, paste(missing_stations, collapse = ", ")
  ))

  # ---- helper: hourly climatology -----------------------------------------
  make_hourly_climatology <- function(df, value_col) {
    df |>
      mutate(yday = yday(date_time), hour = hour(date_time)) |>
      group_by(yday, hour) |>
      summarize(value = mean(.data[[value_col]], na.rm = TRUE), .groups = "drop")
  }

  # ---- 1. Air temperature climatology (lake-specific gap-fill pair) -------
  message("Preparing air temperature climatology...")

  airt_primary <- airt_primary |>
    mutate(date_time    = mdy_hm(date_time),
           airtemp_3m_K = .data[[cfg$air_temp$primary_col]] + 273.15)

  airt_secondary <- airt_secondary |>
    mutate(date_time    = mdy_hm(date_time),
           airtemp_3m_K = .data[[cfg$air_temp$secondary_col]] + 273.15) |>
    filter(date_time < secondary_air_end)

  air_temperature <- tibble(
    date_time = seq(min(airt_primary$date_time), max(airt_primary$date_time), by = "15 min")
  ) |>
    left_join(airt_primary   |> select(date_time, airtemp_3m_K), by = "date_time") |>
    left_join(airt_secondary |> select(date_time, airtemp_3m_K_alt = airtemp_3m_K), by = "date_time") |>
    mutate(airtemp_3m_K = coalesce(airtemp_3m_K, airtemp_3m_K_alt)) |>
    select(date_time, airtemp_3m_K)

  air_clim <- make_hourly_climatology(air_temperature, "airtemp_3m_K")

  # ---- 2. Met station climatologies (lake-specific station combination) ---
  message("Preparing met station climatologies...")

  data_sources <- list(
    sw_in    = list(df = station_data[[cfg$shortwave$primary]], col = "swradin_wm2"),
    lwr_in   = list(df = station_data$COHM,                     col = "lwradin2_wm2"),
    lwr_out  = list(df = station_data$COHM,                     col = "lwradout2_wm2"),
    pressure = list(df = station_data$HOEM,                     col = "bpress_mb"),
    wind     = list(df = station_data[[cfg$wind$primary]],      col = "wspd_ms"),
    rh       = list(df = station_data[[cfg$humidity$primary]],  col = "rhh2o_3m_pct")
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
  attr(result, "lake_key")  <- lake_key
  attr(result, "lake_name") <- cfg$lake_name
  result
}


# ============================================================
# generate_synthetic_climate
# — lake-agnostic replacement for the 0.5_<LAKE>_data_preparation_
#   forecasting.R scripts
# — fits a VAR model to the anomalies of a lake's prepared climate
#   record (relative to its (day-of-year, hour) seasonal cycle),
#   bootstraps a "realistic" synthetic climate record from the
#   residual distribution, applies physical corrections (clear-sky
#   shortwave masking, quantile-mapped air temperature, recomputed
#   LWR_out, variance-matched LWR_in), and forecasts forward to a
#   target horizon year.
#
#   The resulting `synthetic` (historical-period) and
#   `future_physical` (forecast-period) records preserve the lake's
#   realistic meteorology + albedo statistics, so different climate
#   scenarios (warming trends, flat offsets, seasonal adjustments —
#   see build_climate_scenario() / prepare_model_input()) can be
#   layered on top and run through run_ice_model() to see how ice
#   thickness responds.
#
#   lake_key     : "ELB" | "WLB" | "LH" | "LF" — resolves cfg$coords
#                  (lat/lon) used for clear-sky sun-angle masking
#   time_series  : a prepared lake climate time series, e.g.
#                  inputs$time_series from prepare_lake_model_inputs()
#                  (must contain time, T_air, SW_in, LWR_in, LWR_out,
#                  albedo, pressure, wind, relative_humidity)
#   horizon_year : final calendar year to forecast out to
#   window_days  : +/- days used to pool observations by (doy, hour)
#                  for seasonal quantile mapping (legacy scripts used
#                  14 for ELB and 7 for LF — pick whichever matches
#                  the lake's data density / seasonality)
#   max_lag      : maximum VAR lag considered during lag selection
#   sim_seed / forecast_seed : RNG seeds for the historical bootstrap
#                  simulation and the future-horizon simulation
#   plot_diagnostics : if TRUE, also build density / ACF / correlation
#                  comparison plots (observed vs. synthetic)
#
#   returns list(
#     lake_key, lake_name,
#     synthetic        = <historical-period synthetic climate tibble>,
#     future_physical  = <forecast-period synthetic climate tibble>,
#     var_model        = <fitted VAR model, for inspection/reuse>,
#     diagnostics      = list(p_choice, method_used, emissivity,
#                             n_sim, n_future, plots)
#   )
#
#   Required packages (load in the driver script before sourcing
#   functions.R, the same way 00_*.R loads `suncalc` when needed):
#   zoo, vars, copula, reshape2, gridExtra, scales, suncalc, purrr
# ============================================================
generate_synthetic_climate <- function(
    lake_key,
    time_series,
    lake_configs     = LAKE_CONFIGS,
    horizon_year     = 2037,
    window_days      = 14,
    max_lag          = 24,
    sim_seed         = 123,
    forecast_seed    = 999,
    plot_diagnostics = TRUE
) {

  cfg <- lake_configs[[lake_key]]
  if (is.null(cfg)) stop(sprintf(
    "Unknown lake_key '%s'. Valid options: %s",
    lake_key, paste(names(lake_configs), collapse = ", ")
  ))

  message(sprintf("Generating synthetic climate record for %s (%s)...", cfg$lake_name, lake_key))

  lat_site <- cfg$coords$lat
  lon_site <- cfg$coords$lon
  sigma_sb <- 5.670374419e-8

  # ---- 1. Prepare and sanity-check ----------------------------------------
  df <- time_series |>
    arrange(time) |>
    mutate(time = as.POSIXct(time, tz = "UTC"))

  na_count <- sum(is.na(df))
  message("Total NA values in dataset: ", na_count)
  if (na_count > 0) {
    message("NA values present — consider filling/removing them before modelling.")
  }

  # ---- 2. Transform variables ----------------------------------------------
  eps       <- 1e-6
  logit     <- function(x) qlogis(pmin(pmax(x, eps), 1 - eps))
  inv_logit <- function(x) plogis(x)

  df_trans <- df |>
    mutate(
      relative_humidity_frac = relative_humidity / 100,
      relative_humidity_frac = pmin(pmax(relative_humidity_frac, 0.0001), 0.9999),
      rh_t           = qlogis(relative_humidity_frac),
      albedo_clamped = pmin(pmax(albedo, 0.0001), 0.9999),
      albedo_t       = qlogis(albedo_clamped),
      wind_t         = sqrt(pmax(wind, 0)),
      T_air_t        = T_air,
      SW_in_t        = SW_in,
      LWR_in_t       = LWR_in,
      pressure_t     = pressure
    ) |>
    dplyr::select(time, T_air_t, SW_in_t, LWR_in_t, albedo_t, pressure_t, wind_t, rh_t)

  # ---- 3. Seasonal cycle (doy x hour) and anomalies ------------------------
  df_trans <- df_trans |> mutate(hour = hour(time), doy = yday(time))

  vars_t <- c("T_air_t", "SW_in_t", "LWR_in_t", "albedo_t", "pressure_t", "wind_t", "rh_t")

  seasonal_means <- df_trans |>
    group_by(doy, hour) |>
    summarise(
      T_air_t_seas    = mean(T_air_t,    na.rm = TRUE),
      SW_in_t_seas    = mean(SW_in_t,    na.rm = TRUE),
      LWR_in_t_seas   = mean(LWR_in_t,   na.rm = TRUE),
      albedo_t_seas   = mean(albedo_t,   na.rm = TRUE),
      pressure_t_seas = mean(pressure_t, na.rm = TRUE),
      wind_t_seas     = mean(wind_t,     na.rm = TRUE),
      rh_t_seas       = mean(rh_t,       na.rm = TRUE),
      .groups = "drop"
    )

  df_anom <- df_trans |>
    left_join(seasonal_means, by = c("doy", "hour"), suffix = c("", "_seas")) |>
    mutate(across(all_of(vars_t), ~ . - get(paste0(cur_column(), "_seas")), .names = "anom_{col}"))

  anom_names <- paste0("anom_", vars_t)
  Y <- df_anom |> dplyr::select(all_of(anom_names)) |> as.matrix()

  na_rows <- apply(Y, 1, function(x) any(is.na(x)))
  if (any(na_rows)) {
    warning(sum(na_rows), " rows contain NA in anomalies. These will be removed for VAR fitting.")
    Y_fit <- Y[!na_rows, ]
  } else {
    Y_fit <- Y
  }

  # ---- 4. Fit VAR (select lag) ----------------------------------------------
  lag_sel <- VARselect(Y_fit, lag.max = max_lag, type = "const")
  message("Lag selection results:")
  print(lag_sel$selection)

  p_choice <- as.integer(lag_sel$selection["AIC(n)"])
  if (is.na(p_choice)) p_choice <- 1
  message("Selected VAR lag p = ", p_choice)

  var_model <- VAR(Y_fit, p = p_choice, type = "const")

  resids    <- as.matrix(residuals(var_model))
  Sigma_res <- cov(resids, use = "pairwise.complete.obs")

  # ---- helper: recursive bootstrap simulation from residual draws ----------
  simulate_VAR_bootstrap <- function(var_model, n_sim, init_y = NULL, resids = NULL, seed = NULL) {
    if (!is.null(seed)) set.seed(seed)

    p  <- var_model$p
    Yv <- var_model$y
    k  <- ncol(Yv)
    varnames <- colnames(Yv)

    coefs_list <- var_model$varresult
    A_list <- vector("list", p)
    for (l in 1:p) A_list[[l]] <- matrix(0, nrow = k, ncol = k)
    const_vec <- numeric(k)

    for (i in seq_len(k)) {
      this_mod <- coefs_list[[i]]
      co <- coef(this_mod)
      names_co <- names(co)

      if ("const" %in% names_co) {
        const_vec[i] <- co["const"]
      } else if ("(Intercept)" %in% names_co) {
        const_vec[i] <- co["(Intercept)"]
      } else {
        const_vec[i] <- 0
      }

      for (l in 1:p) {
        lag_names <- paste0("L", l, ".", varnames)
        present   <- intersect(lag_names, names_co)
        if (length(present) > 0) {
          A_list[[l]][i, match(present, lag_names)] <- co[present]
        }
      }
    }

    if (is.null(init_y)) init_y <- tail(Yv, p)
    state <- as.matrix(init_y)

    if (is.null(resids)) stop("Must supply residual matrix")
    resids <- as.matrix(resids)

    Ysim <- matrix(NA_real_, nrow = n_sim, ncol = k)
    colnames(Ysim) <- varnames

    for (t in 1:n_sim) {
      mean_t <- const_vec
      for (l in 1:p) {
        past_row <- state[nrow(state) - (l - 1), ]
        mean_t   <- mean_t + A_list[[l]] %*% past_row
      }
      e_t   <- resids[sample(nrow(resids), 1), ]
      new_y <- as.numeric(mean_t + e_t)
      Ysim[t, ] <- new_y

      if (p > 1) {
        state <- rbind(state[-1, , drop = FALSE], new_y)
      } else {
        state <- matrix(new_y, nrow = 1)
      }
    }

    as.data.frame(Ysim)
  }

  # ---- 5. Synthetic simulation (bootstrap residual VAR) --------------------
  n_sim <- nrow(resids)

  sim_anom_mat <- simulate_VAR_bootstrap(
    var_model = var_model, n_sim = n_sim, init_y = NULL, resids = resids, seed = sim_seed
  )
  sim_anom <- as.data.frame(sim_anom_mat)
  colnames(sim_anom) <- colnames(var_model$y)

  # ---- 6. Reconstruct physical variables ------------------------------------
  if (!all(colnames(var_model$y) %in% anom_names)) {
    warning("VAR column names differ from expected anomaly names. Attempting to align by position.")
  }

  sim_full <- df_anom |>
    dplyr::select(time, doy, hour) |>
    mutate(row_id = row_number(), sim_index = row_number()) |>
    bind_cols(as_tibble(sim_anom)[1:nrow(df_anom), , drop = FALSE]) |>
    left_join(seasonal_means, by = c("doy", "hour"))

  recon <- sim_full
  for (v in vars_t) {
    anom_col <- paste0("anom_", v)
    seas_col <- paste0(v, "_seas")
    out_col  <- paste0(v, "_sim_recon")
    recon[[out_col]] <- recon[[anom_col]] + recon[[seas_col]]
  }

  synthetic <- tibble(
    time              = recon$time,
    T_air             = recon$T_air_t_sim_recon,
    SW_in             = recon$SW_in_t_sim_recon,
    LWR_in            = recon$LWR_in_t_sim_recon,
    albedo            = pmin(pmax(inv_logit(recon$albedo_t_sim_recon), 0), 1),
    pressure          = recon$pressure_t_sim_recon,
    wind              = (recon$wind_t_sim_recon)^2,
    relative_humidity = pmin(pmax(inv_logit(recon$rh_t_sim_recon), 0), 1)
  ) |>
    mutate(delta_T = T_air - lag(T_air))

  # ---- 7. Physical correction patch -----------------------------------------
  message("Applying physical corrections (clear-sky SW mask, T_air quantile mapping)...")

  sunpos <- suncalc::getSunlightPosition(date = synthetic$time, lat = lat_site, lon = lon_site)
  synthetic$solar_alt <- sunpos$altitude

  obs_sunpos  <- suncalc::getSunlightPosition(date = df$time, lat = lat_site, lon = lon_site)
  df$solar_alt <- obs_sunpos$altitude

  ub <- quantile(df$SW_in[df$solar_alt > 0], probs = 0.999, na.rm = TRUE)

  synthetic <- synthetic |>
    mutate(
      SW_in_orig = SW_in,
      SW_in = ifelse(solar_alt <= 0, 0, SW_in),
      SW_in = ifelse(SW_in < 0, 0, SW_in),
      SW_in = pmin(SW_in, ub)
    )

  df <- df |> mutate(doy = yday(time), hour = hour(time))
  obs_groups <- df |>
    group_by(doy, hour) |>
    summarise(vals = list(na.omit(T_air)), n = length(na.omit(T_air)), .groups = "drop")

  circ_dist <- function(a, b, nyear = 365) {
    d <- abs(a - b)
    pmin(d, nyear - d)
  }

  get_obs_pool <- function(target_doy, target_hour, window = window_days) {
    pool <- obs_groups |>
      filter(hour == target_hour) |>
      mutate(dd = circ_dist(doy, target_doy)) |>
      filter(dd <= window) |>
      pull(vals)
    if (length(pool) == 0) return(numeric(0))
    unlist(pool)
  }

  qm_map_one <- function(x, obs_pool) {
    if (is.na(x) || length(obs_pool) < 10) return(x)
    p <- ecdf(obs_pool)(x)
    as.numeric(quantile(obs_pool, probs = p, na.rm = TRUE, type = 8))
  }

  synthetic <- synthetic |>
    mutate(doy = yday(time), hour = hour(time),
           obs_pool_id = paste0(doy, "_", hour))

  unique_keys   <- unique(synthetic$obs_pool_id)
  obs_pool_list <- setNames(vector("list", length(unique_keys)), unique_keys)
  for (key in unique_keys) {
    parts <- strsplit(key, "_")[[1]]
    obs_pool_list[[key]] <- get_obs_pool(as.integer(parts[1]), as.integer(parts[2]))
  }

  mapped_T <- vector("numeric", nrow(synthetic))
  for (i in seq_len(nrow(synthetic))) {
    mapped_T[i] <- qm_map_one(synthetic$T_air[i], obs_pool_list[[synthetic$obs_pool_id[i]]])
  }

  replace_idx <- !is.na(mapped_T)
  synthetic$T_air_qm <- synthetic$T_air
  synthetic$T_air[replace_idx] <- mapped_T[replace_idx]

  emissivity <- mean(df$LWR_out / (sigma_sb * df$T_air^4), na.rm = TRUE)
  emissivity <- pmin(pmax(emissivity, 0.4), 1.0)
  synthetic  <- synthetic |> mutate(LWR_out = emissivity * sigma_sb * (T_air)^4)

  obs_sd_by_key <- df |>
    group_by(doy, hour) |>
    summarise(sd_obs = sd(LWR_in, na.rm = TRUE), .groups = "drop") |>
    mutate(key = paste0(doy, "_", hour))

  synthetic <- synthetic |>
    left_join(obs_sd_by_key |> dplyr::select(key, sd_obs), by = c("obs_pool_id" = "key")) |>
    mutate(
      LWR_in_resid = LWR_in - mean(LWR_in, na.rm = TRUE),
      LWR_in = ifelse(!is.na(sd_obs) & sd(LWR_in, na.rm = TRUE) < sd_obs,
                      mean(LWR_in, na.rm = TRUE) + LWR_in_resid * (sd_obs / (sd(LWR_in, na.rm = TRUE) + 1e-9)),
                      LWR_in)
    ) |>
    dplyr::select(-LWR_in_resid, -sd_obs)

  synthetic_fixed <- synthetic |>
    mutate(
      SW_in             = pmax(SW_in, 0),
      albedo            = pmin(pmax(albedo, 0), 1),
      relative_humidity = pmin(pmax(relative_humidity, 0), 1),
      wind              = pmax(wind, 0),
      pressure          = pmax(pressure, 1)
    ) |>
    dplyr::select(-solar_alt, -obs_pool_id, -doy, -hour)

  pre_counts <- synthetic |> summarise(
    neg_SW   = sum(SW_in_orig < 0, na.rm = TRUE),
    n240_260 = sum(T_air_qm >= 240 & T_air_qm <= 260, na.rm = TRUE)
  )
  post_counts <- synthetic_fixed |> summarise(
    neg_SW   = sum(SW_in < 0, na.rm = TRUE),
    n240_260 = sum(T_air >= 240 & T_air <= 260, na.rm = TRUE)
  )
  message("Diagnostics before/after physical corrections:")
  print(bind_rows(before = pre_counts, after = post_counts))

  # ---- 8. Align sim_anom -> df_anom -> apply QM -> rebuild T_air ------------
  common_cols <- intersect(colnames(sim_anom), colnames(df_anom))
  if (length(common_cols) == 0) {
    common_cols <- intersect(grep("^anom_", colnames(sim_anom), value = TRUE),
                             grep("^anom_", colnames(df_anom), value = TRUE))
  }
  if (length(common_cols) == 0) stop("Could not find shared anomaly column names between sim_anom and df_anom.")

  mask_complete <- complete.cases(df_anom[, common_cols, drop = FALSE])
  n_mask <- sum(mask_complete)
  n_sim2 <- nrow(sim_anom)

  if (n_mask == n_sim2) {
    use_idx     <- which(mask_complete)
    method_used <- "exact_complete_match"
  } else if (n_mask > n_sim2) {
    use_idx     <- which(mask_complete)[1:n_sim2]
    method_used <- "first_N_of_complete_rows"
  } else {
    miss_count  <- apply(is.na(df_anom[, common_cols, drop = FALSE]), 1, sum)
    ranked      <- order(miss_count, decreasing = FALSE)
    use_idx     <- sort(ranked[1:n_sim2])
    method_used <- "least-missing_fallback"
  }
  message("Anomaly alignment method used: ", method_used)

  sim_anom_full <- df_anom |> dplyr::select(time)
  for (v in colnames(sim_anom)) sim_anom_full[[v]] <- NA_real_

  nfill <- min(length(use_idx), nrow(sim_anom))
  for (v in colnames(sim_anom)) {
    sim_anom_full[[v]][use_idx[1:nfill]] <- sim_anom[[v]][1:nfill]
  }

  if (!"doy"  %in% names(synthetic_fixed)) synthetic_fixed <- synthetic_fixed |> mutate(doy  = yday(time))
  if (!"hour" %in% names(synthetic_fixed)) synthetic_fixed <- synthetic_fixed |> mutate(hour = hour(time))

  seas_candidates <- c("T_air_t_seas", "T_air_seasonal", "T_air_seas", "T_air_t_season_mean")
  seas_col <- intersect(seas_candidates, names(df_anom))
  if (length(seas_col) == 0) stop("No seasonal temperature column found in df_anom.")
  df_anom2 <- df_anom |> rename(T_air_t_seas = !!sym(seas_col[1]))

  synthetic_fixed <- synthetic_fixed |>
    left_join(sim_anom_full |> dplyr::select(time, all_of(colnames(sim_anom))), by = "time") |>
    left_join(df_anom2 |> dplyr::select(time, T_air_t_seas), by = "time")

  if (!("anom_T_air_t" %in% names(synthetic_fixed))) {
    t_anom_cand <- intersect(c("anom_T_air_t", "anom_T_air", "T_air_anom", "anom_air_temp"),
                             names(synthetic_fixed))
    if (length(t_anom_cand) == 0) stop("Cannot find T_air anomaly in synthetic after join.")
    synthetic_fixed <- synthetic_fixed |> rename(anom_T_air_t = !!sym(t_anom_cand[1]))
  }
  if (!("T_air_t_seas" %in% names(synthetic_fixed))) stop("T_air_t_seas missing in synthetic after join.")

  synthetic_fixed <- synthetic_fixed |> mutate(T_air_raw = anom_T_air_t + T_air_t_seas)

  obsA <- df_anom2 |> dplyr::select(time, doy, hour, anom_T_air_t)

  get_pool <- function(target_doy, target_hour) {
    obsA |>
      filter(hour == target_hour) |>
      mutate(dd = circ_dist(doy, target_doy)) |>
      filter(dd <= window_days) |>
      pull(anom_T_air_t)
  }

  qm_one <- function(x, pool) {
    if (is.na(x) || length(pool) < 30) return(x)
    p <- ecdf(pool)(x)
    quantile(pool, probs = p, type = 8, na.rm = TRUE)
  }

  synthetic_fixed <- synthetic_fixed |> mutate(doy = yday(time))

  synthetic_fixed$anom_T_air_qm <- purrr::pmap_dbl(
    list(synthetic_fixed$anom_T_air_t, synthetic_fixed$doy, synthetic_fixed$hour),
    function(x, doy, hour) qm_one(x, get_pool(doy, hour))
  )

  synthetic_fixed <- synthetic_fixed |> mutate(T_air = anom_T_air_qm + T_air_t_seas)

  orig_emissivity <- mean(df$LWR_out / (sigma_sb * df$T_air^4), na.rm = TRUE)
  orig_emissivity <- min(max(orig_emissivity, 0.4), 1.0)
  synthetic_fixed <- synthetic_fixed |> mutate(LWR_out = orig_emissivity * sigma_sb * (T_air^4))

  message("Finished alignment/QM. sim_anom rows: ", n_sim2,
          " ; df_anom rows: ", nrow(df_anom),
          " ; synthetic rows: ", nrow(synthetic_fixed))

  # ---- 9. Final physical constraints ----------------------------------------
  synthetic_final <- synthetic_fixed |>
    mutate(
      albedo            = pmin(pmax(albedo, 0), 1),
      relative_humidity = pmin(pmax(relative_humidity, 0), 1),
      wind              = pmax(wind, 0),
      pressure          = pmax(pressure, 1)
    )

  # ---- 10. Optional diagnostic plots (observed vs. synthetic) ---------------
  diagnostic_plots <- NULL
  if (isTRUE(plot_diagnostics)) {
    message("Building diagnostic plots...")
    plot_vars <- c("T_air", "SW_in", "LWR_in", "LWR_out", "albedo", "wind", "relative_humidity")

    combined_df <- bind_rows(
      df              |> dplyr::select(time, all_of(plot_vars)) |>
        pivot_longer(-time, names_to = "variable", values_to = "value") |> mutate(source = "observed"),
      synthetic_final |> dplyr::select(time, all_of(plot_vars)) |>
        pivot_longer(-time, names_to = "variable", values_to = "value") |> mutate(source = "synthetic")
    )

    density_plots <- lapply(unique(combined_df$variable), function(var_name) {
      ggplot(filter(combined_df, variable == var_name), aes(x = value, fill = source, colour = source)) +
        geom_density(alpha = 0.2, linewidth = 0.5) +
        ggtitle(var_name) +
        theme_minimal()
    })
    names(density_plots) <- unique(combined_df$variable)

    acf_orig  <- acf(na.omit(df$T_air),              plot = FALSE)
    acf_synth <- acf(na.omit(synthetic_final$T_air), plot = FALSE)
    acf_plot  <- tibble(lag = acf_orig$lag, observed = acf_orig$acf, synthetic = acf_synth$acf) |>
      pivot_longer(-lag, names_to = "series", values_to = "acf") |>
      ggplot(aes(x = lag, y = acf, colour = series)) +
      geom_line() +
      ggtitle(sprintf("ACF: T_air observed vs. synthetic — %s", cfg$lake_name)) +
      theme_bw()

    orig_mat  <- df             |> dplyr::select(all_of(plot_vars)) |> drop_na() |> as.matrix()
    synth_mat <- synthetic_final |> dplyr::select(all_of(plot_vars)) |> drop_na() |> as.matrix()

    m1 <- reshape2::melt(cor(orig_mat,  use = "pairwise.complete.obs"))
    m2 <- reshape2::melt(cor(synth_mat, use = "pairwise.complete.obs"))
    names(m1) <- names(m2) <- c("Var1", "Var2", "Corr")
    m1$source <- "observed"; m2$source <- "synthetic"

    corr_plot <- ggplot(bind_rows(m1, m2), aes(x = Var1, y = Var2, fill = Corr)) +
      geom_tile() + facet_wrap(~source) +
      scale_fill_gradient2(low = "blue", mid = "white", high = "red", limits = c(-1, 1)) +
      theme_minimal() + theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
      ggtitle(sprintf("Correlation matrices: observed vs. synthetic — %s", cfg$lake_name))

    diagnostic_plots <- list(density = density_plots, acf = acf_plot, correlation = corr_plot)
  }

  # ---- 11. Forecast into the future (preserve mean climate) -----------------
  message(sprintf("Forecasting %s climate out to %d...", cfg$lake_name, horizon_year))

  last_obs_time <- max(df$time)
  dt_seconds <- as.numeric(median(diff(sort(df$time)), na.rm = TRUE), units = "secs")
  if (is.na(dt_seconds) || dt_seconds <= 0) dt_seconds <- 3600

  future_end   <- as.POSIXct(paste0(horizon_year, "-12-31 23:59:59"), tz = tz(last_obs_time))
  future_times <- seq(from = last_obs_time + dt_seconds, to = future_end, by = dt_seconds)
  n_future <- length(future_times)
  message("Simulating ", n_future, " future timesteps from ", as.character(min(future_times)),
          " to ", as.character(max(future_times)))

  p      <- var_model$p
  Y_full <- var_model$y
  if (nrow(Y_full) < p) stop("VAR fit contains fewer rows than p. Cannot initialize simulation.")
  init_y <- Y_full[(nrow(Y_full) - p + 1):nrow(Y_full), , drop = FALSE]

  future_anom <- as_tibble(simulate_VAR_bootstrap(
    var_model = var_model, n_sim = n_future, init_y = init_y, resids = resids, seed = forecast_seed
  ))

  future_df <- future_anom |>
    mutate(time = future_times, doy = yday(time), hour = hour(time)) |>
    left_join(seasonal_means, by = c("doy", "hour"))

  if (any(is.na(future_df[[paste0(vars_t[1], "_seas")]]))) {
    warning("Some seasonal means are missing for future times (check seasonal_means keys).")
  }

  for (v in vars_t) {
    anom_col <- paste0("anom_", v)
    seas_col <- paste0(v, "_seas")
    out_col  <- paste0(v, "_sim_t")
    if (!all(c(anom_col, seas_col) %in% names(future_df))) {
      stop("Missing columns when reconstructing: ", anom_col, " or ", seas_col)
    }
    future_df[[out_col]] <- future_df[[anom_col]] + future_df[[seas_col]]
  }

  future_physical <- future_df |>
    transmute(
      time              = time,
      T_air             = !!sym("T_air_t_sim_t"),
      SW_in             = !!sym("SW_in_t_sim_t"),
      LWR_in            = !!sym("LWR_in_t_sim_t"),
      pressure          = !!sym("pressure_t_sim_t"),
      relative_humidity = plogis(!!sym("rh_t_sim_t")) * 100,
      albedo            = plogis(!!sym("albedo_t_sim_t")),
      wind              = pmax(!!sym("wind_t_sim_t"), 0)^2
    )

  message("Done. synthetic: ", nrow(synthetic_final), " rows | future_physical: ",
          nrow(future_physical), " rows (", min(future_physical$time), " -> ",
          max(future_physical$time), ")")

  list(
    lake_key        = lake_key,
    lake_name       = cfg$lake_name,
    synthetic       = synthetic_final,
    future_physical = future_physical,
    var_model       = var_model,
    diagnostics     = list(
      p_choice    = p_choice,
      method_used = method_used,
      emissivity  = orig_emissivity,
      n_sim       = n_sim2,
      n_future    = n_future,
      plots       = diagnostic_plots
    )
  )
}


# ============================================================
# generate_climatological_climate
# — lake-agnostic, mean-annual-cycle alternative to
#   generate_synthetic_climate()
# — instead of fitting a VAR model to a short, recent record, this
#   pools the lake's ENTIRE available met record (e.g. back into the
#   1990s — see start_filter = "max" usage below), computes a mean
#   annual cycle (the average value of each variable at each
#   (day-of-year, hour) across all observed years), and simply
#   repeats that climatological cycle forward as the "synthetic"
#   future climate. No stochastic simulation, no VAR fitting — just
#   "what does a typical year at this lake look like, on average,
#   across as much history as we have, repeated forward in time."
#
#   This trades the VAR approach's realistic year-to-year variability
#   for simplicity, transparency, and a much longer observational
#   basis — a useful complement when you want a clean, low-noise
#   "typical year" baseline to layer climate scenarios on top of.
#
#   lake_key     : "ELB" | "WLB" | "LH" | "LF" — used for messages/labels
#   time_series  : a LONG, lake-agnostic prepared climate time series —
#                  ideally spanning back across as much of the met
#                  record as is available (NOT the short, lake-specific
#                  modeling-period record). Build one with, e.g.:
#                    long_inputs <- prepare_lake_model_inputs(
#                      lake_key, station_data, airt_primary, airt_secondary,
#                      ice_thickness, albedo_orig,
#                      start_filter = as.POSIXct("1990-01-01"),
#                      n_years      = "max"
#                    )
#                  and pass long_inputs$time_series here.
#   horizon_year : final calendar year to tile the climatology out to
#   plot_diagnostics : if TRUE, build density comparison plots of the
#                  observed long record vs. the climatological
#                  reconstruction over that same span
#
#   returns list(
#     lake_key, lake_name,
#     climatology      = <tibble of (doy, hour) mean-annual values, plus
#                         n_years_pooled = how many distinct observed
#                         years contributed to each (doy, hour) cell>,
#     synthetic        = <historical-period record, reconstructed by
#                         looking up each timestamp's (doy, hour)
#                         climatological mean — directly comparable to
#                         generate_synthetic_climate()'s $synthetic>,
#     future_physical  = <forecast-period record: the climatology tiled
#                         forward from the end of the long record out
#                         to horizon_year, at the same timestep>,
#     diagnostics      = list(n_years_pooled, record_span, plots)
#   )
# ============================================================
generate_climatological_climate <- function(
    lake_key,
    time_series,
    lake_configs     = LAKE_CONFIGS,
    horizon_year     = 2037,
    plot_diagnostics = TRUE
) {

  cfg <- lake_configs[[lake_key]]
  if (is.null(cfg)) stop(sprintf(
    "Unknown lake_key '%s'. Valid options: %s",
    lake_key, paste(names(lake_configs), collapse = ", ")
  ))

  message(sprintf("Building mean-annual climatology for %s (%s)...", cfg$lake_name, lake_key))

  phys_vars <- c("T_air", "SW_in", "LWR_in", "LWR_out",
                 "albedo", "pressure", "wind", "relative_humidity")

  # ---- 1. Prepare the long record -------------------------------------------
  df <- time_series |>
    arrange(time) |>
    mutate(time = as.POSIXct(time, tz = "UTC"),
           doy  = yday(time),
           hour = hour(time),
           yr   = year(time))

  n_years_pooled_total <- n_distinct(df$yr)
  record_span <- list(start = min(df$time), end = max(df$time))
  message(sprintf("  ...pooling %d distinct year(s) of observations (%s -> %s)",
                  n_years_pooled_total, format(record_span$start), format(record_span$end)))
  if (n_years_pooled_total < 5) {
    warning(sprintf(
      "Only %d distinct year(s) found in the supplied time_series — the resulting climatology ",
      n_years_pooled_total),
      "will be based on very little inter-annual variability. Consider passing a longer ",
      "record (e.g. prepare_lake_model_inputs(..., start_filter = as.POSIXct(\"1990-01-01\"), n_years = \"max\"))."
    )
  }

  # ---- 2. Mean-annual cycle: average each variable by (doy, hour) -----------
  # This is a literal "for each timestep-of-year, take the mean of that same
  # timestep across every observed year" climatology — no transforms, no
  # detrending, just plain arithmetic means (and a same-shape SD table for
  # context/diagnostics).
  climatology <- df |>
    group_by(doy, hour) |>
    summarise(
      across(all_of(phys_vars), ~ mean(.x, na.rm = TRUE),  .names = "{.col}"),
      across(all_of(phys_vars), ~ sd(.x,   na.rm = TRUE),  .names = "{.col}_sd"),
      n_years_pooled = n_distinct(yr),
      .groups = "drop"
    ) |>
    arrange(doy, hour)

  # ---- 3. Reconstruct the historical period from the climatology ------------
  # (directly comparable to generate_synthetic_climate()'s $synthetic — same
  # span as the observed record, but every value is that timestamp's
  # (doy, hour) mean-annual value rather than a stochastic draw)
  synthetic <- df |>
    dplyr::select(time, doy, hour) |>
    left_join(climatology |> dplyr::select(doy, hour, all_of(phys_vars)), by = c("doy", "hour")) |>
    mutate(
      albedo            = pmin(pmax(albedo, 0), 1),
      relative_humidity = pmin(pmax(relative_humidity, 0), 100),
      wind              = pmax(wind, 0),
      pressure          = pmax(pressure, 1),
      delta_T           = T_air - lag(T_air)
    ) |>
    dplyr::select(-doy, -hour)

  # ---- 4. Tile the climatology forward to the forecast horizon --------------
  last_obs_time <- max(df$time)
  dt_seconds <- as.numeric(median(diff(sort(df$time)), na.rm = TRUE), units = "secs")
  if (is.na(dt_seconds) || dt_seconds <= 0) dt_seconds <- 3600

  future_end   <- as.POSIXct(paste0(horizon_year, "-12-31 23:59:59"), tz = tz(last_obs_time))
  future_times <- seq(from = last_obs_time + dt_seconds, to = future_end, by = dt_seconds)
  message(sprintf("  ...tiling climatology forward across %d timesteps (%s -> %s)",
                  length(future_times), format(min(future_times)), format(max(future_times))))

  future_physical <- tibble(time = future_times) |>
    mutate(doy = yday(time), hour = hour(time)) |>
    left_join(climatology |> dplyr::select(doy, hour, all_of(phys_vars)), by = c("doy", "hour")) |>
    mutate(
      albedo            = pmin(pmax(albedo, 0), 1),
      relative_humidity = pmin(pmax(relative_humidity, 0), 100),
      wind              = pmax(wind, 0),
      pressure          = pmax(pressure, 1)
    ) |>
    dplyr::select(-doy, -hour)

  if (anyNA(future_physical[phys_vars])) {
    warning("Some (day-of-year, hour) combinations in the forecast period have no climatological ",
            "match (gaps in the observed record). These rows were filled by carrying the nearest ",
            "available climatological value forward/backward.")
    future_physical <- future_physical |>
      arrange(time) |>
      fill(all_of(phys_vars), .direction = "downup")
  }

  # ---- 5. Optional diagnostic plots (observed vs. climatological recon) -----
  diagnostic_plots <- NULL
  if (isTRUE(plot_diagnostics)) {
    message("Building diagnostic plots (observed vs. climatological reconstruction)...")

    combined_df <- bind_rows(
      df        |> dplyr::select(time, all_of(phys_vars)) |>
        pivot_longer(-time, names_to = "variable", values_to = "value") |> mutate(source = "observed"),
      synthetic |> dplyr::select(time, all_of(phys_vars)) |>
        pivot_longer(-time, names_to = "variable", values_to = "value") |> mutate(source = "climatology")
    )

    density_plots <- lapply(phys_vars, function(var_name) {
      ggplot(filter(combined_df, variable == var_name), aes(x = value, fill = source, colour = source)) +
        geom_density(alpha = 0.2, linewidth = 0.5) +
        ggtitle(var_name) +
        theme_minimal()
    })
    names(density_plots) <- phys_vars

    seasonal_plot <- climatology |>
      mutate(day_frac = doy + hour / 24) |>
      dplyr::select(day_frac, all_of(phys_vars)) |>
      pivot_longer(-day_frac, names_to = "variable", values_to = "value") |>
      ggplot(aes(x = day_frac, y = value)) +
      geom_line(colour = "#3B8BD4", linewidth = 0.4) +
      facet_wrap(~variable, scales = "free_y") +
      labs(title = sprintf("Mean annual cycle — %s (pooled across %d years)", cfg$lake_name, n_years_pooled_total),
           x = "Day of year", y = NULL) +
      theme_minimal()

    diagnostic_plots <- list(density = density_plots, seasonal_cycle = seasonal_plot)
  }

  message(sprintf("Done. climatology: %d (doy,hour) cells | synthetic: %d rows | future_physical: %d rows (%s -> %s)",
                  nrow(climatology), nrow(synthetic), nrow(future_physical),
                  format(min(future_physical$time)), format(max(future_physical$time))))

  list(
    lake_key        = lake_key,
    lake_name       = cfg$lake_name,
    climatology     = climatology,
    synthetic       = synthetic,
    future_physical = future_physical,
    diagnostics     = list(
      n_years_pooled = n_years_pooled_total,
      record_span    = record_span,
      plots          = diagnostic_plots
    )
  )
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
