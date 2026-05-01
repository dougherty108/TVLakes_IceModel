

run_ice_model <- function(
    time_series,                # output from build_climate_scenario() or similar
    L_initial      = 3.88,      # initial ice thickness (m)
    dx             = 0.1,       # spatial step size (m)
    dt             = 1/24,      # time step (days); default = 1 hour
    alpha          = 1.02e-6,   # thermal diffusivity of ice (m²/s)
    k              = 2.22,      # thermal conductivity of ice (W/m/K)
    rho            = 917,       # density of ice (kg/m³)
    L_f            = 334000,    # latent heat of fusion (J/kg)
    sigma          = 5.67e-8,   # Stefan-Boltzmann constant (W/m²/K⁴)
    emissivity     = 0.97,      # ice surface emissivity
    Chi            = 0.43,      # fraction of SW absorbed at surface vs. transmitted
    Ch             = 1.3e-3,    # sensible heat transfer coefficient
    Ce             = 1.3e-3,    # latent heat transfer coefficient
    Ca             = 1005,      # specific heat of air (J/kg/K)
    Ma             = 0.029,     # molar mass of air (kg/mol)
    R              = 8.314,     # universal gas constant (J/mol/K)
    epsilon        = 0.622,     # ratio of molar masses water/dry air
    xLv            = 2.501e6,   # latent heat of vaporization (J/kg)
    xLs            = 2.834e6,   # latent heat of sublimation (J/kg)
    Tf             = 273.15,    # freezing point of water (K)
    warming_rate   = 0.000,     # compounding annual warming rate (fraction/year)
    show_progress  = TRUE
) {
  
  # ---- 0. Pre-process time series ----------------------------------------
  baseline_year <- min(year(time_series$time))
  
  time_series <- time_series |>
    mutate(
      LWR_out          = emissivity * sigma * T_air^4,
      delta_T          = T_air - lag(T_air),
      year             = year(time),
      years_elapsed    = year - baseline_year,
      warming_multiplier = (1 + warming_rate)^years_elapsed,
      T_air            = T_air * warming_multiplier
    ) |>
    drop_na(delta_T) |>
    arrange(time)
  
  n_iter   <- nrow(time_series)
  dt_sec   <- dt * 86400          # dt in seconds (avoids recomputing each loop)
  r        <- alpha * dt_sec / dx^2   # diffusion number (pre-computed)
  
  # ---- 1. Extract all input columns to plain vectors (fast indexing) ------
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
  
  # ---- 2. Pre-allocate output vectors (no list-columns; faster) -----------
  out_time          <- v_time                        # known upfront
  out_thickness     <- numeric(n_iter)
  out_LW_net        <- numeric(n_iter)
  out_SW            <- numeric(n_iter)
  out_SW_abs        <- numeric(n_iter)
  out_sensible_Q    <- numeric(n_iter)
  out_latent_Q      <- numeric(n_iter)
  out_conductive_Q  <- numeric(n_iter)
  out_surface_flux  <- numeric(n_iter)
  out_surface_loss  <- numeric(n_iter)
  out_bottom_gain   <- numeric(n_iter)
  # depth/temperature profiles stored as lists (variable length)
  out_depth         <- vector("list", n_iter)
  out_temperature   <- vector("list", n_iter)
  
  # ---- 3. Initialise state ------------------------------------------------
  L      <- L_initial
  prevL  <- L_initial
  depth  <- seq(0, L, by = dx)
  prevT  <- seq(from = v_T_air[1], to = Tf, length.out = length(depth))
  
  dL_surface <- 0
  dL_bottom  <- 0
  
  if (show_progress) {
    pb <- progress_bar$new(
      format = "[:bar] :percent :elapsed | ETA: :eta",
      total  = n_iter, clear = FALSE
    )
  }
  
  # ---- 4. Main simulation loop -------------------------------------------
  for (t_idx in seq_len(n_iter)) {
    
    # -- 4a. Unpack scalars for this timestep (vector indexing is fast) -----
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
    
    # -- 4b. Heat diffusion (vectorised; no inner for-loop) -----------------
    if (n_nodes >= 3) {
      interior <- 2:(n_nodes - 1)
      newT[interior] <- prevT[interior] +
        r * (prevT[interior + 1] - 2 * prevT[interior] + prevT[interior - 1])
    }
    
    # Boundary conditions — only apply if enough nodes exist
    if (n_nodes >= 2) {
      newT[1]       <- T_air
      newT[n_nodes] <- Tf
    } else if (n_nodes == 1) {
      newT[1] <- T_air
    }
    
    # -- 4c. Radiative fluxes -----------------------------------------------
    SW_abs <- (1 - Chi) * SW_in * (1 - albedo)
    LW_net <- LWR_in - LWR_out
    
    # -- 4d. Sensible heat flux ---------------------------------------------
    rho_air <- (press * Ma) * 0.1 / (R * T_air)
    Qh      <- rho_air * Ca * Ch * delta_T * wind
    
    # -- 4e. Latent heat flux (phase-dependent) -----------------------------
    if (newT[1] >= Tf) {
      A <- 6.1121; B <- 17.502; C <- 240.97
      xLatent <- xLv
    } else {
      A <- 6.1115; B <- 22.452; C <- 272.55
      xLatent <- xLs
    }
    
    T_ref  <- T_air - Tf   # offset used twice below
    ea     <- ((rh / 100) * A * exp((B * T_ref) / (C + T_ref))) / 100
    rho_air_lat <- press * Ma / (R * T_air) * (1 + (epsilon - 1) * (ea / press))
    
    if (newT[1] >= Tf) {
      es0 <- (A * exp((B * (Tf - Tf)) / (C + (Tf - Tf)))) / 100   # = A/100
    } else {
      es0 <- (A * exp((B * T_ref) / (C + T_ref))) / 100
    }
    
    Ql <- rho_air_lat * xLatent * Ce * (0.622 / press) * (ea - es0) * wind
    
    # -- 4f. Conductive flux ------------------------------------------------
    Qc <- k * (prevT[1] - T_air) / dx
    
    # -- 4g. Net surface flux and mass balance ------------------------------
    surface_flux <- SW_abs + (LW_net - Qc) + Qh + Ql
    
    dL_surface <- 0
    if (!is.na(surface_flux) && surface_flux > 0) {
      dL_surface <- surface_flux * dt_sec / (rho * L_f)
    }
    
    newL <- prevL - dL_surface
    
    dL_bottom <- 0
    if (!is.na(newL) && newL > 0) {
      Q_bottom  <- -k * (newT[n_nodes - 1] - newT[n_nodes]) / dx
      dL_bottom <- Q_bottom * dt_sec / (rho * L_f)
      newL      <- newL + dL_bottom
    }
    
    newL <- max(0, newL)
    
    # -- 4h. Regrid temperature profile to new thickness --------------------
    if (newL > 0) {
      newdepth <- seq(0, newL, by = dx)
      newT     <- approx(
        x    = seq(0, prevL, length.out = length(depth)),
        y    = newT,
        xout = seq(0, newL, length.out = length(newdepth)),
        rule = 2
      )$y
    } else {
      newdepth <- NA_real_
      newT     <- numeric(0)
    }
    
    # -- 4i. Advance state --------------------------------------------------
    prevT  <- newT
    prevL  <- newL
    depth  <- newdepth
    
    # -- 4j. Store outputs (direct vector assignment; fastest option) -------
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
    out_depth[[t_idx]]       <- depth
    out_temperature[[t_idx]] <- prevT
    
    if (show_progress) pb$tick()
  }
  
  # ---- 5. Assemble results tibble ----------------------------------------
  tibble(
    time             = out_time,
    thickness        = out_thickness,
    LW_net           = out_LW_net,
    SW               = out_SW,
    SW_abs           = out_SW_abs,
    sensible_Q       = out_sensible_Q,
    latent_Q         = out_latent_Q,
    conductive_Q     = out_conductive_Q,
    surface_heat_flux= out_surface_flux,
    surface_loss     = out_surface_loss,
    bottom_gain      = out_bottom_gain,
    depth            = out_depth,
    temperature      = out_temperature
  )
}

