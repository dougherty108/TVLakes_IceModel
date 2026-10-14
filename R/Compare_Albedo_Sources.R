###### Albedo source comparison — blue-box vs whole-lake albedo ########
#
# Runs the ice model for each Dry Valley lake twice, identical except for the
# albedo forcing taken from Data/AlbedoModel.csv:
#   "bb"        = albedo.predict.bb        (blue-box pixel; the default model setup)
#   "wholelake" = albedo.predict.wholelake (whole-lake mean)
# Everything else follows each lake's 00_/01_ scripts (same met data, air
# temperature, LAKE_CONFIGS, CONSTANTS, no warming trend).
#
# Writes one CSV per lake and albedo source to
#   Data/model_outputs/albedo_comparison/<LAKE>_<source>_output.csv
# with the albedo forcing alongside the model output. The
# "Albedo source" section of Antarctica_to_Rockies_Comparison_Presentation.Rmd
# plots them. Run from the repository root (the Rmd does this for you when
# rerun_albedo_comparison: true). Each lake runs the full model twice, so
# expect this to take about twice as long as the normal Dry Valley runs.

source("R/functions/libraries.R")
source("R/functions/functions.R")

albedo_lakes   <- c("WLB", "ELB", "LH", "LF")
albedo_sources <- c("bb", "wholelake")
out_dir        <- "Data/model_outputs/albedo_comparison"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

for (lake_key_cmp in albedo_lakes) {
  message(sprintf("==== %s: albedo source comparison ====", lake_key_cmp))

  # Load this lake's met / air-temperature / ice / albedo data exactly as its
  # 00_ script does, in a separate environment
  prep_env <- new.env(parent = globalenv())
  source(sprintf("R/%s/00_%s_data_preparation.R", lake_key_cmp, lake_key_cmp), local = prep_env)

  for (src in albedo_sources) {
    message(sprintf("  -- %s with albedo source '%s'", lake_key_cmp, src))
    inputs_src <- prepare_lake_model_inputs(
      lake_key       = lake_key_cmp,
      station_data   = prep_env$station_data,
      airt_primary   = prep_env$airt_primary,
      airt_secondary = prep_env$airt_secondary,
      ice_thickness  = prep_env$ice_thickness,
      albedo_orig    = prep_env$albedo_orig,
      n_years        = prep_env$n_years,
      albedo_source  = src
    )

    ts_src <- prepare_model_input(inputs_src$time_series,
                                  warming_rate = 0,
                                  constants    = lake_constants(lake_key_cmp))
    res_src <- run_ice_model(ts_src, constants = lake_constants(lake_key_cmp))

    out <- res_src |>
      dplyr::select(time, thickness, SW_abs, LW_net, sensible_Q, latent_Q,
                    conductive_Q, surface_heat_flux, surface_loss, bottom_gain) |>
      dplyr::mutate(albedo = ts_src$albedo, albedo_source = src, lake_key = lake_key_cmp)

    readr::write_csv(out, file.path(out_dir, sprintf("%s_%s_output.csv", lake_key_cmp, src)))
  }
  rm(prep_env)
}

message("Albedo comparison runs written to ", out_dir)
