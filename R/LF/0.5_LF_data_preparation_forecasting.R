
#
# Required packages:
required_pkgs <- c("tidyverse","lubridate","zoo","vars","copula","ggplot2","reshape2","gridExtra","scales")
new_pkgs <- required_pkgs[!(required_pkgs %in% installed.packages()[,"Package"])]
if(length(new_pkgs)) install.packages(new_pkgs)
library(tidyverse); library(lubridate); library(zoo); library(vars)
library(copula); library(ggplot2); library(reshape2); library(gridExtra); library(scales)

# pull and collate input met data
source("R/ELB/00_ELB_data_preparation.R")

# ---------------------------
# 1. Prepare and sanity-check
# ---------------------------
# Ensure your tibble is present
if(!exists("time_series_actual")) stop("time_series_actual object not found. Please load it before running this script.")

df <- time_series_actual %>%
  arrange(time) %>%
  mutate(time = as.POSIXct(time, tz = "UTC")) # adjust tz if needed

# Check for NA's and optionally interpolate or remove (here we stop if many NA)
na_count <- sum(is.na(df))
message("Total NA values in dataset: ", na_count)
if(na_count > 0) {
  message("You have NA values. It's recommended to fill or remove them before modelling.")
  # simple linear interpolation for small gaps (uncomment to enable):
  # df <- df %>% mutate(across(where(is.numeric), ~ na.approx(., x = time, na.rm = FALSE)))
}

# ---------------------------
# 2. Transform variables
# ---------------------------
eps <- 1e-6
logit <- function(x) { qlogis(pmin(pmax(x, eps), 1 - eps)) }
inv_logit <- function(x) { plogis(x) }

df_trans <- df %>%
  mutate(
    # convert RH from percent to fraction & clamp
    relative_humidity_frac = relative_humidity / 100,
    relative_humidity_frac = pmin(pmax(relative_humidity_frac, 0.0001), 0.9999),
    
    # convert to logit scale
    rh_t = qlogis(relative_humidity_frac),
    
    # albedo 0–1 clamp and logit
    albedo_clamped = pmin(pmax(albedo, 0.0001), 0.9999),
    albedo_t = qlogis(albedo_clamped),
    
    # wind transform
    wind_t = sqrt(pmax(wind, 0)),
    
    # leave radiative + temperature + pressure mostly untouched
    T_air_t = T_air,
    SW_in_t  = SW_in,
    LWR_in_t = LWR_in,
    pressure_t = pressure
  ) %>%
  dplyr::select(
    time,
    T_air_t, SW_in_t, LWR_in_t,
    albedo_t, pressure_t, wind_t, rh_t
  )



# ---------------------------
# 3. Compute seasonal cycle (hour of day + day of year) and anomalies
# ---------------------------
# We'll compute a seasonal climatology by (hour-of-day, day-of-year) to capture diurnal + annual
df_trans <- df_trans %>%
  mutate(
    hour = hour(time),
    doy = yday(time)
  )

# compute mean seasonal cycle for each variable as mean over (doy, hour)
vars_t <- c("T_air_t","SW_in_t","LWR_in_t","albedo_t","pressure_t","wind_t","rh_t")

seasonal_means <- df_trans %>%
  mutate(
    doy = yday(time),
    hour = hour(time)
  ) %>%
  group_by(doy, hour) %>%      
  summarise(
    T_air_t_seas    = mean(T_air_t, na.rm = TRUE),
    SW_in_t_seas    = mean(SW_in_t, na.rm = TRUE),
    LWR_in_t_seas   = mean(LWR_in_t, na.rm = TRUE),
    albedo_t_seas   = mean(albedo_t, na.rm = TRUE),
    pressure_t_seas = mean(pressure_t, na.rm = TRUE),
    wind_t_seas     = mean(wind_t, na.rm = TRUE),
    rh_t_seas       = mean(rh_t, na.rm = TRUE),
    .groups = "drop"
  )

# join back to get anomalies
df_anom <- df_trans %>%
  left_join(seasonal_means, by = c("doy","hour"), suffix = c("","_seas")) %>%
  mutate(across(all_of(vars_t), ~ . - get(paste0(cur_column(), "_seas")), .names = "anom_{col}"))

# Build matrix of anomalies for VAR
anom_names <- paste0("anom_", vars_t)
Y <- df_anom %>%
  dplyr::select(all_of(anom_names)) %>%
  as.matrix()

# remove rows with any NA in Y
na_rows <- apply(Y, 1, function(x) any(is.na(x)))
if(any(na_rows)) {
  warning(sum(na_rows), " rows contain NA in anomalies. These will be removed for VAR fitting.")
  Y_fit <- Y[!na_rows, ]
  df_fit <- df_anom[!na_rows, ]
} else {
  Y_fit <- Y
  df_fit <- df_anom
}

