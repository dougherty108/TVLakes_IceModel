###### Sanity check — climatology-driven vs. observed-driven ice model ########

### Authors
# Charlie Dougherty

# NOTES
# This is troubleshooting step #2 from the "why do ELB/WLB/LH drop sharply
# under the no-warming climatological forecast while LF stays stable?"
# discussion: run the ice model on `climate_forecast$synthetic` (the
# mean-annual "typical year" climatology reconstructed over the HISTORICAL
# span) and compare it directly to the model run on the REAL observed
# forcing — over the exact same time window, with the exact same initial
# condition (L_initial) and constants.
#
# Why this isolates the problem:
#   The forecast-period comparison (Compare_All_Lakes_Synthetic_Forecast.R)
#   confounds several things at once: (a) a transition from real data to
#   climatological data, (b) a jump from the short modeling-period start
#   condition to wherever the long record happens to end, and (c) whatever
#   biases the climatology itself introduces (independent per-variable
#   averaging breaking the LWR_out <-> T_air coupling, smoothing-out of the
#   nonlinear extremes that drive ice growth/melt, etc).
#
#   Here we hold (a)-the-period and (b)-the-initial-condition FIXED — both
#   runs start from the same `L_initial`, at the same calendar moment, and
#   cover the same span — and change ONLY the forcing data (real observed
#   vs. climatological "typical year" reconstruction of that same period).
#   Whatever divergence appears between the two runs over that identical
#   window can only be coming from the climatology-building step itself
#   (point (c)) — not from spin-up / initial-condition mismatch (b), and not
#   from the historical -> forecast transition (a).
#
# How to read the output:
#   - If the climatology-forced run tracks the real-forced run (and the
#     observed validation points) reasonably closely for a lake, that lake's
#     climatology is internally consistent enough not to be the main source
#     of forecast-period drift — the issue for that lake more likely lies in
#     spin-up / initial-condition mismatch (troubleshooting step #1) or in
#     record composition differences feeding the FUTURE tiling.
#   - If the climatology-forced run diverges sharply from the real-forced
#     run over this identical, fixed-initial-condition window, that confirms
#     the climatology itself (the smoothing / broken cross-variable coupling
#     discussed earlier) is driving the drift — and the fix belongs in
#     generate_climatological_climate() (e.g. recompute LWR_out from the
#     climatological T_air via each lake's empirical emissivity, or build the
#     synthetic forcing from a block-bootstrap of whole observed years
#     instead of per-cell means).
#
# This driver is a thin diagnostic layer over the lake-agnostic functions in
# R/TEST_Optimizations/functions.R — no lake-specific modeling code lives here.

source("R/TEST_Optimizations/libraries.R")
source("R/TEST_Optimizations/functions.R")

###################### Sanity-check assumptions ######################
# How far back to pull each lake's long climatology record — same window
# used by the 0.5_<LAKE> scripts and Compare_All_Lakes_Synthetic_Forecast.R,
# so the climatology being tested here is the SAME climatology that produces
# the forecast-period drift we're trying to explain.
climatology_start <- as.POSIXct("1990-01-01")

# generate_climatological_climate() requires a horizon_year to tile the
# future forcing forward, but `future_physical` is unused in this script —
# we only need `synthetic` (the historical-period reconstruction). Any valid
# year works here.
horizon_year <- 2037

# Per-lake diagnostic density/seasonal-cycle plots from
# generate_climatological_climate() are skipped here (they're already
# available via the 0.5_<LAKE> scripts) — this script's own comparison plots
# are unaffected either way.
plot_diagnostics <- FALSE

# Per-lake settings: which 00_ script to source (builds the short
# modeling-period `inputs` — real observed forcing + observed validation
# ice-thickness — that 01_ runs the ice model on).
lake_specs <- list(
  ELB = list(prep_script = "R/ELB/00_ELB_data_preparation.R"),
  WLB = list(prep_script = "R/WLB/00_WLB_data_preparation.R"),
  LH  = list(prep_script = "R/LH/00_LH_data_preparation.R"),
  LF  = list(prep_script = "R/LF/00_LF_data_preparation.R")
)

