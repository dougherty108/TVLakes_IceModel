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
  L_initial  = 3.88,      # initial ice thickness (m)

  # Seasonal ice — open-water physics
  # (only used when seasonally_frozen = TRUE; ignored for perennial-ice lakes)
  seasonally_frozen = FALSE,  # set TRUE for lakes that freeze and thaw each year
  k_water           = 0.57,   # thermal conductivity of liquid water at 0 °C (W/m/K)
  rho_water         = 999.8,  # density of water near 0 °C (kg/m³)
  Cp_water          = 4218,   # specific heat of water near 0 °C (J/kg/K)
  mixing_depth      = 0.5,    # surface mixed-layer depth for open-water temp tracking (m)
                               # — controls how quickly the lake surface cools/warms;
                               # tune this to match observed freeze-onset timing
  L_nucleation      = 0.002,  # ice thickness at nucleation (m) — 2 mm of new ice
  albedo_water      = 0.06,   # open-water albedo (replaces time_series$albedo when
                               # the lake is ice-free; typical clear-water value)
  albedo_ice        = 0.85    # default ice/snow albedo for lakes with no AlbedoModel
                               # data (overridden per-lake via LAKE_CONFIGS$albedo_ice;
                               # applied as the constant time_series$albedo for those lakes)
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
    lake_name        = "East Lake Bonney",
    L_initial        = 3.88,   # ice-to-ice thickness on 2016-12-17
    Chi              = 0.30, #0.40,
    albedo_multiplier = 1.00,  # 
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
    lake_name        = "West Lake Bonney",
    L_initial        = 3.39,   # ice-to-ice thickness on 2016-12-17
    Chi              = 0.25, #0.30,
    albedo_multiplier = 1.00,  # no adjustment
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
    lake_name        = "Lake Hoare",
    L_initial        = 3.50,   # ice-to-ice thickness on 2016-12-17
    Chi              = 0.35,
    albedo_multiplier = 1.00,  # no adjustment
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
    lake_name        = "Lake Fryxell",
    L_initial        = 4.60,   # ice-to-ice thickness on 2016-12-17
    Chi              = 0.35,
    albedo_multiplier = 1.00,  # leave LF as-is
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
  ),

  GL4 = list(
    lake_name         = "Green Lake 4",
    L_initial         = 0.10,   # = dx; start ice-covered (1 Jan is mid-winter) on a valid 2-node grid
    L_nucleation      = 0.10,   # = dx; new ice forms at one grid step so the profile can grow
    Chi               = 0.25,
    albedo_multiplier = 1.00,
    albedo_ice        = 0.85,   # constant dummy albedo — no AlbedoModel.csv for GL4
    seasonally_frozen = TRUE,
    start_filter      = as.POSIXct("2014-01-01 00:00:00"),

    n_years           = "max",
    base_station      = "D1",   # NWT LTER D1 station (single station, no secondary)
    stations_needed   = c("D1"),
    # GL4 uses a dedicated prepare_gl4_model_inputs() — the fields below are
    # provided for reference / documentation only and are not consumed by
    # prepare_lake_model_inputs() when lake_key == "GL4".
    air_temp          = list(primary_col = "airtemp_avg", secondary_col = NULL),
    shortwave         = list(primary = "D1", secondary = NULL, use_artificial = FALSE),
    wind              = list(primary = "D1", secondary = NULL),
    humidity          = list(primary = "D1", secondary = NULL),
    coords            = list(lat = 40.0544, lon = -105.6172),  # Niwot Ridge, GL4
    ice_loc_filter    = NULL
  ),

  LOC = list(
    lake_name         = "The Loch",
    L_initial         = 0.10,   # = dx; start ice-covered (1 Jan is mid-winter) on a valid 2-node grid
    L_nucleation      = 0.10,   # = dx; new ice forms at one grid step so the profile can grow
    Chi               = 0.30,   # same as GL4 until Loch-specific tuning is available
    albedo_multiplier = 1.00,
    albedo_ice        = 0.85,   # constant dummy albedo (same as GL4) — no albedo data for the Loch
    seasonally_frozen = TRUE,
    start_filter      = as.POSIXct("2017-01-01 07:00:00", tz = "UTC"),  # first LVWS record (00:00 MST)

    n_years           = "max",
    base_station      = "LVWS", # Loch Vale weather station (USGS / NREL), single station
    stations_needed   = c("LVWS"),
    # The Loch uses a dedicated prepare_loc_model_inputs() — the fields below
    # are provided for reference / documentation only.
    air_temp          = list(primary_col = "airt", secondary_col = NULL),
    shortwave         = list(primary = "LVWS", secondary = NULL, use_artificial = FALSE),
    wind              = list(primary = "LVWS", secondary = NULL),
    humidity          = list(primary = "LVWS", secondary = NULL),
    coords            = list(lat = 40.2914, lon = -105.6636),  # The Loch, Loch Vale, RMNP
    ice_loc_filter    = NULL
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
  overrides <- list(L_initial = cfg$L_initial, Chi = cfg$Chi)
  # propagate optional per-lake constants when present
  if (!is.null(cfg$seasonally_frozen)) overrides$seasonally_frozen <- cfg$seasonally_frozen
  if (!is.null(cfg$albedo_ice))        overrides$albedo_ice        <- cfg$albedo_ice
  if (!is.null(cfg$L_nucleation))      overrides$L_nucleation      <- cfg$L_nucleation
  modifyList(constants, overrides)
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

  # Apply this lake's albedo multiplier (LAKE_CONFIGS$<lake>$albedo_multiplier;
  # defaults to 1 = no change if a config omits it). This lets you scale a
  # lake's albedo forcing up or down — e.g. albedo_multiplier = 1.5 bumps ELB's
  # albedo up 50% — without touching the raw AlbedoModel.csv data. Re-clamped
  # to the physical [0, 1] range afterward, since albedo can't exceed 1.
  albedo_mult <- cfg$albedo_multiplier %||% 1
  if (albedo_mult != 1) {
    message(sprintf("  applying albedo_multiplier = %.2f for %s", albedo_mult, cfg$lake_name))
  }
  albedo_interp <- pmin(pmax(albedo_interp * albedo_mult, 0), 1)

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
# standardize_gl4_ice
# — converts the NWT LTER GL4 ice-thickness table (thickness in cm) to the
#   MCM-LTER schema (location_name, location, date_time, z_water_m in m).
#   Accepts the date column as `date` or `date_time`, in either the original
#   ISO format (1984-10-06) or the Excel re-save format (10/6/84), and as
#   text or already-parsed Date/POSIXct.
# ============================================================
standardize_gl4_ice <- function(df, lake_name = "Green Lake 4") {
  date_col <- intersect(c("date_time", "date"), names(df))[1]
  if (is.na(date_col)) stop(
    "GL4 ice-thickness table needs a `date` or `date_time` column. Columns present: ",
    paste(names(df), collapse = ", "))
  if (!"thickness" %in% names(df)) stop(
    "GL4 ice-thickness table needs a `thickness` column (cm). Columns present: ",
    paste(names(df), collapse = ", "))

  raw_dates <- df[[date_col]]
  date_time <- if (inherits(raw_dates, c("POSIXct", "Date"))) {
    as.POSIXct(raw_dates, tz = "UTC")
  } else {
    lubridate::parse_date_time(as.character(raw_dates),
                               orders = c("Ymd", "mdy", "mdY", "Ymd HMS", "Ymd HM",
                                          "mdy HM", "mdY HM"),
                               tz = "UTC", quiet = TRUE)
  }

  tibble::tibble(
    location_name = lake_name,
    location      = if ("local_site" %in% names(df)) df$local_site else "GL4",
    date_time     = date_time,
    z_water_m     = as.numeric(df$thickness) / 100     # cm → m
  )
}


# ============================================================
# prepare_gl4_model_inputs
# — GL4-specific input preparation for the NWT LTER D1 station
#   10-min met data. Returns the same schema as
#   prepare_lake_model_inputs() so it can be passed directly to
#   prepare_model_input() and run_ice_model().
#
# Key differences from the Antarctic lakes:
#   • Single station, no secondary fallback
#   • 10-min raw resolution → aggregated to hourly
#   • Air temp / RH coalesced across D1 sensors (logger changed in 2019)
#   • Pressure in mbar  → converted to Pa (×100)
#   • SW from solrad_avg (W/m²); values >1500 W/m² flagged as erroneous
#   • No AlbedoModel.csv → constant albedo from LAKE_CONFIGS$GL4$albedo_ice
#   • No longwave-in measurement → estimated from Stefan-Boltzmann:
#       LWR_in ≈ emissivity_atm × sigma × T_air^4
#       where emissivity_atm is approximated from Brutsaert (1975):
#       emissivity_atm = 1.24 × (e_a / T_air)^(1/7)
#       and e_a (Pa) = (RH/100) × 611 × exp(17.27 × (T_air_C) / (T_air_C + 237.3))
#   • Ice thickness from gl4_ice_thickness.nc.data.csv (cm, date column) is
#     reformatted to the MCM-LTER schema used by the Antarctic lakes:
#     location_name, location, date_time (POSIXct), z_water_m (positive m),
#     so plot_ice_model() and downstream scripts work unchanged.
#
#   met_data / ice_thickness accept either a raw tibble (as the Antarctic
#   00_ scripts pass) or a file path.
# ============================================================
prepare_gl4_model_inputs <- function(
    met_data,          # raw D1 10-min tibble, or path to d-1cr23x-cr1000.10minute.ml.data.csv
    ice_thickness,     # raw GL4 ice tibble, or path to gl4_ice_thickness.nc.data.csv
    lake_configs = LAKE_CONFIGS,
    constants    = CONSTANTS,
    start_filter = NULL,   # POSIXct; NULL = LAKE_CONFIGS$GL4$start_filter
    n_years      = NULL    # numeric years after start_filter; NULL = LAKE_CONFIGS$GL4$n_years
) {

  cfg   <- lake_configs[["GL4"]]
  consts <- lake_constants("GL4", lake_configs, constants)
  start_filter <- start_filter %||% cfg$start_filter
  if (!is.null(start_filter))
    start_filter <- lubridate::force_tz(as.POSIXct(start_filter), "UTC")
  n_years <- n_years %||% cfg$n_years %||% "max"

  read_if_path <- function(x) {
    if (is.character(x)) {
      suppressMessages(suppressWarnings(
        readr::read_csv(x, na = c("", "NA", "NaN"), show_col_types = FALSE)
      ))
    } else x
  }

  # ---- 1. Load and clean met data ----
  met_raw <- read_if_path(met_data)

  # Parse datetime — column is date.time_start
  met_raw <- met_raw |>
    dplyr::rename(time = date.time_start) |>
    dplyr::mutate(
      time = lubridate::parse_date_time(time,
               orders = c("Ymd HMS", "Ymd HM", "mdY HM", "mdY HMS"),
               tz = "UTC")
    ) |>
    dplyr::filter(!is.na(time))

  # Apply start / n_years filters
  if (!is.null(start_filter)) {
    met_raw <- dplyr::filter(met_raw, time >= start_filter)
  }
  if (!identical(n_years, "max") && is.numeric(n_years)) {
    t0 <- min(met_raw$time, na.rm = TRUE)
    met_raw <- dplyr::filter(met_raw, time <= t0 + lubridate::dyears(n_years))
  }

  # Flag / remove erroneous SW values (instrument ceiling ~1500 W/m²)
  met_raw <- met_raw |>
    dplyr::mutate(
      solrad_avg = dplyr::if_else(!is.na(solrad_avg) & solrad_avg > 1500,
                                  NA_real_, solrad_avg),
      solrad_avg = dplyr::if_else(!is.na(solrad_avg) & solrad_avg < 0,
                                  0, solrad_avg)
    )

  # Convert pressure mbar → Pa
  met_raw <- met_raw |>
    dplyr::mutate(bp_avg = bp_avg * 100)

  # Coalesce air temperature and RH across D1 sensors.
  # The D1 logger changed sensors in 2019: airtemp_avg / rh_avg / rh_max / rh_min
  # stop in 2019, the HMP columns only start then, and rh_hmp1_avg is empty for
  # 2014–2018. Using a single column left LWR_in NA in every hour, so the model
  # never froze. HMP values in late 2018 – Feb 2019 are bad (e.g. −157 °C), so
  # prefer the original sensors and screen out physically impossible values.
  in_range <- function(x, lo, hi) dplyr::if_else(!is.na(x) & x >= lo & x <= hi, x, NA_real_)
  met_raw <- met_raw |>
    dplyr::mutate(
      T_air_C_raw = dplyr::coalesce(in_range(airtemp_avg,      -50, 35),
                                    in_range(airtemp_hmp1_avg, -50, 35),
                                    in_range(airtemp_hmp2_avg, -50, 35),
                                    in_range(airtemp_hmp3_avg, -50, 35)),
      RH_raw      = dplyr::coalesce(in_range(rh_avg,      0, 100),
                                    in_range(rh_hmp1_avg, 0, 100),
                                    in_range(rh_hmp2_avg, 0, 100),
                                    in_range(rh_hmp3_avg, 0, 100),
                                    in_range((rh_max + rh_min) / 2, 0, 100))
    )

  # ---- 2. Aggregate to hourly ----
  met_hourly <- met_raw |>
    dplyr::mutate(time = lubridate::floor_date(time, "hour")) |>
    dplyr::group_by(time) |>
    dplyr::summarise(
      T_air_C           = mean(T_air_C_raw,   na.rm = TRUE),
      RH                = mean(RH_raw,        na.rm = TRUE),
      pressure          = mean(bp_avg,         na.rm = TRUE),
      wind              = mean(ws_avg,         na.rm = TRUE),
      SW_in             = mean(solrad_avg,     na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(dplyr::across(c(T_air_C, RH, pressure, wind, SW_in),
                                ~ dplyr::if_else(is.nan(.x), NA_real_, .x))) |>
    # short gaps (≤ 6 h): linear interpolation
    dplyr::mutate(dplyr::across(c(T_air_C, RH, pressure, wind, SW_in),
                                ~ zoo::na.approx(.x, na.rm = FALSE, maxgap = 6))) |>
    # longer gaps: month × hour-of-day climatology so the model never sees NA forcing
    dplyr::group_by(.mo = lubridate::month(time), .hr = lubridate::hour(time)) |>
    dplyr::mutate(dplyr::across(c(T_air_C, RH, pressure, wind, SW_in),
                                ~ dplyr::coalesce(.x, mean(.x, na.rm = TRUE)))) |>
    dplyr::ungroup() |>
    dplyr::select(-.mo, -.hr) |>
    dplyr::mutate(
      T_air = T_air_C + 273.15,          # K
      # Saturation vapour pressure (Pa) via Magnus formula
      e_sat = 611.0 * exp(17.27 * T_air_C / (T_air_C + 237.3)),
      e_a   = (RH / 100) * e_sat,        # actual vapour pressure (Pa)
      # Brutsaert (1975) atmospheric emissivity
      emissivity_atm = 1.24 * (e_a / T_air)^(1/7),
      emissivity_atm = pmin(pmax(emissivity_atm, 0.6), 1.0),
      LWR_in  = emissivity_atm * constants$sigma * T_air^4,
      LWR_out = constants$emissivity * constants$sigma * constants$Tf^4,
      # Constant albedo (no AlbedoModel for GL4)
      albedo  = consts$albedo_ice,
      # Fill remaining NAs by linear interpolation where gaps are small
      SW_in    = zoo::na.approx(SW_in,    na.rm = FALSE, maxgap = 6),
      wind     = zoo::na.approx(wind,     na.rm = FALSE, maxgap = 6),
      pressure = zoo::na.approx(pressure, na.rm = FALSE, maxgap = 6),
      RH       = zoo::na.approx(RH,       na.rm = FALSE, maxgap = 6)
    ) |>
    dplyr::select(time, T_air, SW_in, LWR_in, LWR_out,
                  albedo, pressure, wind, relative_humidity = RH)

  # ---- 3. Ice-thickness validation data → MCM-LTER schema ----
  # Same columns/units as prepare_lake_model_inputs() returns for the
  # Antarctic lakes: date_time (POSIXct), z_water_m (positive thickness, m).
  ice_start <- min(met_hourly$time, na.rm = TRUE)
  ice_end   <- max(met_hourly$time, na.rm = TRUE)

  ice_thickness_clean <- read_if_path(ice_thickness) |>
    standardize_gl4_ice(lake_name = cfg$lake_name) |>
    dplyr::filter(!is.na(date_time), !is.na(z_water_m),
                  date_time >= ice_start, date_time <= ice_end) |>
    dplyr::select(location_name, location, date_time, z_water_m)

  # ---- 4. Return in the same list schema as prepare_lake_model_inputs() ----
  message(sprintf("  [GL4] prepared %d hourly rows (%s – %s)",
                  nrow(met_hourly),
                  format(min(met_hourly$time, na.rm = TRUE), "%Y-%m-%d"),
                  format(max(met_hourly$time, na.rm = TRUE), "%Y-%m-%d")))

  n_years_run <- as.numeric(difftime(ice_end, ice_start, units = "days")) / 365.25

  list(
    lake_key      = "GL4",
    lake_name     = cfg$lake_name,
    time_series   = met_hourly,
    ice_thickness = ice_thickness_clean,
    time_model    = met_hourly$time,
    params        = list(alpha = consts$alpha,
                         r     = consts$alpha * consts$dt * 86400 / consts$dx^2,
                         dt = consts$dt, dx = consts$dx,
                         L_initial = consts$L_initial, Chi = consts$Chi,
                         nt = nrow(met_hourly), n_years = n_years_run),
    constants     = consts
  )
}


# ============================================================
# prepare_loc_model_inputs
# — Loch-specific (The Loch, Loch Vale, Rocky Mountain NP) input
#   preparation. Mirrors prepare_gl4_model_inputs() and returns the same
#   schema, so 01_LOC_ice_model.R runs the identical workflow.
#
# Met data: lvws_met_*.csv — Loch Vale weather station, already hourly (UTC):
#   datetime  ISO-8601 UTC          airt      air temperature (°C)
#   wnd_10    10 m wind speed (m/s) RH        relative humidity (%)
#   swrad     incoming SW (W/m²)    lwrad_net NET longwave over the station
#   press     pressure (Pa)                   site (W/m²) — not over the lake
#
#   • LWR_in is estimated with Brutsaert (1975) exactly as for GL4, because
#     lwrad_net is a net value over land/snow at the station, not incoming LW.
#     lwrad_net is kept in the time series as `LW_net_station` for reference.
#   • No albedo data → constant albedo from LAKE_CONFIGS$LOC$albedo_ice.
#   • Ice thickness: none yet. ice_thickness = NULL returns an empty table in
#     the standard schema (location_name, location, date_time, z_water_m), so
#     plotting and downstream code work unchanged. When data arrive, pass a
#     table/path with either z_water_m (m) or date + thickness (cm, like GL4).
# ============================================================
prepare_loc_model_inputs <- function(
    met_data,              # raw LVWS hourly tibble, or path to lvws_met_*.csv
    ice_thickness = NULL,  # NULL (no data yet), tibble, or path
    lake_configs  = LAKE_CONFIGS,
    constants     = CONSTANTS,
    start_filter  = NULL,  # POSIXct; NULL = LAKE_CONFIGS$LOC$start_filter
    n_years       = NULL   # numeric years after start_filter; NULL = LAKE_CONFIGS$LOC$n_years
) {

  cfg    <- lake_configs[["LOC"]]
  consts <- lake_constants("LOC", lake_configs, constants)
  start_filter <- start_filter %||% cfg$start_filter
  if (!is.null(start_filter))
    start_filter <- lubridate::force_tz(as.POSIXct(start_filter), "UTC")
  n_years <- n_years %||% cfg$n_years %||% "max"

  read_if_path <- function(x) {
    if (is.character(x)) {
      suppressMessages(suppressWarnings(
        readr::read_csv(x, na = c("", "NA", "NaN"), show_col_types = FALSE)
      ))
    } else x
  }

  # ---- 1. Load and clean met data ----
  met_raw <- read_if_path(met_data) |>
    dplyr::mutate(time = lubridate::floor_date(
      lubridate::with_tz(lubridate::as_datetime(datetime), "UTC"), "hour")) |>
    dplyr::filter(!is.na(time))

  if (!is.null(start_filter)) met_raw <- dplyr::filter(met_raw, time >= start_filter)
  if (!identical(n_years, "max") && is.numeric(n_years)) {
    t0 <- min(met_raw$time, na.rm = TRUE)
    met_raw <- dplyr::filter(met_raw, time <= t0 + lubridate::dyears(n_years))
  }

  in_range <- function(x, lo, hi) dplyr::if_else(!is.na(x) & x >= lo & x <= hi, x, NA_real_)

  # ---- 2. Hourly series on a complete time spine ----
  met_hourly <- met_raw |>
    dplyr::group_by(time) |>
    dplyr::summarise(
      T_air_C        = mean(in_range(airt,   -50, 35),   na.rm = TRUE),
      RH             = mean(in_range(RH,       0, 100),  na.rm = TRUE),
      pressure       = mean(in_range(press, 5e4, 1.1e5), na.rm = TRUE),
      wind           = mean(in_range(wnd_10,   0, 75),   na.rm = TRUE),
      SW_in          = mean(in_range(swrad,    0, 1500), na.rm = TRUE),
      LW_net_station = mean(lwrad_net,                  na.rm = TRUE),
      .groups = "drop"
    ) |>
    tidyr::complete(time = seq(min(time), max(time), by = "hour")) |>
    dplyr::mutate(dplyr::across(c(T_air_C, RH, pressure, wind, SW_in, LW_net_station),
                                ~ dplyr::if_else(is.nan(.x), NA_real_, .x))) |>
    # short gaps (≤ 6 h): linear interpolation
    dplyr::mutate(dplyr::across(c(T_air_C, RH, pressure, wind, SW_in),
                                ~ zoo::na.approx(.x, na.rm = FALSE, maxgap = 6))) |>
    # longer gaps: month × hour-of-day climatology so the model never sees NA forcing
    dplyr::group_by(.mo = lubridate::month(time), .hr = lubridate::hour(time)) |>
    dplyr::mutate(dplyr::across(c(T_air_C, RH, pressure, wind, SW_in),
                                ~ dplyr::coalesce(.x, mean(.x, na.rm = TRUE)))) |>
    dplyr::ungroup() |>
    dplyr::select(-.mo, -.hr) |>
    dplyr::mutate(
      T_air = T_air_C + 273.15,          # K
      # Saturation / actual vapour pressure (Pa) via Magnus formula
      e_sat = 611.0 * exp(17.27 * T_air_C / (T_air_C + 237.3)),
      e_a   = (RH / 100) * e_sat,
      # Brutsaert (1975) atmospheric emissivity — same as GL4
      emissivity_atm = pmin(pmax(1.24 * (e_a / T_air)^(1/7), 0.6), 1.0),
      LWR_in  = emissivity_atm * constants$sigma * T_air^4,
      LWR_out = constants$emissivity * constants$sigma * constants$Tf^4,
      albedo  = consts$albedo_ice        # constant (no albedo data for the Loch)
    ) |>
    dplyr::select(time, T_air, SW_in, LWR_in, LWR_out,
                  albedo, pressure, wind, relative_humidity = RH, LW_net_station)

  ice_start <- min(met_hourly$time, na.rm = TRUE)
  ice_end   <- max(met_hourly$time, na.rm = TRUE)

  # ---- 3. Ice-thickness validation data (none yet → empty, standard schema) ----
  ice_thickness_clean <- standardize_loc_ice(read_if_path(ice_thickness),
                                             lake_name = cfg$lake_name) |>
    dplyr::filter(date_time >= ice_start, date_time <= ice_end)

  message(sprintf("  [LOC] prepared %d hourly rows (%s – %s) | %d ice-thickness observations",
                  nrow(met_hourly), format(ice_start, "%Y-%m-%d"),
                  format(ice_end, "%Y-%m-%d"), nrow(ice_thickness_clean)))

  n_years_run <- as.numeric(difftime(ice_end, ice_start, units = "days")) / 365.25

  list(
    lake_key      = "LOC",
    lake_name     = cfg$lake_name,
    time_series   = met_hourly,
    ice_thickness = ice_thickness_clean,
    time_model    = met_hourly$time,
    params        = list(alpha = consts$alpha,
                         r     = consts$alpha * consts$dt * 86400 / consts$dx^2,
                         dt = consts$dt, dx = consts$dx,
                         L_initial = consts$L_initial, Chi = consts$Chi,
                         nt = nrow(met_hourly), n_years = n_years_run),
    constants     = consts
  )
}


# ============================================================
# standardize_loc_ice
# — Loch ice thickness → standard schema. NULL / empty input returns an
#   empty table with the right columns. Accepts either z_water_m (m, already
#   standard) or a GL4-style date/date_time + thickness (cm) table.
# ============================================================
standardize_loc_ice <- function(df, lake_name = "The Loch") {
  empty <- tibble::tibble(location_name = character(), location = character(),
                          date_time = as.POSIXct(character(), tz = "UTC"),
                          z_water_m = numeric())
  if (is.null(df) || nrow(df) == 0) return(empty)

  out <- if ("z_water_m" %in% names(df)) {
    tibble::tibble(
      location_name = lake_name,
      location      = if ("location" %in% names(df)) as.character(df$location) else "LOC",
      date_time     = if (inherits(df$date_time, c("POSIXct", "Date"))) {
                        as.POSIXct(df$date_time, tz = "UTC")
                      } else {
                        lubridate::parse_date_time(as.character(df$date_time),
                          orders = c("Ymd HMS", "Ymd HM", "Ymd", "mdy HM", "mdy", "mdY"),
                          tz = "UTC", quiet = TRUE)
                      },
      z_water_m     = abs(as.numeric(df$z_water_m))
    )
  } else {
    standardize_gl4_ice(df, lake_name = lake_name)
  }
  dplyr::filter(out, !is.na(date_time), !is.na(z_water_m))
}
 


# ============================================================
# prepare_model_input
# — single gateway between any input source and run_ice_model
# — warming and albedo trends applied HERE and nowhere else
#
# warming_rate : linear trend added to T_air in Kelvin per year
#                elapsed since the forecast start:
#                  T_air = T_air + warming_rate * (year - baseline_year)
#                0 = no trend; positive = warming; negative = cooling.
#
# albedo_rate  : same structure, applied to albedo instead of T_air:
#                  albedo = albedo + albedo_rate * (year - baseline_year)
#                clamped to [0, 1] afterward so the result stays physical.
#                0 = no trend; positive = albedo increasing over time
#                (more reflective surface -> less absorbed SW -> less melt);
#                negative = albedo decreasing over time (more melt).
# ============================================================
prepare_model_input <- function(
    time_series,
    warming_rate = 0,   # K/yr added to T_air; 0 = no trend
    albedo_rate  = 0,   # unitless/yr added to albedo; 0 = no trend
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
      mutate(LWR_out = (emissivity * sigma * T_air^4) * 0.95)
  }

  baseline_year <- min(year(time_series$time))

  # Apply linear warming trend — ONLY here, ONLY if warming_rate != 0
  if (warming_rate != 0) {
    time_series <- time_series |>
      mutate(T_air = T_air + warming_rate * (year(time) - baseline_year))
  }

  # Apply linear albedo trend — ONLY here, ONLY if albedo_rate != 0.
  # Clamped to [0, 1] so the result always stays physically valid.
  if (albedo_rate != 0) {
    time_series <- time_series |>
      mutate(albedo = pmin(pmax(albedo + albedo_rate * (year(time) - baseline_year), 0), 1))
  }

  time_series |> drop_na(delta_T)
}


run_ice_model <- function(
    time_series,
    constants     = CONSTANTS,
    show_progress = TRUE
) {
  # ---- Unpack constants ----
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

  # ---- Seasonal-ice constants (safe defaults so Antarctic lakes are unaffected) ----
  seasonally_frozen <- constants$seasonally_frozen %||% FALSE
  k_water      <- constants$k_water      %||% 0.57
  rho_water    <- constants$rho_water    %||% 999.8
  Cp_water     <- constants$Cp_water     %||% 4218
  mixing_depth <- constants$mixing_depth %||% 0.5
  L_nucleation <- constants$L_nucleation %||% 0.002
  albedo_water <- constants$albedo_water %||% 0.06

  dt_sec <- dt * 86400
  r      <- alpha * dt_sec / dx^2
  n_iter <- nrow(time_series)

  # ---- Validate required columns ----
  required_cols <- c("time", "T_air", "SW_in", "LWR_in", "LWR_out",
                     "albedo", "pressure", "wind", "delta_T", "relative_humidity")
  missing <- setdiff(required_cols, names(time_series))
  if (length(missing) > 0)
    stop("time_series is missing columns: ", paste(missing, collapse = ", "),
         "\nDid you run prepare_model_input() first?")

  # ---- Extract to plain vectors ----
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

  # ---- Pre-allocate outputs ----
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
  # seasonally-frozen extra outputs (NA for perennial lakes)
  out_phase        <- rep(NA_character_, n_iter)
  out_T_water      <- rep(NA_real_,      n_iter)

  # ---- Initialise state ----
  prevL      <- L_initial
  depth      <- if (L_initial > 0) seq(0, L_initial, by = dx) else NA_real_
  prevT      <- if (L_initial > 0)
                  seq(from = v_T_air[1], to = Tf, length.out = length(depth))
                else numeric(0)
  dL_surface <- 0
  dL_bottom  <- 0

  # Seasonal state machine variables
  phase   <- if (L_initial > 0) "ice" else "open_water"
  T_water <- Tf   # mixed-layer temperature; only meaningful in open_water phase

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

    # ============================================================
    # ICE PHASE — existing physics (perennial lakes always here)
    # ============================================================
    if (!seasonally_frozen || phase == "ice") {

      n_nodes <- length(prevT)
      newT    <- prevT

      # -- Heat diffusion --------------------------------------------------
      if (n_nodes >= 3) {
        interior <- 2:(n_nodes - 1)
        newT[interior] <- prevT[interior] +
          r * (prevT[interior + 1] - 2 * prevT[interior] + prevT[interior - 1])
      }
      if (any(is.na(newT))) newT <- prevT

      # -- Boundary conditions ---------------------------------------------
      if (n_nodes >= 2) {
        newT[1]       <- T_air
        newT[n_nodes] <- Tf
      } else if (n_nodes == 1) {
        newT[1] <- T_air
      }

      # -- Radiative fluxes ------------------------------------------------
      SW_abs <- (1 - Chi) * SW_in * (1 - albedo)
      LW_net <- LWR_in - LWR_out

      # -- Sensible heat flux ----------------------------------------------
      rho_air <- (press * Ma) / (R * T_air)   # kg m^-3; press is in Pa (removed stray *0.1, 2026-10-09)
      Qh      <- rho_air * Ca * Ch * delta_T * wind

      # -- Latent heat flux ------------------------------------------------
      if (length(newT) > 0 && newT[1] >= Tf) {
        A <- 6.1121; B <- 17.502; C <- 240.97; xLatent <- xLv
      } else {
        A <- 6.1115; B <- 22.452; C <- 272.55; xLatent <- xLs
      }
      T_ref       <- T_air - Tf
      ea          <- ((rh / 100) * A * exp((B * T_ref) / (C + T_ref))) * 100   # hPa -> Pa (was / 100, 2026-10-09)
      rho_air_lat <- press * Ma / (R * T_air) * (1 + (epsilon - 1) * (ea / press))
      es0         <- if (length(newT) > 0 && newT[1] >= Tf) {
        (A * exp(0)) * 100                                  # hPa -> Pa
      } else {
        (A * exp((B * T_ref) / (C + T_ref))) * 100          # hPa -> Pa
      }
      Ql <- rho_air_lat * xLatent * Ce * (0.622 / press) * (ea - es0) * wind

      # -- Conductive flux -------------------------------------------------
      Qc <- if (length(prevT) >= 1) k * (prevT[1] - T_air) / dx else 0

      # -- Net surface flux and mass balance --------------------------------
      surface_flux <- SW_abs + (LW_net - Qc) + Qh + Ql

      dL_surface <- 0
      if (!is.na(surface_flux) && surface_flux > 0) {
        dL_surface <- surface_flux * dt_sec / (rho * L_f)
      }

      newL <- prevL - dL_surface

      dL_bottom <- 0
      if (seasonally_frozen && !is.na(newL) && newL > 0 && newL < 2 * dx) {
        # GL4 / seasonally frozen lakes only — thin-ice growth.
        # Ice thinner than 2*dx collapses to a 1-node grid (e.g. 2 mm nucleated
        # ice with dx = 0.1 m), so the finite-difference basal flux below can
        # never fire and the ice would stay frozen at L_nucleation all winter.
        # Instead assume a linear profile T_air -> Tf across the ice and grow it
        # with the integrated Stefan solution (stable for any thickness).
        dT_ice    <- if (is.na(T_air)) 0 else max(0, Tf - T_air)
        L_next    <- sqrt(newL^2 + 2 * k * dT_ice * dt_sec / (rho * L_f))
        dL_bottom <- L_next - newL
        newL      <- L_next
      } else if (!is.na(newL) && newL > 0 && n_nodes >= 2) {
        Q_bottom  <- -k * (newT[n_nodes - 1] - newT[n_nodes]) / dx
        dL_bottom <- Q_bottom * dt_sec / (rho * L_f)
        newL      <- newL + dL_bottom
      }

      newL <- max(0, newL)

      # -- Regrid temperature profile --------------------------------------
      if (newL > 0 && prevL > 0 && length(newT) >= 2 && !all(is.na(newT))) {
        newdepth <- seq(0, newL, by = dx)
        old_grid <- seq(0, prevL, length.out = length(depth))
        if (length(unique(old_grid)) >= 2 && length(newdepth) >= 2) {
          newT <- approx(
            x    = old_grid,
            y    = newT,
            xout = seq(0, newL, length.out = length(newdepth)),
            rule = 2
          )$y
        } else {
          newT <- rep(mean(newT, na.rm = TRUE), length(newdepth))
        }
      } else if (newL <= 0) {
        newdepth <- NA_real_
        newT     <- numeric(0)
      } else {
        newdepth <- seq(0, newL, by = dx)
        newT     <- seq(from = T_air, to = Tf, length.out = length(newdepth))
      }

      # -- Seasonal: switch to open_water when ice disappears ---------------
      if (seasonally_frozen && newL <= 0) {
        phase   <- "open_water"
        T_water <- Tf   # reset mixed layer to freezing point
      }

    } else {
      # ============================================================
      # OPEN WATER PHASE — mixed-layer energy balance + nucleation
      # ============================================================

      # Use open-water albedo
      albedo_eff <- albedo_water

      # Radiative fluxes (LWR_out from water surface temperature)
      SW_abs <- (1 - Chi) * SW_in * (1 - albedo_eff)
      LWR_out_water <- emissivity * sigma * T_water^4
      LW_net <- LWR_in - LWR_out_water

      # Sensible heat (bulk aerodynamic). Positive = heat INTO the water, so the
      # gradient is air minus water: cold air over warmer water cools the lake.
      # (Was T_water - T_air, which warmed the lake in winter so it never refroze.)
      rho_air     <- (press * Ma) / (R * T_air)   # kg m^-3; press in Pa (removed stray *0.1, 2026-10-09)
      dT_bulk     <- T_air - T_water
      Qh          <- rho_air * Ca * Ch * dT_bulk * wind

      # Latent heat from open water surface
      A <- 6.1121; B <- 17.502; C <- 240.97; xLatent <- xLv
      T_ref       <- T_air - Tf
      ea          <- ((rh / 100) * A * exp((B * T_ref) / (C + T_ref))) * 100   # hPa -> Pa (was / 100, 2026-10-09)
      rho_air_lat <- press * Ma / (R * T_air) * (1 + (epsilon - 1) * (ea / press))
      T_ref_w     <- T_water - Tf
      es0         <- (A * exp((B * T_ref_w) / (C + T_ref_w))) * 100   # hPa -> Pa (was / 100, 2026-10-09)
      Ql          <- rho_air_lat * xLatent * Ce * (0.622 / press) * (ea - es0) * wind

      # No conductive flux in open-water phase
      Qc           <- 0
      surface_flux <- SW_abs + LW_net + Qh + Ql

      # Update mixed-layer temperature
      dT_water <- if (!is.na(surface_flux)) {
        surface_flux * dt_sec / (rho_water * Cp_water * mixing_depth)
      } else 0
      T_water <- T_water + dT_water

      # Nucleation: if mixed layer reaches/passes Tf while losing heat → form ice
      dL_surface <- 0
      dL_bottom  <- 0
      if (!is.na(T_water) && T_water <= Tf && !is.na(surface_flux) && surface_flux < 0) {
        T_water  <- Tf
        phase    <- "ice"
        newL     <- L_nucleation
        newdepth <- seq(0, newL, by = dx)
        newT     <- seq(from = T_air, to = Tf, length.out = length(newdepth))
      } else {
        # Clamp water temp: can't meaningfully rise above some physical limit,
        # but we only enforce the lower bound here (no ice can exist > Tf)
        T_water  <- if (is.na(T_water)) Tf else max(Tf, T_water)
        newL     <- 0
        newdepth <- NA_real_
        newT     <- numeric(0)
      }
      LWR_out <- LWR_out_water   # update for storage consistency
    }

    # -- Advance state --------------------------------------------------------
    prevT <- newT
    prevL <- newL
    depth <- newdepth

    # -- Store outputs --------------------------------------------------------
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
    if (seasonally_frozen) {
      out_phase[t_idx]   <- phase
      out_T_water[t_idx] <- T_water
    }

    if (show_progress) pb$tick()
  }

  result <- tibble(
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

  if (seasonally_frozen) {
    result <- result |>
      dplyr::mutate(
        phase   = out_phase,
        T_water = out_T_water
      )
  }

  result
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
    clip_obs_to_model = TRUE,        # drop observations outside the modelled time range
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
      # Fall back to common alternative column names so older / differently
      # formatted validation tables (e.g. time/thickness or date/thickness)
      # still plot instead of erroring.
      pick_col <- function(preferred, fallbacks, what) {
        hit <- c(preferred, fallbacks)[c(preferred, fallbacks) %in% names(ice_thickness)][1]
        if (is.na(hit)) stop(sprintf(
          "plot_ice_model(): no %s column found in ice_thickness. Looked for: %s. Columns present: %s",
          what, paste(c(preferred, fallbacks), collapse = ", "),
          paste(names(ice_thickness), collapse = ", ")))
        if (hit != preferred) message(sprintf(
          "plot_ice_model(): '%s' not found in ice_thickness; using '%s' instead.", preferred, hit))
        hit
      }
      dt_col  <- pick_col(datetime_col, c("date_time", "time", "date"), "datetime")
      obs_col <- pick_col(observed_col, c("z_water_m", "thickness"),    "thickness")

      obs <- ice_thickness |>
        rename(time = all_of(dt_col),
               obs  = all_of(obs_col)) |>
        mutate(time = as.POSIXct(time, tz = "UTC")) |>
        filter(!is.na(time), !is.na(obs))

      # Keep only observations inside the span of modelled output, so the
      # x-axis isn't stretched by validation data before/after the run.
      if (clip_obs_to_model) {
        model_range <- range(results$time[!is.na(results$thickness)], na.rm = TRUE)
        obs <- obs |> filter(time >= model_range[1], time <= model_range[2])
      }
      
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


# ============================================================
# load_ice_observations
# — lightweight loader for a lake's ice-thickness validation data,
#   returning the same schema prepare_lake_model_inputs() /
#   prepare_gl4_model_inputs() put in inputs$ice_thickness
#   (location_name, location, date_time, z_water_m in positive m).
#   Applies the same lake filters (location_name, ice_loc_filter)
#   but needs NO met data, so it is cheap to call from reports /
#   R Markdown where only saved model outputs are loaded.
#
#   lake_key     : "ELB", "WLB", "LH", "LF", "GL4", or "LOC"
#   project_path : repository root (default: working directory)
#   time_range   : optional length-2 POSIXct; keep observations inside it
#                  (e.g. range(results$time)). NULL = keep all.
# ============================================================
load_ice_observations <- function(
    lake_key,
    project_path = ".",
    time_range   = NULL,
    lake_configs = LAKE_CONFIGS
) {
  cfg <- lake_configs[[lake_key]]
  if (is.null(cfg)) stop(sprintf("Unknown lake_key '%s'. Valid options: %s",
                                 lake_key, paste(names(lake_configs), collapse = ", ")))

  if (identical(lake_key, "LOC")) {
    # No Loch ice-thickness data yet. Drop a file at Data/LOC/loc_ice_thickness.csv
    # (z_water_m in m, or date + thickness in cm) and it will be picked up here.
    loc_file <- file.path(project_path, "Data/LOC/loc_ice_thickness.csv")
    loc_raw  <- if (file.exists(loc_file)) readr::read_csv(loc_file, show_col_types = FALSE) else NULL
    obs <- standardize_loc_ice(loc_raw, lake_name = cfg$lake_name)
  } else if (identical(lake_key, "GL4")) {
    obs <- readr::read_csv(file.path(project_path, "Data/GL4/gl4_ice_thickness.nc.data.csv"),
                           show_col_types = FALSE) |>
      standardize_gl4_ice(lake_name = cfg$lake_name)
  } else {
    obs <- readr::read_csv(file.path(project_path, "Data/mcmlter-lake-ice_thickness-20250218_0_2025.csv"),
                           show_col_types = FALSE) |>
      dplyr::mutate(date_time = lubridate::mdy_hm(date_time, tz = "UTC"),
                    z_water_m = z_water_m * -1) |>
      dplyr::filter(location_name == cfg$lake_name)
    if (!is.null(cfg$ice_loc_filter)) obs <- cfg$ice_loc_filter(obs)
  }

  obs <- obs |>
    dplyr::filter(!is.na(date_time), !is.na(z_water_m)) |>
    dplyr::select(location_name, location, date_time, z_water_m) |>
    dplyr::arrange(date_time)

  if (!is.null(time_range)) {
    obs <- dplyr::filter(obs, date_time >= time_range[1], date_time <= time_range[2])
  }
  obs
}