# ---------------------------
# 4. Fit VAR (select lag)
# ---------------------------
max_lag <- 24  # adjust depending on data frequency / memory (48 for up to 2-day memory if hourly)
lag_sel <- VARselect(Y_fit, lag.max = max_lag, type = "const")
message("Lag selection results:"); print(lag_sel$selection)

p_choice <- as.integer(lag_sel$selection["AIC(n)"])  # choose AIC-selected lag
if(is.na(p_choice)) p_choice <- 1
message("Selected VAR lag p = ", p_choice)

var_model <- VAR(Y_fit, p = p_choice, type = "const")
summary(var_model)

# Extract residuals (for bootstrap) and their covariance
resids <- residuals(var_model)   # matrix (n_obs - p) x nvars
Sigma_res <- cov(resids, use = "pairwise.complete.obs")

simulate_VAR_bootstrap <- function(var_model, n_sim, init_y = NULL, resids = NULL, seed = NULL) {
  if(!is.null(seed)) set.seed(seed)
  
  # dimensions
  p  <- var_model$p
  Y  <- var_model$y
  k  <- ncol(Y)
  varnames <- colnames(Y)
  
  # Extract coefficient lists
  coefs_list <- var_model$varresult
  
  # Prepare storage
  A_list <- vector("list", p)
  for(l in 1:p) {
    A_list[[l]] <- matrix(0, nrow = k, ncol = k)
  }
  const_vec <- numeric(k)
  
  # Build coefficient matrices safely
  for(i in seq_len(k)) {
    this_mod <- coefs_list[[i]]
    co <- coef(this_mod)   # <--- **THIS is co** (now defined!)
    names_co <- names(co)
    
    # intercept handling
    if("const" %in% names_co) {
      const_vec[i] <- co["const"]
    } else if("(Intercept)" %in% names_co) {
      const_vec[i] <- co["(Intercept)"]
    } else {
      const_vec[i] <- 0
    }
    
    # lag coefficients
    for(l in 1:p) {
      lag_names <- paste0("L", l, ".", varnames)
      present <- intersect(lag_names, names_co)
      if(length(present) > 0) {
        A_list[[l]][i, match(present, lag_names)] <- co[present]
      }
    }
  }
  
  # Initialization
  if(is.null(init_y)) {
    init_y <- tail(Y, p)
  }
  state <- as.matrix(init_y)
  
  if(is.null(resids)) stop("Must supply residual matrix")
  resids <- as.matrix(resids)
  
  # Storage for simulated anomalies
  Ysim <- matrix(NA_real_, nrow = n_sim, ncol = k)
  colnames(Ysim) <- varnames
  
  # Recursive simulation
  for(t in 1:n_sim) {
    mean_t <- const_vec
    for(l in 1:p) {
      past_row <- state[nrow(state) - (l - 1), ]
      mean_t <- mean_t + A_list[[l]] %*% past_row
    }
    e_t <- resids[sample(nrow(resids), 1), ]
    new_y <- as.numeric(mean_t + e_t)
    Ysim[t, ] <- new_y
    
    # roll state
    if(p > 1) {
      state <- rbind(state[-1,,drop=FALSE], new_y)
    } else {
      state <- matrix(new_y, nrow = 1)
    }
  }
  
  return(as.data.frame(Ysim))
}


# 5. Synthetic simulation (bootstrap residual VAR simulation)
# ---------------------------------------------------------
# var_model must already be fitted, e.g.:
# var_model <- VAR(df_var, p = lag_order, type = "const")

# First, get residuals used for bootstrapping:
resids <- residuals(var_model)  # matrix: nobs x k
resids <- as.matrix(resids)     # ensure matrix form
n_sim  <- nrow(resids)          # simulate the same number of observations

# Run the simulation:
sim_anom_mat <- simulate_VAR_bootstrap(
  var_model = var_model,
  n_sim     = n_sim,
  init_y    = NULL,     # automatically uses last p model values
  resids    = resids,   # bootstrap from empirical residuals
  seed      = 123       # optional reproducibility
)

# Convert to dataframe and keep column names consistent
sim_anom <- as.data.frame(sim_anom_mat)
colnames(sim_anom) <- colnames(var_model$y)

# Check the result:
summary(sim_anom)
sapply(sim_anom, sd)
any(is.na(sim_anom))


# ---------------------------
# 6. Reconstruct physical variables
# ---------------------------
# sim_anom is n_sim x k with column names matching var_model$y (which matches var names in Y_fit)
# We need to map them back to original rows with seasonal cycle and inverse transforms.