###################### Run the sanity check for each lake ######################
sanity_results <- list()

for (lk in names(lake_specs)) {

  spec <- lake_specs[[lk]]
  message("\n==================== ", lk, " ====================")

  # 1. Build (or rebuild) this lake's short modeling-period inputs — the real
  #    observed forcing (`inputs$time_series`) and observed validation ice
  #    thickness (`inputs$ice_thickness`) that 01_ runs the ice model on and
  #    plots against.
  source(spec$prep_script)
  lake_key  <- lk
  lake_name <- inputs$lake_name

  # 2. Pull the same LONG record + "typical year" climatology that the
  #    forecast pipeline uses (identical climatology_start / machinery to
  #    0.5_<LAKE>_data_preparation_forecasting.R and
  #    Compare_All_Lakes_Synthetic_Forecast.R).
  long_inputs <- prepare_lake_model_inputs(
    lake_key       = lake_key,
    station_data   = station_data,
    airt_primary   = airt_primary,
    airt_secondary = airt_secondary,
    ice_thickness  = ice_thickness,
    albedo_orig    = albedo_orig,
    start_filter   = climatology_start,
    n_years        = "max"
  )

  climate_forecast <- generate_climatological_climate(
    lake_key         = lake_key,
    time_series      = long_inputs$time_series,
    horizon_year     = horizon_year,
    plot_diagnostics = plot_diagnostics
  )

  # 3. Crop the climatological "synthetic" reconstruction (which spans the
  #    full long record) down to EXACTLY the same window the ice model
  #    actually runs over (`inputs$time_series`) — same start, same length —
  #    so the only thing that differs between the two runs below is the
  #    forcing data itself.
  obs_start <- min(inputs$time_series$time)
  obs_end   <- max(inputs$time_series$time)

  synthetic_matched <- climate_forecast$synthetic |>
    filter(time >= obs_start, time <= obs_end)

  coverage <- nrow(synthetic_matched) / nrow(inputs$time_series)
  message(sprintf("  matched climatological window covers %.1f%% of the modeling-period rows (%d / %d)",
                  coverage * 100, nrow(synthetic_matched), nrow(inputs$time_series)))
  if (coverage < 0.95) {
    warning(sprintf(
      paste0("[%s] climatological 'synthetic' record only covers %.1f%% of the modeling-period rows — ",
             "the long record may not fully overlap the short modeling period; comparison below may be ",
             "based on a partial/misaligned window."),
      lk, coverage * 100
    ))
  }

  # 4. Run the SAME model (same lake_constants -> same L_initial / Chi, and
  #    NO warming trend, so we isolate the forcing rather than conflating it
  #    with a warming scenario) on (a) the real observed forcing and (b) the
  #    climatological "typical year" reconstruction of that exact same
  #    period. Both start from an identical initial condition.
  ts_real  <- prepare_model_input(inputs$time_series, warming_rate = 0, constants = lake_constants(lake_key))
  ts_synth <- prepare_model_input(synthetic_matched,  warming_rate = 0, constants = lake_constants(lake_key))

  results_real  <- run_ice_model(ts_real,  constants = lake_constants(lake_key), show_progress = FALSE)
  results_synth <- run_ice_model(ts_synth, constants = lake_constants(lake_key), show_progress = FALSE)

  sanity_results[[lk]] <- list(
    lake_name     = lake_name,
    results_real  = results_real,
    results_synth = results_synth,
    ice_thickness = inputs$ice_thickness
  )
}

