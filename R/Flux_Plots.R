# ============================================================
# Flux_Plots.R - surface energy-balance plots from the saved model outputs
#
#   A. Time series of each surface flux, one figure per lake
#   B. Fluxes leading up to ice-off (GL4, The Loch) and through the warmest
#      part of the year (Dec-Feb) for the perennially frozen Dry Valley lakes,
#      plus a mean energy-budget comparison across all lakes
#
# Reads  Data/model_outputs/<LAKE>_<years>_output.csv (hourly run_ice_model output)
# Writes figures/Flux_Plots/*.png (landscape 16:9)
# Sign convention: positive = energy into the ice surface. Conduction is shown
# as -Qc so it reads the same way (positive = heat reaching the surface from below).
# Run from the project root:  source("R/Flux_Plots.R")
# ============================================================

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(ggplot2); library(readr); library(lubridate)
})

in_dir  <- if (exists("flux_in_dir"))  flux_in_dir  else "Data/model_outputs"
out_dir <- if (exists("flux_out_dir")) flux_out_dir else "figures/Flux_Plots"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

LAKES <- c(ELB = "East Lobe Bonney", WLB = "West Lobe Bonney", LH = "Lake Hoare",
           LF = "Lake Fryxell", GL4 = "Green Lake 4", LOC = "The Loch")
SEASONAL  <- c("GL4", "LOC")
PERENNIAL <- c("ELB", "WLB", "LH", "LF")

# flux order + colours (fixed categorical order; net in ink)
FLUX_LAB <- c(SW_abs = "Shortwave absorbed (SW_abs)", LW_net = "Net longwave (LW_net)",
              Qh = "Sensible (Qh)", Ql = "Latent (Ql)", negQc = "Conduction (-Qc)",
              net = "Net surface flux")
FLUX_COL <- c(SW_abs = "#2a78d6", LW_net = "#eb6834", Qh = "#1baf7a",
              Ql = "#eda100", negQc = "#e87ba4", net = "#2b2b2b")
INK <- "#2b2b2b"; MUTED <- "#77756e"; GRID <- "#e6e4dd"

theme_flux <- function(base = 13) {
  theme_minimal(base_size = base) +
    theme(panel.grid.minor = element_blank(),
          panel.grid.major = element_line(colour = GRID, linewidth = 0.3),
          axis.text = element_text(colour = MUTED), axis.title = element_text(colour = INK),
          strip.text = element_text(colour = INK, face = "bold", hjust = 0),
          plot.title = element_text(colour = INK, face = "bold"),
          plot.subtitle = element_text(colour = MUTED),
          plot.caption = element_text(colour = MUTED, hjust = 0),
          legend.position = "top", legend.title = element_blank(),
          plot.background = element_rect(fill = "white", colour = NA))
}
save_fig <- function(p, name, w = 13.33, h = 7.5)
  ggsave(file.path(out_dir, name), p, width = w, height = h, dpi = 200, bg = "white")

# ---- load + daily aggregation ---------------------------------------------------
read_lake <- function(lake) {
  f <- list.files(in_dir, pattern = paste0("^", lake, "_\\d{4}_\\d{4}_output\\.csv$"), full.names = TRUE)
  if (!length(f)) return(NULL)
  d <- readr::read_csv(f[1], show_col_types = FALSE, progress = FALSE,
         col_select = dplyr::any_of(c("time", "thickness", "LW_net", "SW_abs", "sensible_Q",
                                      "latent_Q", "conductive_Q", "surface_heat_flux",
                                      "surface_loss", "bottom_gain", "phase")))
  if (!"phase" %in% names(d)) d$phase <- "ice"
  d |>
    mutate(day = as.Date(time)) |>
    group_by(day) |>
    summarise(SW_abs = mean(SW_abs, na.rm = TRUE), LW_net = mean(LW_net, na.rm = TRUE),
              Qh = mean(sensible_Q, na.rm = TRUE), Ql = mean(latent_Q, na.rm = TRUE),
              negQc = -mean(conductive_Q, na.rm = TRUE),
              net = mean(surface_heat_flux, na.rm = TRUE),
              thickness = mean(thickness, na.rm = TRUE),
              ice_frac = mean(phase == "ice", na.rm = TRUE), .groups = "drop") |>
    mutate(lake = lake)
}
daily <- bind_rows(lapply(names(LAKES), read_lake))
lakes_present <- intersect(names(LAKES), unique(daily$lake))

long_flux <- function(d) d |>
  pivot_longer(all_of(names(FLUX_LAB)), names_to = "flux", values_to = "W") |>
  mutate(flux = factor(flux, names(FLUX_LAB), FLUX_LAB))
col_map <- setNames(FLUX_COL, FLUX_LAB)

roll7 <- function(x) as.numeric(stats::filter(x, rep(1 / 7, 7), sides = 2))