# Build a tibble to hold simulated anomalies aligned to the original df rows
sim_anom_df <- as_tibble(sim_anom)
# Ensure ordering of columns corresponds to anom_names; var_model$y column names might be the same
# var_model$y colnames should be anom_names; check:
if(!all(colnames(var_model$y) %in% anom_names)) {
  warning("VAR column names differ from expected anomaly names. Attempting to align by position.")
}

# We'll take the same time index as df (even if some rows were removed during fitting).
# For rows that were excluded (NA rows), we'll fill with NA or simulated values — simplest: return full-length sim by aligning indices.
sim_full <- df_anom %>%
  dplyr::select(time, doy, hour) %>%
  mutate(row_id = row_number()) %>%
  # attach simulated anomalies in order (if df had NA rows removed during fit, simulation used contiguous fit rows)
  mutate(sim_index = row_number())  # one-to-one

# If we removed rows during VAR fitting, we must align simulated output with original df rows:
if(any(na_rows)) {
  # we simulated n_sim = nrow(df), but the VAR used only rows where !na_rows; our simulate_VAR_bootstrap used init from fitted data and
  # simulated n_sim steps; to be cautious, we'll take the first n_sim simulated rows and map them to the original time order.
  # For simplicity, map sequentially: (user can refine if they want strict mapping)
  # Attach by position:
  sim_full <- sim_full %>%
    bind_cols(as_tibble(sim_anom)[1:nrow(sim_full), , drop = FALSE])
} else {
  sim_full <- sim_full %>%
    bind_cols(as_tibble(sim_anom)[1:nrow(sim_full), , drop = FALSE])
}

# Now add back seasonal means for each variable
# bring seasonal_means into sim_full by (doy,hour)
sim_full <- sim_full %>%
  left_join(seasonal_means, by = c("doy","hour"))


# For each variable, compute simulated physical value = anomaly_sim + seasonal_mean
# anom names are anom_<var>
recon <- sim_full
for(v in vars_t) {
  anom_col <- paste0("anom_", v)
  seas_col <- paste0(v, "_seas")   # seasonal_means columns used suffix "_seas" earlier
  out_col  <- paste0(v, "_sim_recon")
  # the seasonal mean column exists as column named like "T_air_t_seas" in sim_full
  recon[[out_col]] <- recon[[anom_col]] + recon[[seas_col]]
}

# Now invert transforms to original physical variables
# recall transforms:
# rh_t = logit(relative_humidity)  -> inv_logit
# albedo_t = logit(albedo) -> inv_logit
# wind_t = sqrt(wind) -> square
# T_air_t was unchanged

# Create final synthetic tibble
sigma_sb <- 5.670374419e-8  # Stefan-Boltzmann constant

synthetic <- tibble(
  time = recon$time,
  T_air = recon$T_air_t_sim_recon,      # Kelvin
  SW_in = recon$SW_in_t_sim_recon,
  LWR_in = recon$LWR_in_t_sim_recon,
  #LWR_out_raw = recon$LWR_out_t_sim_recon,  # we'll optionally replace with physics-based calc below
  albedo = pmin(pmax(inv_logit(recon$albedo_t_sim_recon), 0), 1),
  pressure = recon$pressure_t_sim_recon,
  wind = (recon$wind_t_sim_recon)^2,     # inverse sqrt -> square
  relative_humidity = pmin(pmax(inv_logit(recon$rh_t_sim_recon), 0), 1)
) %>% mutate(
  # delta_T relative to previous time
  delta_T = T_air - lag(T_air)
)

##### Drop in Code patch to fix fit errors: ############
# ---------- Drop-in correction patch ----------
# Station coordinates (you provided)
lat_site <- -77.7333
lon_site <- 162.1667
tz_site  <- "UTC"   # keep UTC unless you need local TZ

# Packages
required <- c("dplyr","lubridate","suncalc","purrr")
newpk <- required[!(required %in% installed.packages()[,"Package"])]
if(length(newpk)) install.packages(newpk)
library(dplyr); library(lubridate); library(suncalc); library(purrr)

# Ensure 'synthetic' and 'df' exist
if(!exists("synthetic")) stop("No object named `synthetic` found. Run reconstruction first.")
if(!exists("df")) stop("Observed data `df` is missing. Required for quantile mapping/clipping bounds.")

# 1) Compute solar elevation for synthetic times
# suncalc::getSunlightPosition returns altitude in radians
sunpos <- getSunlightPosition(date = synthetic$time, lat = lat_site, lon = lon_site)
synthetic$solar_alt <- sunpos$altitude  # radians; alt <= 0 => sun below horizon

