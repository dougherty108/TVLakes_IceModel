
# ---- Observed data pathway ----
inputs      <- prepare_elb_model_inputs(BOYM, HOEM, COHM, TARM,
                                        airt_elb, airt_wlb,
                                        ice_raw, albedo_raw)
prepped_obs <- prepare_model_input(inputs$time_series, warming_rate = 0.000)
results_obs <- run_ice_model(prepped_obs)
plot_ice_model(results_obs)

# ---- Scenario pathway ----
clim_scenario  <- build_climate_scenario(
  airt_elb = airt_elb,
  airt_wlb = airt_wlb,
  albedo_df = albedo_raw,
  year_start = 2020,
  year_end   = 2050,
  flat_offsets = list(air_temp = 0.1, wind = 1.5),
  seasonal_adjustments = list(
    air_temp = c(summer = 2.0, autumn = 3.0, winter = 4.5, spring = 2.5),
    sw_in    = c(summer = 10,  autumn = 5,   winter = 0,   spring = 8)
  )
)
prepped_scen  <- prepare_model_input(clim_scenario, warming_rate = 0)
results_scen  <- run_ice_model(prepped_scen)

# ---- Plot either ----
plot_ice_model(results_obs,  ice_thickness = inputs$ice_thickness)
plot_ice_model(results_scen)

results <- run_ice_model(time_series = clim_scenario)
