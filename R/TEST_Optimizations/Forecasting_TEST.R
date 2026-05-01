
# load data 
BOYM <- read_csv("~/Library/CloudStorage/OneDrive-UCB-O365/Documents/MCM-LTER_Met/met stations/mcmlter-clim_boym_15min-20250205.csv") |> 
  mutate(date_time = ymd_hms(date_time)) |> 
  mutate(airtemp_3m_K = airtemp_3m_degc + 273.15)

HOEM <- read_csv("~/Library/CloudStorage/OneDrive-UCB-O365/Documents/MCM-LTER_Met/met stations/mcmlter-clim_hoem_15min-20250205.csv") |> 
  mutate(date_time = ymd_hms(date_time)) |>
  mutate(airtemp_3m_K = airtemp_3m_degc + 273.15)

COHM <- read_csv("~/Library/CloudStorage/OneDrive-UCB-O365/Documents/MCM-LTER_Met/met stations/mcmlter-clim_cohm_15min-20250205.csv") |> 
  mutate(date_time = ymd_hms(date_time)) 

TARM <- read_csv("~/Library/CloudStorage/OneDrive-UCB-O365/Documents/MCM-LTER_Met/met stations/mcmlter-clim_tarm_15min-20250205.csv") |> 
  mutate(date_time = ymd_hms(date_time)) |
  mutate(airtemp_3m_K = airtemp_3m_degc + 273.15)