# 2) Shortwave fixes: force SW=0 when sun below horizon, remove negatives, clip at obs 99.9th
# First compute empirical upper bound from observed data (use observed SW seasonal mask where sun > 0)
# compute observed solar altitude for df as well (so ub excludes true-night zeros)
obs_sunpos <- getSunlightPosition(date = df$time, lat = lat_site, lon = lon_site)
df$solar_alt <- obs_sunpos$altitude

# Observed upper bound (exclude true-night zeros)
ub <- quantile(df$SW_in[df$solar_alt > 0], probs = 0.999, na.rm = TRUE)

synthetic <- synthetic %>%
  mutate(
    SW_in_orig = SW_in,               # keep original simulated SW if you want to inspect
    # zero where sun below horizon - preserves midnight sun in summer since solar_alt>0 there
    SW_in = ifelse(solar_alt <= 0, 0, SW_in),
    # remove small numerical negative leftovers
    SW_in = ifelse(SW_in < 0, 0, SW_in),
    # clip to empirical upper bound to remove unreal spikes
    SW_in = pmin(SW_in, ub)
  )

# 3) Temperature quantile mapping by (doy, hour) window
# Build observed grouped lists for quick lookup
df <- df %>% mutate(doy = yday(time), hour = hour(time))
obs_groups <- df %>%
  group_by(doy, hour) %>%
  summarise(vals = list(na.omit(T_air)), n = length(na.omit(T_air)), .groups = "drop")

# small helper: circular day distance (handles year wrap)
circ_dist <- function(a, b, nyear = 365) {
  d <- abs(a - b)
  pmin(d, nyear - d)
}

# Function to get pooled observed values within +/- window_days of target doy and same hour
get_obs_pool <- function(target_doy, target_hour, window_days = 14) {
  # find doy candidates from obs_groups
  # compute distance for each obs_group doy -> select those within window_days
  pool <- obs_groups %>%
    filter(hour == target_hour) %>%
    mutate(dd = circ_dist(doy, target_doy)) %>%
    filter(dd <= window_days) %>%
    pull(vals)
  if(length(pool) == 0) return(numeric(0))
  # pool is list of vectors; combine
  unlist(pool)
}

# Quantile-map a single value using pooled observed sample:
qm_map_one <- function(x, obs_pool) {
  if(is.na(x) || length(obs_pool) < 10) return(x)  # not enough obs to map -> keep as-is
  # p = empirical CDF of x relative to obs pool
  p <- ecdf(obs_pool)(x)
  # map to obs quantile
  as.numeric(quantile(obs_pool, probs = p, na.rm = TRUE, type = 8))
}

# Apply quantile mapping over synthetic times (vectorised-ish)
window_days <- 14  # +/- 14 days = 29-day window
synthetic <- synthetic %>%
  mutate(doy = yday(time), hour = hour(time)) %>%
  mutate(
    # precompute obs pools for each unique (doy,hour) in synthetic to speed mapping
    obs_pool_id = paste0(doy,"_",hour)
  )

unique_keys <- unique(synthetic$obs_pool_id)
# Build a named list of obs pools
obs_pool_list <- setNames(vector("list", length(unique_keys)), unique_keys)
for(k in unique_keys) {
  parts <- strsplit(k, "_")[[1]]
  dd <- as.integer(parts[1]); hh <- as.integer(parts[2])
  obs_pool_list[[k]] <- get_obs_pool(dd, hh, window_days = window_days)
}

# Now map values (do in chunks to avoid huge mapply overhead)
# Create vector of mapped T_air
mapped_T <- vector("numeric", nrow(synthetic))
for(i in seq_len(nrow(synthetic))) {
  key <- synthetic$obs_pool_id[i]
  obs_pool <- obs_pool_list[[key]]
  mapped_T[i] <- qm_map_one(synthetic$T_air[i], obs_pool)
}

# Replace only where mapping produced a non-NA numeric (i.e., obs_pool had enough data)
replace_idx <- !is.na(mapped_T)
synthetic$T_air_qm <- synthetic$T_air   # keep original synthetic T_air for comparison
synthetic$T_air[replace_idx] <- mapped_T[replace_idx]

# 4) Recompute LWR_out from T_air using observed emissivity (recompute if not available)
sigma_sb <- 5.670374419e-8
if(exists("orig_emissivity")) {
  emissivity <- orig_emissivity
} else {
  emissivity <- mean((df$LWR_out) / (sigma_sb * (df$T_air)^4), na.rm = TRUE)
  emissivity <- pmin(pmax(emissivity, 0.4), 1.0)
}
synthetic <- synthetic %>% mutate(
  LWR_out = emissivity * sigma_sb * (T_air)^4
)