# ---- ice-off dates (seasonal lakes): first day of ≥3 open-water days, Apr-Sep --------
ice_off_dates <- function(d) {
  d <- arrange(d, day)
  open <- d$ice_frac < 0.5
  r <- rle(open); ends <- cumsum(r$lengths); starts <- ends - r$lengths + 1
  st <- d$day[starts[r$values & r$lengths >= 3]]
  st <- st[month(st) %in% 4:9 & st > min(d$day)]
  tibble(year = year(st), ice_off = st) |> group_by(year) |> slice_min(ice_off, n = 1) |> ungroup()
}

# =================================================================================
# A. Time series panels - one figure per lake
# =================================================================================
for (lk in lakes_present) {
  d <- filter(daily, lake == lk) |> arrange(day) |>
    mutate(across(all_of(names(FLUX_LAB)), roll7))
  dl <- long_flux(d)
  open_spans <- NULL
  if (lk %in% SEASONAL) {
    od <- filter(daily, lake == lk) |> arrange(day) |> mutate(open = ice_frac < 0.5,
            grp = cumsum(open != lag(open, default = first(open))))
    open_spans <- od |> filter(open) |> group_by(grp) |>
      summarise(start = min(day), end = max(day), .groups = "drop")
  }
  p <- ggplot(dl, aes(day, W, colour = flux)) +
    { if (!is.null(open_spans) && nrow(open_spans))
        geom_rect(data = open_spans, inherit.aes = FALSE,
                  aes(xmin = start, xmax = end, ymin = -Inf, ymax = Inf),
                  fill = "#9ec5f4", alpha = 0.25) } +
    geom_hline(yintercept = 0, colour = MUTED, linewidth = 0.4) +
    geom_line(linewidth = 0.5) +
    facet_wrap(~ flux, ncol = 2, scales = "free_y") +
    scale_colour_manual(values = col_map, guide = "none") +
    scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
    labs(title = sprintf("%s - surface energy fluxes", LAKES[[lk]]),
         subtitle = paste0("7-day running mean of daily means (W m-2). Positive = energy into the ice surface",
                           if (lk %in% SEASONAL) "; shaded = open water" else ""),
         x = NULL, y = expression(W~m^-2)) +
    theme_flux(12)
  save_fig(p, sprintf("A_%s_flux_timeseries.png", lk))
}

# A (overview): net flux + ice thickness for all lakes on one page
ov <- daily |> group_by(lake) |> arrange(day) |> mutate(net7 = roll7(net)) |> ungroup() |>
  mutate(lake = factor(LAKES[lake], LAKES))
p <- ggplot(ov, aes(day, net7)) +
  geom_hline(yintercept = 0, colour = MUTED, linewidth = 0.4) +
  geom_line(colour = INK, linewidth = 0.45) +
  facet_wrap(~ lake, ncol = 2, scales = "free_x") +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  labs(title = "Net surface energy flux, all lakes",
       subtitle = "7-day running mean (W m-2). Above zero = the surface is gaining energy (melting at 0 °C)",
       x = NULL, y = expression(W~m^-2)) + theme_flux(12)
save_fig(p, "A_all_lakes_net_flux.png")

# =================================================================================
# B1. Seasonal lakes - the 60 days before each ice-off
# =================================================================================
pre_off <- bind_rows(lapply(intersect(SEASONAL, lakes_present), function(lk) {
  d <- filter(daily, lake == lk)
  offs <- ice_off_dates(d)
  bind_rows(lapply(seq_len(nrow(offs)), function(i)
    d |> filter(day >= offs$ice_off[i] - 60, day < offs$ice_off[i]) |>
      mutate(rel = as.numeric(day - offs$ice_off[i]), season = offs$year[i])))
}))

if (nrow(pre_off)) {
  pm <- pre_off |> long_flux() |> group_by(lake, flux, rel) |>
    summarise(mean = mean(W, na.rm = TRUE), lo = quantile(W, 0.25, na.rm = TRUE),
              hi = quantile(W, 0.75, na.rm = TRUE), n = n_distinct(season), .groups = "drop") |>
    group_by(lake, flux) |> arrange(rel) |>
    mutate(across(c(mean, lo, hi), roll7)) |> ungroup() |>
    mutate(lake = factor(LAKES[lake], LAKES))
  nyrs <- pre_off |> group_by(lake) |> summarise(n = n_distinct(season))
  p <- ggplot(pm, aes(rel, mean, colour = flux, fill = flux)) +
    geom_hline(yintercept = 0, colour = MUTED, linewidth = 0.4) +
    geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.15, colour = NA) +
    geom_line(aes(linewidth = flux == FLUX_LAB[["net"]])) +
    geom_vline(xintercept = 0, colour = INK, linetype = "22", linewidth = 0.4) +
    facet_wrap(~ lake, ncol = 2) +
    scale_colour_manual(values = col_map) + scale_fill_manual(values = col_map) +
    scale_linewidth_manual(values = c(`FALSE` = 0.7, `TRUE` = 1.2), guide = "none") +
    labs(title = "Energy fluxes in the 60 days before ice-off",
         subtitle = sprintf("Mean across years (line) and interquartile range (band), 7-day smoothed. Day 0 = ice-off. %s",
                            paste(sprintf("%s: %d years", LAKES[nyrs$lake], nyrs$n), collapse = "; ")),
         x = "Days relative to ice-off", y = expression(W~m^-2)) +
    guides(colour = guide_legend(nrow = 1), fill = guide_legend(nrow = 1)) + theme_flux(12)
  save_fig(p, "B1_seasonal_pre_ice_off.png")

  # per-year net flux and thickness leading to ice-off
  py <- pre_off |> mutate(lake = factor(LAKES[lake], LAKES), season = factor(season))
  p <- ggplot(py, aes(rel, thickness, group = season)) +
    geom_line(colour = "#2a78d6", alpha = 0.6, linewidth = 0.5) +
    stat_summary(aes(group = 1), fun = mean, geom = "line", colour = INK, linewidth = 1.1) +
    facet_wrap(~ lake, ncol = 2) +
    labs(title = "Ice thickness in the 60 days before ice-off",
         subtitle = "Each year (thin blue) and the mean (black)", x = "Days relative to ice-off",
         y = "Ice thickness (m)") + theme_flux(12)
  save_fig(p, "B1_seasonal_pre_ice_off_thickness.png")
}