###################### Per-lake comparison plots ######################
# Each panel overlays: (1) the model run on real observed forcing, (2) the
# model run on the climatological "typical year" reconstruction of that same
# period, and (3) the observed validation ice-thickness points. If (1) tracks
# (3) reasonably (as it should — that's what 01_ is calibrated to do) but (2)
# diverges from both, the climatology itself is introducing the bias.
sanity_plots <- imap(sanity_results, function(sr, lk) {

  combined <- bind_rows(
    sr$results_real  |> select(time, thickness) |> mutate(source = "Real observed forcing"),
    sr$results_synth |> select(time, thickness) |> mutate(source = "Climatological 'typical year' forcing")
  )

  obs <- sr$ice_thickness |>
    rename(time = date_time, obs = z_water_m) |>
    filter(!is.na(time), !is.na(obs))

  ggplot(combined, aes(x = time, y = thickness, colour = source)) +
    geom_line(linewidth = 0.7, alpha = 0.85) +
    geom_point(data = obs, aes(x = time, y = obs), inherit.aes = FALSE,
               colour = "black", size = 1.1, alpha = 0.5) +
    scale_colour_manual(values = c(
      "Real observed forcing"                 = "#3B8BD4",
      "Climatological 'typical year' forcing" = "#E8593C"
    )) +
    labs(
      title    = sprintf("%s — same window, same initial condition, two forcings", sr$lake_name),
      subtitle = "Black points = observed ice-to-ice thickness  |  lines = modeled thickness",
      x        = NULL, y = "Ice thickness (m)", colour = NULL
    ) +
    theme_minimal(base_size = 12) +
    theme(legend.position = "bottom")
})

walk(sanity_plots, print)

###################### Summary table: how far does the climatology-forced ######################
###################### run drift from the real-forced run (and itself)?    ######################
sanity_summary <- imap(sanity_results, function(sr, lk) {

  real  <- sr$results_real
  synth <- sr$results_synth

  # Align on shared timestamps so the two runs can be differenced directly.
  joined <- inner_join(
    real  |> select(time, thickness_real  = thickness),
    synth |> select(time, thickness_synth = thickness),
    by = "time"
  )

  tibble(
    lake                     = lk,
    lake_name                = sr$lake_name,
    L_initial_m              = lake_constants(lk)$L_initial,
    final_thickness_real_m   = tail(real$thickness, 1),
    final_thickness_synth_m  = tail(synth$thickness, 1),
    drift_real_m             = tail(real$thickness, 1)  - real$thickness[1],
    drift_synth_m            = tail(synth$thickness, 1) - synth$thickness[1],
    mean_abs_diff_real_synth_m = mean(abs(joined$thickness_real - joined$thickness_synth), na.rm = TRUE),
    max_abs_diff_real_synth_m  = max(abs(joined$thickness_real - joined$thickness_synth),  na.rm = TRUE)
  )
}) |> bind_rows()

message("\n==================== Sanity-check summary ====================")
message("Same period | same L_initial | same constants | warming_rate = 0 | only the forcing differs")
print(sanity_summary)

# How to read this table:
#   - `drift_real_m`  : how much the REAL-forcing run's thickness changed
#                       over the modeling period (this is what 01_ already
#                       shows you, and what the lake "actually did").
#   - `drift_synth_m` : how much the CLIMATOLOGY-forcing run's thickness
#                       changed over that SAME period, from that SAME start.
#   - If `drift_synth_m` is much larger (more negative) than `drift_real_m`
#     for a lake, its climatology is systematically biased toward melting
#     relative to what the real record produces — i.e. the climatology-
#     building step (independent per-variable averaging / broken LWR_out
#     coupling / smoothed-out extremes) is the dominant source of that
#     lake's forecast-period drop, not spin-up or record-length effects.
#   - `mean_abs_diff_real_synth_m` / `max_abs_diff_real_synth_m` quantify how
#     far apart the two trajectories run on average / at their worst over the
#     identical window — a quick single-number "how wrong is the climatology"
#     score you can compare across lakes (e.g. is it small for LF and large
#     for ELB/WLB/LH, mirroring what you saw in the forecast comparison?).

# To dig further into WHY a particular lake's climatology run diverges, plot
# `prepare_lake_model_inputs(...)`'s `synthetic_matched` against
# `inputs$time_series` variable-by-variable with plot_scenario(), e.g.:
#
#   plot_scenario(synthetic_matched, baseline_df = inputs$time_series,
#                 baseline_label = "Real observed", scenario_label = "Climatology")
#
# — this shows which physical variable(s) (T_air, LWR_out, SW_in, albedo...)
# the climatology reconstructs least faithfully, pinpointing where the
# energy-balance bias is coming from.