# 5) Recompute LWR_in variance correction (optional mild correction):
# We'll nudge LWR_in so its std matches observed within that (doy,hour) window.
# Compute observed sd by (doy,hour) pooled window
obs_sd_by_key <- df %>%
  group_by(doy, hour) %>%
  summarise(sd_obs = sd(LWR_in, na.rm = TRUE), .groups = "drop") %>%
  mutate(key = paste0(doy,"_",hour))

synthetic <- synthetic %>%
  left_join(obs_sd_by_key %>% dplyr::select(key, sd_obs), by = c("obs_pool_id" = "key")) %>%
  mutate(
    # if sd_obs exists and synthetic's local sd is lower, amplify small residuals a bit
    LWR_in_resid = LWR_in - mean(LWR_in, na.rm = TRUE),
    LWR_in = ifelse(!is.na(sd_obs) & sd(LWR_in, na.rm=TRUE) < sd_obs,
                    mean(LWR_in, na.rm=TRUE) + LWR_in_resid * (sd_obs / (sd(LWR_in, na.rm=TRUE) + 1e-9)),
                    LWR_in)
  ) %>%
  dplyr::select(-LWR_in_resid, -sd_obs)

# 6) Final physical constraints and tidy
synthetic_fixed <- synthetic %>%
  mutate(
    SW_in = pmax(SW_in, 0),
    albedo = pmin(pmax(albedo, 0), 1),
    relative_humidity = pmin(pmax(relative_humidity, 0), 1),
    wind = pmax(wind, 0),
    pressure = pmax(pressure, 1)
  ) %>%
  dplyr::select(-solar_alt, -obs_pool_id, -doy, -hour)

# Report diagnostics after fixes
message("Diagnostics before/after fixes:")
pre_counts <- synthetic %>% summarise(
  neg_SW = sum(SW_in_orig < 0, na.rm=TRUE),
  n240_260 = sum(T_air_qm >= 240 & T_air_qm <= 260, na.rm=TRUE)
)
post_counts <- synthetic_fixed %>% summarise(
  neg_SW = sum(SW_in < 0, na.rm=TRUE),
  n240_260 = sum(T_air >= 240 & T_air <= 260, na.rm=TRUE)
)
print(bind_rows(before = pre_counts, after = post_counts))

# Save result to global env
assign("synthetic_fixed", synthetic_fixed, envir = .GlobalEnv)
message("synthetic_fixed created (clamped SW, QM T_air).")
# ---------- End patch ----------

# ----------------------------
# Align sim_anom -> full df_anom -> apply QM -> rebuild T_air
# ----------------------------

# 1) Determine columns in common between sim_anom and df_anom
common_cols <- intersect(colnames(sim_anom), colnames(df_anom))
if(length(common_cols) == 0) {
  # If df_anom uses 'anom_T_air_t' naming and sim_anom uses it too, they will intersect.
  # Otherwise try to match by pattern "anom_" in sim_anom and df_anom
  common_cols <- intersect(grep("^anom_", colnames(sim_anom), value = TRUE),
                           grep("^anom_", colnames(df_anom), value = TRUE))
}
if(length(common_cols) == 0) stop("Could not find shared anomaly column names between sim_anom and df_anom.")

message("Common anomaly columns used for alignment: ", paste(common_cols, collapse = ", "))

# 2) Build candidate mask of rows in df_anom that are complete for those columns
mask_complete <- complete.cases(df_anom[, common_cols, drop = FALSE])
n_mask <- sum(mask_complete)
n_sim  <- nrow(sim_anom)
message("df_anom complete-case rows for those columns: ", n_mask, "; sim_anom rows: ", n_sim)

# 3) Choose rows to fill in df_anom for sim_anom
if(n_mask == n_sim) {
  use_idx <- which(mask_complete)
  method_used <- "exact_complete_match"
} else if(n_mask > n_sim) {
  # More complete rows than sim rows -> assume sim corresponds to first n_sim of those complete rows
  use_idx <- which(mask_complete)[1:n_sim]
  method_used <- "first_N_of_complete_rows"
} else {
  # n_mask < n_sim: not enough strictly complete rows. Try a fallback:
  # Use rows with smallest number of NA among the relevant columns (least-missing), preserving time order.
  miss_count <- apply(is.na(df_anom[, common_cols, drop = FALSE]), 1, sum)
  ranked <- order(miss_count, decreasing = FALSE)  # fewest NAs first
  # pick first n_sim indices, then sort to keep chronological order
  use_idx <- sort(ranked[1:n_sim])
  method_used <- "least-missing_fallback"
}