# =================================================================================
# B2. Perennial lakes - the warmest part of the year (1 Dec - 28 Feb)
# =================================================================================
summer <- daily |> filter(lake %in% PERENNIAL, month(day) %in% c(12, 1, 2)) |>
  mutate(season = ifelse(month(day) == 12, year(day) + 1, year(day)),
         rel = as.numeric(day - as.Date(paste0(season, "-01-01"))))
if (nrow(summer)) {
  sm <- summer |> long_flux() |> group_by(lake, flux, rel) |>
    summarise(mean = mean(W, na.rm = TRUE), lo = quantile(W, 0.25, na.rm = TRUE),
              hi = quantile(W, 0.75, na.rm = TRUE), .groups = "drop") |>
    group_by(lake, flux) |> arrange(rel) |> mutate(across(c(mean, lo, hi), roll7)) |> ungroup() |>
    mutate(lake = factor(LAKES[lake], LAKES))
  p <- ggplot(sm, aes(rel, mean, colour = flux, fill = flux)) +
    geom_hline(yintercept = 0, colour = MUTED, linewidth = 0.4) +
    geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.15, colour = NA) +
    geom_line(aes(linewidth = flux == FLUX_LAB[["net"]])) +
    facet_wrap(~ lake, ncol = 2) +
    scale_x_continuous(breaks = c(-31, 0, 31, 59), labels = c("1 Dec", "1 Jan", "1 Feb", "1 Mar")) +
    scale_colour_manual(values = col_map) + scale_fill_manual(values = col_map) +
    scale_linewidth_manual(values = c(`FALSE` = 0.7, `TRUE` = 1.2), guide = "none") +
    labs(title = "Energy fluxes through the austral summer (Dry Valley lakes)",
         subtitle = "Mean across summers (line) and interquartile range (band), 7-day smoothed",
         x = NULL, y = expression(W~m^-2)) +
    guides(colour = guide_legend(nrow = 1), fill = guide_legend(nrow = 1)) + theme_flux(12)
  save_fig(p, "B2_perennial_summer.png")
}

# =================================================================================
# B3. Mean energy budget in those windows, all lakes side by side
# =================================================================================
win <- bind_rows(
  if (nrow(pre_off)) pre_off |> filter(rel >= -30) |> mutate(window = "Last 30 days before ice-off"),
  if (nrow(summer))  summer  |> mutate(window = "1 Dec - 28 Feb"))
if (nrow(win)) {
  bud <- win |> long_flux() |> group_by(lake, window, flux) |>
    summarise(W = mean(W, na.rm = TRUE), .groups = "drop") |>
    mutate(lake = factor(LAKES[lake], LAKES),
           lab = sprintf("%s\n(%s)", lake, window))
  bud$lab <- factor(bud$lab, unique(bud$lab[order(bud$lake)]))
  p <- ggplot(bud, aes(flux, W, fill = flux)) +
    geom_hline(yintercept = 0, colour = MUTED, linewidth = 0.4) +
    geom_col(width = 0.75, colour = "white", linewidth = 0.5) +
    geom_text(aes(label = round(W), vjust = ifelse(W >= 0, -0.4, 1.3)), colour = INK, size = 3) +
    facet_wrap(~ lab, nrow = 2) +
    scale_fill_manual(values = col_map) +
    scale_y_continuous(expand = expansion(mult = 0.15)) +
    labs(title = "Mean surface energy budget in the melt window",
         subtitle = "Seasonal lakes: last 30 days before ice-off. Dry Valley lakes: 1 Dec - 28 Feb. Positive = into the ice surface",
         x = NULL, y = expression(W~m^-2)) +
    guides(fill = guide_legend(nrow = 1)) + theme_flux(11) +
    theme(axis.text.x = element_blank(), panel.grid.major.x = element_blank())
  save_fig(p, "B3_melt_window_budget.png")
  readr::write_csv(select(bud, lake, window, flux, W), file.path(out_dir, "B3_melt_window_budget.csv"))
}

message("Flux figures written to ", normalizePath(out_dir))