plot_ice_model <- function(
    results,
    ice_thickness   = NULL,   # optional observed ice thickness df for validation
    datetime_col    = "date_time",  # name of datetime column in ice_thickness
    observed_col    = "z_water_m",  # name of thickness column in ice_thickness
    title           = "East Lake Bonney",
    subtitle        = NULL,
    
    # ---- which plots to produce ----
    plot_thickness  = TRUE,
    plot_fluxes     = TRUE,
    plot_temp_profile = TRUE,
    
    # ---- flux panel selection ----
    flux_vars = c("SW_abs", "LW_net", "sensible_Q", "latent_Q",
                  "conductive_Q", "surface_heat_flux"),
    
    # ---- smoothing for flux panels ("none", "day", "week", "month") ----
    smooth = "day",
    
    # ---- colours ----
    model_colour    = "#2166ac",
    observed_colour = "#d6604d",
    
    # ---- output ("print", "list", or "patchwork") ----
    output = "print"
) {
  
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(lubridate)
  library(patchwork)
  
  plots <- list()
  
  # ---- helper: aggregate to chosen temporal resolution -------------------
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
        plot.title        = element_text(size = 11, face = "bold", margin = margin(b = 4)),
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
      group_by(time) |>
      summarize(thickness = max(thickness), .groups = "drop")
    
    p_thick <- ggplot(thick_df, aes(x = time, y = thickness)) +
      geom_line(colour = model_colour, linewidth = 0.8) +
      labs(title = "Ice thickness", x = NULL, y = "Thickness (m)") +
      ice_theme()
    
    if (!is.null(ice_thickness)) {
      obs <- ice_thickness |>
        rename(time = all_of(datetime_col), obs = all_of(observed_col))
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
      SW_abs           = "Absorbed SW (W m⁻²)",
      LW_net           = "Net LW (W m⁻²)",
      sensible_Q       = "Sensible heat (W m⁻²)",
      latent_Q         = "Latent heat (W m⁻²)",
      conductive_Q     = "Conductive heat (W m⁻²)",
      surface_heat_flux= "Net surface flux (W m⁻²)",
      surface_loss     = "Surface melt (m)",
      bottom_gain      = "Bottom growth (m)"
    )
    
    available_flux <- intersect(flux_vars, names(results))
    
    flux_df <- results |>
      select(time, all_of(available_flux)) |>
      smooth_df(available_flux) |>
      pivot_longer(-time, names_to = "variable", values_to = "value") |>
      mutate(variable = factor(variable, levels = available_flux,
                               labels = flux_labels[available_flux]))
    
    p_flux <- ggplot(flux_df, aes(x = time, y = value)) +
      geom_line(colour = model_colour, linewidth = 0.5, alpha = 0.85) +
      geom_hline(yintercept = 0, linetype = "dashed", colour = "grey60",
                 linewidth = 0.4) +
      facet_wrap(~ variable, scales = "free_y", ncol = 2) +
      labs(title = paste("Surface energy fluxes —", smooth, "mean"),
           x = NULL, y = NULL) +
      ice_theme() +
      theme(strip.text = element_text(size = 9))
    
    plots$fluxes <- p_flux
  }
  
  # ======================================================================
  # Panel 3: Temperature profile snapshots
  # ======================================================================
  if (plot_temp_profile) {
    
    # pick ~6 evenly-spaced snapshots across the run
    snap_idx <- round(seq(1, nrow(results), length.out = 6))
    snap_times <- results$time[snap_idx]
    
    profile_df <- results |>
      filter(time %in% snap_times) |>
      select(time, depth, temperature) |>
      mutate(
        depth       = lapply(depth, as.numeric),
        temperature = lapply(temperature, as.numeric)
      ) |>
      unnest(cols = c(depth, temperature)) |>
      mutate(label = format(time, "%Y-%m-%d"))
    
    p_profile <- ggplot(profile_df,
                        aes(x = temperature - 273.15, y = -depth,
                            colour = label, group = label)) +
      geom_path(linewidth = 0.7) +
      scale_colour_brewer(palette = "Blues", direction = 1, name = NULL) +
      labs(title    = "Temperature profile snapshots",
           x        = "Temperature (°C)",
           y        = "Depth (m)") +
      ice_theme()
    
    plots$temp_profile <- p_profile
  }
  
  # ======================================================================
  # Assemble and return
  # ======================================================================
  n <- length(plots)
  
  if (n == 0) {
    message("No plots selected.")
    return(invisible(NULL))
  }
  
  # Build patchwork layout: thickness full-width on top, rest below
  if (output == "list") return(plots)
  
  combined <- if (plot_thickness && n > 1) {
    top_row    <- plots$thickness
    bottom_plots <- plots[names(plots) != "thickness"]
    bottom_row <- wrap_plots(bottom_plots, ncol = if (n - 1 == 1) 1 else 2)
    top_row / bottom_row + plot_layout(heights = c(1, 2))
  } else {
    wrap_plots(plots, ncol = 1)
  }
  
  combined <- combined +
    plot_annotation(
      title    = title,
      subtitle = subtitle %||% paste(
        "Smoothing:", smooth,
        "| Years:", year(min(results$time)), "–", year(max(results$time))
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

prepare_model_input <- function(
    time_series,
    warming_rate   = 0,        # set 0 for scenario data (warming already baked in)
    emissivity     = 0.97,
    sigma          = 5.67e-8
) {
  
  # If LWR_out is missing, compute it from T_air
  if (!"LWR_out" %in% names(time_series)) {
    time_series <- time_series |>
      mutate(LWR_out = emissivity * sigma * T_air^4)
  }
  
  # If delta_T is missing, compute it
  if (!"delta_T" %in% names(time_series)) {
    time_series <- time_series |>
      mutate(delta_T = T_air - lag(T_air))
  }
  
  # Apply compounding warming only if rate > 0 (i.e. observed data pathway)
  if (warming_rate > 0) {
    baseline_year <- min(year(time_series$time))
    time_series <- time_series |>
      mutate(
        years_elapsed      = year(time) - baseline_year,
        warming_multiplier = (1 + warming_rate)^years_elapsed,
        T_air              = T_air * warming_multiplier
      ) |>
      select(-years_elapsed, -warming_multiplier)
  }
  
  time_series |> drop_na(delta_T)
}