message("Alignment method used: ", method_used)
message("Filling sim_anom into df_anom at indices: ", paste(head(use_idx,3), collapse = ", "),
        " ... ", paste(tail(use_idx,3), collapse = ", "))

# 4) Build full-length sim_anom_full with same time index as df_anom
sim_anom_full <- df_anom %>% dplyr::select(time) 

# create anomaly columns initialized NA with same names as sim_anom columns
for(v in colnames(sim_anom)) {
  sim_anom_full[[v]] <- NA_real_
}

# 5) Fill the chosen use_idx rows with sim_anom rows (align by order)
nfill <- min(length(use_idx), nrow(sim_anom))
for(v in colnames(sim_anom)) {
  sim_anom_full[[v]][use_idx[1:nfill]] <- sim_anom[[v]][1:nfill]
}

# quick diagnostic: how many non-NA filled per column
filled_counts <- sapply(colnames(sim_anom), function(v) sum(!is.na(sim_anom_full[[v]])))
message("Filled counts (non-NA) per sim var (first few):")
print(head(filled_counts, 10))

# 6) Join anomalies and seasonal T into synthetic
# ensure synthetic has doy/hour
if(!"doy" %in% names(synthetic_fixed)) synthetic <- synthetic_fixed %>% mutate(doy = yday(time))
if(!"hour" %in% names(synthetic_fixed)) synthetic_fixed <- synthetic_fixed %>% mutate(hour = hour(time))

# Determine seasonal column name in df_anom (common variants)
seas_candidates <- c("T_air_t_seas","T_air_seasonal","T_air_seas","T_air_t_season_mean")
seas_col <- intersect(seas_candidates, names(df_anom))
if(length(seas_col) == 0) stop("No seasonal temperature column found in df_anom (expected one of: T_air_t_seas, T_air_seasonal, ...).")
seas_col <- seas_col[1]
# if needed rename df_anom seasonal to canonical name (not strictly necessary here)
df_anom2 <- df_anom %>% rename(T_air_t_seas = !!sym(seas_col))

# join anomaly and seasonal back into synthetic
synthetic_fixed <- synthetic_fixed %>%
  left_join(sim_anom_full %>% dplyr::select(time, all_of(colnames(sim_anom))), by = "time") %>%
  left_join(df_anom2 %>% dplyr::select(time, T_air_t_seas), by = "time")


# 7) Build pre-QM T_air_raw if anom + seas present
if(!("anom_T_air_t" %in% names(synthetic_fixed))) {
  # if sim_anom uses different anomaly name for T, try to find it
  t_anom_cand <- intersect(c("anom_T_air_t","anom_T_air","T_air_anom","anom_air_temp"), names(synthetic))
  if(length(t_anom_cand)==0) stop("Cannot find T-air anomaly in synthetic after join. Columns present: ", paste(names(synthetic), collapse=", "))
  synthetic_fixed <- synthetic_fixed %>% rename(anom_T_air_t = !!sym(t_anom_cand[1]))
}
if(!("T_air_t_seas" %in% names(synthetic_fixed))) stop("T_air_t_seas missing in synthetic after join; can't reconstruct.")

synthetic_fixed <- synthetic_fixed %>% mutate(T_air_raw = anom_T_air_t + T_air_t_seas)

# 8) Quantile mapping on anomalies (seasonal window)
obsA <- df_anom2 %>% dplyr::select(time, doy, hour, anom_T_air_t)
window_days <- 14
circ_dist <- function(a,b,N=365) pmin(abs(a-b), N-abs(a-b))

get_pool <- function(target_doy, target_hour) {
  obsA %>%
    filter(hour == target_hour) %>%
    mutate(dd = circ_dist(doy, target_doy)) %>%
    filter(dd <= window_days) %>%
    pull(anom_T_air_t)
}

qm_one <- function(x, pool) {
  if(is.na(x) || length(pool) < 30) return(x)
  p <- ecdf(pool)(x)
  quantile(pool, probs = p, type = 8, na.rm = TRUE)
}

synthetic_fixed = synthetic_fixed |> 
  mutate(doy = yday(time))

synthetic_fixed$anom_T_air_qm <- purrr::pmap_dbl(
  list(synthetic_fixed$anom_T_air_t, synthetic_fixed$doy, synthetic_fixed$hour),
  function(x, doy, hour) qm_one(x, get_pool(doy, hour))
)

# 9) Reconstruct final T_air and recompute LWR_out
synthetic_fixed <- synthetic_fixed %>% mutate(T_air = anom_T_air_qm + T_air_t_seas)