build_climate_scenario <- function(
    
  # ---- met station dataframes (same as before) ----
  data_sources = list(
    sw_in    = list(df = BOYM, col = "swradin_wm2"),
    lwr_in   = list(df = COHM, col = "lwradin2_wm2"),
    lwr_out  = list(df = COHM, col = "lwradout2_wm2"),
    pressure = list(df = HOEM, col = "bpress_mb"),
    wind     = list(df = BOYM, col = "wspd_ms"),
    rh       = list(df = BOYM, col = "rhh2o_3m_pct")
  ),
  
  # ---- lake monitoring station data for air temp (replaces BOYM T_air) ----
  airt_elb,           # ELBBB air temp dataframe
  airt_wlb,           # WLBBB air temp dataframe (gap-filler)
  wlb_end_filter = as.POSIXct("2023-11-01 00:00:00"),
  
  # ---- albedo dataframe (from AlbedoModel.csv) ----
  albedo_df,          # raw albedo data, must have sed.date and albedo.predict.bb
  lake_name = "East Lake Bonney",
  
  # ---- time span ----
  year_start = 2020,
  year_end   = 2020,
  
  # ---- flat offsets ----
  flat_offsets = list(),
  
  # ---- seasonal adjustments ----
  seasonal_adjustments = list(),
  
  # ---- season definition ----
  season_map = list(
    summer = c(12, 1, 2),
    autumn = c(3, 4, 5),
    winter = c(6, 7, 8),
    spring = c(9, 10, 11)
  ),
  
  # ---- unit conversions (applied before climatology) ----
  unit_conversions = list(
    pressure = function(x) x * 100
  )
  
) {
  
  # ------------------------------------------------------------------
  # 0. Helper: build hourly climatology for one variable
  # ------------------------------------------------------------------
  make_hourly_climatology <- function(df, value_col) {
    df |>
      mutate(
        yday = yday(date_time),
        hour = hour(date_time)
      ) |>
      group_by(yday, hour) |>
      summarize(value = mean(.data[[value_col]], na.rm = TRUE),
                .groups = "drop")
  }
  
  # ------------------------------------------------------------------
  # 1. Air temperature: gap-fill ELBBB with WLBBB, then climatology
  # ------------------------------------------------------------------
  message("Preparing air temperature climatology from lake monitoring stations...")
  
  airt_elb <- airt_elb |>
    mutate(date_time    = mdy_hm(date_time),
           airtemp_3m_K = surface_temp_C + 273.15)
  
  airt_wlb <- airt_wlb |>
    mutate(date_time    = mdy_hm(date_time),
           airtemp_3m_K = surface_temp_C + 273.15) |>
    filter(date_time < wlb_end_filter)
  
  # Build full 15-min grid and gap-fill
  full_ts <- tibble(
    date_time = seq(min(airt_elb$date_time),
                    max(airt_elb$date_time),
                    by = "15 min")
  )
  
  air_temperature <- full_ts |>
    left_join(airt_elb |> select(date_time, airtemp_3m_K),
              by = "date_time") |>
    left_join(airt_wlb |> select(date_time, airtemp_3m_K_wlb = airtemp_3m_K),
              by = "date_time") |>
    mutate(airtemp_3m_K = coalesce(airtemp_3m_K, airtemp_3m_K_wlb)) |>
    select(date_time, airtemp_3m_K)
  
  air_clim <- make_hourly_climatology(air_temperature, "airtemp_3m_K")
  
  # ------------------------------------------------------------------
  # 2. Met station climatologies (sw, lwr, pressure, wind, rh)
  # ------------------------------------------------------------------
  message("Preparing met station climatologies...")
  
  met_climatologies <- imap(data_sources, function(src, var_name) {
    df  <- src$df
    col <- src$col
    
    if (var_name %in% names(unit_conversions)) {
      df <- df |> mutate(across(all_of(col), unit_conversions[[var_name]]))
    }
    
    make_hourly_climatology(df, col)
  })
  
  # ------------------------------------------------------------------
  # 3. Albedo: seasonal climatology by day-of-year
  # ------------------------------------------------------------------
  message("Preparing albedo climatology...")
  
  albedo_clean <- albedo_df |>
    filter(lake == lake_name) |>
    mutate(
      date_time = ymd(sed.date),
      yday      = yday(date_time),
      month     = month(date_time)
    ) |>
    drop_na(albedo.predict.bb)
  
  # Build smooth seasonal climatology:
  # 1. Mean albedo by day-of-year across all years
  # 2. Smooth with a 15-day rolling mean to capture the seasonal trend
  #    without overfitting year-specific variation
  albedo_doy <- albedo_clean |>
    group_by(yday) |>
    summarize(value = mean(albedo.predict.bb, na.rm = TRUE),
              .groups = "drop") |>
    arrange(yday)
  
  # Pad ends to allow circular smoothing (wrap Dec into Jan and vice versa)
  pad      <- 15
  n_doy    <- nrow(albedo_doy)
  padded   <- bind_rows(
    albedo_doy |> tail(pad)    |> mutate(yday = yday - 366),
    albedo_doy,
    albedo_doy |> head(pad)    |> mutate(yday = yday + 365)
  )
  
  smoothed_vals <- stats::filter(padded$value,
                                 rep(1 / (2 * pad + 1), 2 * pad + 1),
                                 sides = 2)
  
  albedo_clim <- albedo_doy |>
    mutate(value = as.numeric(smoothed_vals)[(pad + 1):(pad + n_doy)]) |>
    # expand to hourly so it joins cleanly with the time spine
    crossing(hour = 0:23)
  
  # ------------------------------------------------------------------
  # 4. Build time spine
  # ------------------------------------------------------------------
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
  
  time_df <- tibble(
    time = all_times,
    yday = yday(time),
    hour = hour(time)
  )
  
  # ------------------------------------------------------------------
  # 5. Join all climatologies onto time spine
  # ------------------------------------------------------------------
  rename_map <- c(
    air_temp = "T_air",
    sw_in    = "SW_in",
    lwr_in   = "LWR_in",
    lwr_out  = "LWR_out",
    pressure = "pressure",
    wind     = "wind",
    rh       = "relative_humidity",
    albedo   = "albedo"
  )
  
  result <- time_df |>
    left_join(air_clim,                   by = c("yday", "hour")) |> rename(T_air            = value) |>
    left_join(met_climatologies$sw_in,    by = c("yday", "hour")) |> rename(SW_in            = value) |>
    left_join(met_climatologies$lwr_in,   by = c("yday", "hour")) |> rename(LWR_in           = value) |>
    left_join(met_climatologies$lwr_out,  by = c("yday", "hour")) |> rename(LWR_out          = value) |>
    left_join(met_climatologies$pressure, by = c("yday", "hour")) |> rename(pressure         = value) |>
    left_join(met_climatologies$wind,     by = c("yday", "hour")) |> rename(wind             = value) |>
    left_join(met_climatologies$rh,       by = c("yday", "hour")) |> rename(relative_humidity= value) |>
    left_join(albedo_clim,                by = c("yday", "hour")) |> rename(albedo           = value)
  
  # ------------------------------------------------------------------
  # 6. Add season column
  # ------------------------------------------------------------------
  month_to_season <- imap(season_map, function(months, season_name) {
    tibble(month = months, season = season_name)
  }) |> bind_rows()
  
  result <- result |>
    mutate(month = month(time)) |>
    left_join(month_to_season, by = "month")
  
  # ------------------------------------------------------------------
  # 7. Apply flat offsets
  # ------------------------------------------------------------------
  for (var_name in names(flat_offsets)) {
    col    <- rename_map[[var_name]]
    result <- result |>
      mutate(across(all_of(col), ~ .x + flat_offsets[[var_name]]))
  }
  
  # ------------------------------------------------------------------
  # 8. Apply seasonal adjustments
  # ------------------------------------------------------------------
  for (var_name in names(seasonal_adjustments)) {
    col    <- rename_map[[var_name]]
    adj    <- seasonal_adjustments[[var_name]]
    result <- result |>
      mutate(across(all_of(col), ~ .x + adj[season]))
  }
  
  result
}