sigma <- 5.670374419e-8
orig_emissivity <- mean(df$LWR_out / (sigma * df$T_air^4), na.rm=TRUE)
orig_emissivity <- min(max(orig_emissivity, 0.4), 1.0)

synthetic_fixed <- synthetic_fixed %>% mutate(LWR_out = orig_emissivity * sigma * (T_air^4))

# Diagnostics
message("Finished alignment/QM. Diagnostics:")
message("Method used: ", method_used)
message("sim_anom rows:", n_sim, " ; df_anom rows:", nrow(df_anom), " ; synthetic rows:", nrow(synthetic))
message("non-NA filled in anom_T_air_t:", sum(!is.na(sim_anom_full$anom_T_air_t)))
message("synthetic T_air summary:")
print(summary(synthetic$T_air))


# We keep LWR_out computed physically, but keep the raw simulated as well if you want to compare:
#synthetic <- synthetic %>% relocate(LWR_out_raw, .after = LWR_out)

# ---------------------------
# 8. Enforce simple physical constraints
# ---------------------------
synthetic <- synthetic_fixed %>%
  mutate(
    albedo = pmin(pmax(albedo, 0), 1),
    relative_humidity = pmin(pmax(relative_humidity, 0), 1),
    wind = pmax(wind, 0),
    pressure = pmax(pressure, 1)  # ensure positive (Pa)
  )

# ---------------------------
# 9. Quick diagnostics & plots
# ---------------------------
# Combine original and synthetic
plot_vars <- c("T_air","SW_in","LWR_in","LWR_out","albedo","wind","relative_humidity")

orig_plot_df <- df %>%
  dplyr::select(time, all_of(plot_vars)) %>%
  pivot_longer(-time, names_to = "variable", values_to = "value") %>%
  mutate(source = "orig")

synth_plot_df <- synthetic %>%
  dplyr::select(time, all_of(plot_vars)) %>%
  pivot_longer(-time, names_to = "variable", values_to = "value") %>%
  mutate(source = "synth")

combined_df <- bind_rows(orig_plot_df, synth_plot_df)

# Split by variable
plot_list <- lapply(unique(combined_df$variable), function(var_name) {
  df_sub <- combined_df %>% filter(variable == var_name)
  ggplot(df_sub, aes(x = value, fill = source, colour = source)) +
    geom_density(alpha = 0.2, linewidth = 0.5) +
    ggtitle(var_name) +
    theme_minimal()
})

# Show first 4 density plots
library(gridExtra)
grid.arrange(grobs = plot_list[1:4], ncol = 2)

# ACF for T_air original vs synthetic
acf_orig <- acf(na.omit(df$T_air), plot = FALSE)
acf_synth <- acf(na.omit(synthetic$T_air), plot = FALSE)
# You can plot these in RStudio etc.; we'll produce a simple overlay plot using ggplot
acf_df <- tibble(lag = acf_orig$lag, orig = acf_orig$acf, synth = acf_synth$acf) %>%
  pivot_longer(-lag, names_to = "series", values_to = "acf")
ggplot(acf_df, aes(x = lag, y = acf, colour = series)) + geom_line() + ggtitle("ACF: T_air original vs synthetic") + theme_bw()

# Cross-correlation heatmap (original vs synthetic) using Pearson cor across variables
orig_mat <- df %>% dplyr::select(all_of(plot_vars)) %>% drop_na() %>% as.matrix()
synth_mat <- synthetic %>% dplyr::select(all_of(plot_vars)) %>% drop_na() %>% as.matrix()
cor_orig <- cor(orig_mat, use = "pairwise.complete.obs")
cor_synth <- cor(synth_mat, use = "pairwise.complete.obs")

m1 <- melt(cor_orig); names(m1) <- c("Var1","Var2","Corr"); m1$source <- "orig"
m2 <- melt(cor_synth); names(m2) <- c("Var1","Var2","Corr"); m2$source <- "synth"
m_comb <- bind_rows(m1,m2)

ggplot(m_comb, aes(x = Var1, y = Var2, fill = Corr)) +
  geom_tile() + facet_wrap(~source) +
  scale_fill_gradient2(low = "blue", mid = "white", high = "red", limits = c(-1,1)) +
  theme_minimal() + theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  ggtitle("Correlation matrices: original vs synthetic")

# ---------------------------
# 10. Save output
# ---------------------------
# final synthetic tibble is `synthetic`
# attach to workspace and optionally save to disk:
assign("synthetic_time_series", synthetic, envir = .GlobalEnv)
message("Created 'synthetic_time_series' tibble in the global environment.")
# write csv if desired
# write_csv(synthetic, "synthetic_time_series.csv")

# ---------------------------
# Step 11 — Forecast into the future (preserve mean climate)
# ---------------------------
# 1) Configure target horizon
last_obs_time <- max(df$time)           # end of your observed record (e.g., in 2024)
horizon_year <- 2050                   # target final year
# Determine timestep (seconds) from existing data (robust for hourly, sub-hourly, daily)
dt_seconds <- as.numeric(median(diff(sort(df$time)), na.rm = TRUE), units = "secs")
if(is.na(dt_seconds) || dt_seconds <= 0) dt_seconds <- 3600  # fallback to hourly if weird

future_end <- as.POSIXct(paste0(horizon_year, "-12-31 23:59:59"), tz = tz(last_obs_time))
# create future time vector starting at next time step after last observation
future_times <- seq(from = last_obs_time + dt_seconds, to = future_end, by = dt_seconds)
n_future <- length(future_times)
message("Simulating ", n_future, " future timesteps from ", as.character(min(future_times)),
        " to ", as.character(max(future_times)))

# 2) Prepare initial state (last p observations used for fitting)
p <- var_model$p
Y_full <- var_model$y          # matrix used in fit (nobs x k)
# Ensure we have at least p rows
if(nrow(Y_full) < p) stop("VAR fit contains fewer rows than p. Cannot initialize simulation.")
init_y <- Y_full[(nrow(Y_full)-p+1):nrow(Y_full), , drop = FALSE]

# 3) Simulate future anomalies using the same bootstrap function (preserves residual distribution)
# Use the same residuals used for historical simulation (resids object)
future_anom_mat <- simulate_VAR_bootstrap(
  var_model = var_model,
  n_sim     = n_future,
  init_y    = init_y,
  resids    = resids,
  seed      = 999
)

future_anom <- as_tibble(future_anom_mat)
# Column names should be like the VAR endogenous names (e.g., "anom_T_air_t", ...)

# 4) Attach time metadata and seasonal means (doy, hour)
future_df <- future_anom %>%
  mutate(time = future_times) %>%
  mutate(doy = yday(time),
         hour = hour(time))

# join seasonal_means (which has columns like T_air_t_seas, SW_in_t_seas, ..., keyed by doy+hour)
future_df <- future_df %>%
  left_join(seasonal_means, by = c("doy", "hour"))

# Quick check for missing seasonal rows (should be none)
if(any(is.na(future_df[[paste0(vars_t[1], "_seas")]]))) {
  warning("Some seasonal means are missing for future times (check seasonal_means keys).")
}

# 5) Reconstruct transformed-space simulated variables
# For each variable v in vars_t (e.g., "T_air_t"), anom column is "anom_<v>" and seasonal is "<v>_seas"
for (v in vars_t) {
  anom_col <- paste0("anom_", v)
  seas_col <- paste0(v, "_seas")   # e.g., "T_air_t_seas"
  out_col  <- paste0(v, "_sim_t")  # e.g., "T_air_t_sim_t"
  if(!all(c(anom_col, seas_col) %in% names(future_df))) {
    stop("Missing columns when reconstructing: ", anom_col, " or ", seas_col)
  }
  future_df[[out_col]] <- future_df[[anom_col]] + future_df[[seas_col]]
}

# 6) Inverse-transform into physical units (same transforms you used earlier)
future_physical <- future_df %>%
  transmute(
    time = time,
    T_air = !!sym(paste0("T_air_t_sim_t")),          # Kelvin (identity)
    SW_in = !!sym(paste0("SW_in_t_sim_t")),
    LWR_in = !!sym(paste0("LWR_in_t_sim_t")),
    pressure = !!sym(paste0("pressure_t_sim_t")),
    # inverse-logit (rh was percent in original data)
    relative_humidity = plogis(!!sym(paste0("rh_t_sim_t"))) * 100,
    albedo = plogis(!!sym(paste0("albedo_t_sim_t"))),
    wind = pmax(!!sym(paste0("wind_t_sim_t")), 0)^2
  )

# 7) Basic sanity checks
message("Future physical summary (first/last rows & summary):")
print(head(future_physical, 3))
print(tail(future_physical, 3))
print(summary(dplyr::select(future_physical, -time)))

# 8) Save result to global env and optionally to disk
assign("future_physical", future_physical, envir = .GlobalEnv)
# Uncomment to write CSV:
# readr::write_csv(future_physical, "synthetic_future_physical_2060.csv")

message("Saved `future_physical` to global environment. Length: ", nrow(future_physical),
        " rows. Time range: ", min(future_physical$time), " -> ", max(future_physical$time))    