# ---- plotting companion (call after build_climate_scenario) ----
plot_scenario <- function(
    scenario_df,
    
    # which variables to plot — subset of output column names
    variables = c("T_air", "SW_in", "LWR_in", "LWR_out", "pressure", "wind", "relative_humidity"),
    
    # "all": one panel per variable in a combined figure
    # "separate": one ggplot object per variable, returned as a named list
    output = "all",
    
    # optional second scenario to overlay (must share same time spine)
    baseline_df = NULL,
    baseline_label = "Baseline",
    scenario_label = "Scenario",
    
    # smooth the hourly data for readability ("none", "day", "week", "month")
    smooth = "day",
    
    # colour for the scenario line
    scenario_colour = "#E8593C",
    baseline_colour = "#3B8BD4"
) {
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(lubridate)
  library(patchwork)   # for combined layout
  
  # ---- labels and units for each output column ----
  var_meta <- tribble(
    ~col,              ~label,                      ~units,
    "T_air",           "Air temperature",           "K",
    "SW_in",           "Shortwave radiation in",    "W m⁻²",
    "LWR_in",          "Longwave radiation in",     "W m⁻²",
    "LWR_out",         "Longwave radiation out",    "W m⁻²",
    "pressure",        "Atmospheric pressure",      "Pa",
    "wind",            "Wind speed",                "m s⁻¹",
    "relative_humidity","Relative humidity",        "%"
  )
  
  # ---- helper: aggregate to chosen temporal resolution ----
  aggregate_ts <- function(df, cols) {
    df %>%
      mutate(
        period = case_when(
          smooth == "day"   ~ floor_date(time, "day"),
          smooth == "week"  ~ floor_date(time, "week"),
          smooth == "month" ~ floor_date(time, "month"),
          TRUE              ~ time   # "none" → keep hourly
        )
      ) %>%
      group_by(period) %>%
      summarize(across(all_of(cols), ~ mean(.x, na.rm = TRUE)), .groups = "drop") %>%
      rename(time = period)
  }
  
  # ---- helper: build one ggplot panel for one variable ----
  make_panel <- function(var_col, meta) {
    agg_scen <- aggregate_ts(scenario_df, var_col)
    
    p <- ggplot(agg_scen, aes(x = time, y = .data[[var_col]]))
    
    if (!is.null(baseline_df)) {
      agg_base <- aggregate_ts(baseline_df, var_col)
      p <- p +
        geom_line(data = agg_base,
                  aes(x = time, y = .data[[var_col]], colour = baseline_label),
                  linewidth = 0.5, alpha = 0.8) +
        geom_line(aes(colour = scenario_label), linewidth = 0.7, alpha = 0.9) +
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
      labs(
        title = meta$label,
        x     = NULL,
        y     = meta$units
      ) +
      theme_minimal(base_size = 11) +
      theme(
        plot.title       = element_text(size = 10, face = "bold", margin = margin(b = 4)),
        axis.text.x      = element_text(size = 8),
        axis.text.y      = element_text(size = 8),
        panel.grid.minor = element_blank(),
        panel.grid.major = element_line(colour = "grey92"),
        legend.position  = "bottom",
        legend.text      = element_text(size = 9)
      )
  }
  
  # ---- build panels only for requested variables ----
  requested_meta <- var_meta %>% filter(col %in% variables)
  
  panels <- map2(
    requested_meta$col,
    split(requested_meta, seq_len(nrow(requested_meta))),
    make_panel
  )
  names(panels) <- requested_meta$col
  
  # ---- return ----
  if (output == "separate") {
    return(panels)
  }
  
  # combined patchwork layout
  n   <- length(panels)
  ncol <- min(2, n)
  wrap_plots(panels, ncol = ncol) +
    plot_annotation(
      title    = paste("Climate scenario:", scenario_label),
      subtitle = paste(
        "Smoothed to:", smooth,
        "| Years:", year(min(scenario_df$time)), "–", year(max(scenario_df$time))
      ),
      theme = theme(
        plot.title    = element_text(size = 13, face = "bold"),
        plot.subtitle = element_text(size = 9, colour = "grey50")
      )
    )
}

clim_scenario <- build_climate_scenario(
  year_start = 2020,
  year_end   = 2050,
  flat_offsets = list(
    air_temp = 0.00001,       # +4 K uniform warming
    wind     = 1.0      # +1.5 m/s uniform increase
  ),
  seasonal_adjustments = list(
    air_temp = c(summer = 2.0, autumn = 3.0, winter = 4.5, spring = 2.5),
    sw_in    = c(summer = 10,  autumn = 5,   winter = 0,   spring = 8)
  )
)

plot_scenario(clim_scenario)

clim_default <- build_climate_scenario()
