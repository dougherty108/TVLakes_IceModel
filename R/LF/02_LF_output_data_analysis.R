
### pivot results dataframe for plotting of all the fluxes through time
result_flux = results |> 
  pivot_longer(cols = c(temperature, thickness, LW_net, SW, SW_abs, sensible_Q, latent_Q, 
                        conductive_Q, surface_heat_flux), 
               names_to = "flux", 
               values_to = "value")

ggplot(result_flux, aes(time, value, color = flux)) + 
  geom_path() + 
  facet_wrap(~flux, scales = "free") + 
  theme_linedraw()

## 
results_year_max = results |> 
  mutate(year = year(time), 
         date = as.Date(time)) |> 
  group_by(year) |> 
  slice_max(order_by = thickness, n = 1) |> 
  select(year, date) |> 
  ungroup()

results_year_min = results |> 
  mutate(year = year(time), 
         date = as.Date(time)) |> 
  group_by(year) |> 
  slice_min(order_by = thickness, n = 1) |> 
  select(year, date) |> 
  ungroup() |> print()

#troubleshooting plots, to find distance of change at top and bottom
plot(dL_bottom.vec)
plot(dL_surface.vec)

####### Comparing outputs ##########
#setwd("/Users/charliedougherty/Documents/R-Repositories/MCM-LTER-MS")

# load file
GEE_corrected <- results |> 
  group_by(time) |> 
  summarize(thickness = max(thickness)) |> 
  mutate(time = ymd_hms(time)) |> 
  filter(thickness > 0)

summary(GEE_corrected$thickness)
# ice thickness data
ice_thick <- read_csv("Data/mcmlter-lake-ice_thickness-20250218_0_2025.csv") |>
  mutate(date_time = mdy_hm(date_time), 
         z_water_m = z_water_m*-1) |> 
  filter(location_name == "Lake Fryxell", 
  ) |> 
  filter(str_detect(string = location, pattern = "Outside")) |> 
  filter(date_time > "2016-12-01" & date_time < "2024-02-01") |> 
  group_by(date_time) |> 
  summarize(mean_thickness = mean(z_water_m, na.rm = T))

summary(ice_thick$mean_thickness)

# plot modeled ice thickness against the measured thickness
ggplot() + 
  geom_line(data = GEE_corrected, aes(x = time, y = thickness), linewidth = 1.25) + 
  geom_point(data = ice_thick, aes(x = date_time, y = mean_thickness), color = "red") +
  xlab("Time") + ylab("Ice Thickness (m)") + 
  ggtitle("East Lake Bonney Ice Thickness", 
          subtitle = "modeled vs. measured") +
  theme_linedraw(base_size = 20)

#ggsave("plots/manuscript/chapter 2/measured_vs_modeled.png", 
#       dpi = 300, height = 8, width = 12)

modeled_daily <- GEE_corrected |> 
  mutate(time = ymd_hms(time), 
         date_time = date(time)) |> 
  group_by(date_time) |> 
  summarize(modeled_thickness = mean(thickness)) 


### join two datasets together to compare dates
comp <- ice_thick |> 
  left_join(modeled_daily, by = join_by(date_time)) |> 
  group_by(date_time) |> 
  mutate(difference = modeled_thickness - mean_thickness)

# different summary breakdowns
summary(comp$mean_thickness)
summary(comp$modeled_thickness)
summary(comp$difference)

#plot modeled and measured against each other
ggplot(comp, aes(mean_thickness, modeled_thickness)) + 
  geom_point(size = 2.5, shape = 1) + 
  geom_abline(size = 1.5) + 
  xlab("Measured Ice Thickness") + ylab("Modeled Ice Thickness") + 
  theme_linedraw(base_size = 20)

linear_model = lm(modeled_thickness ~mean_thickness, data = comp)

summary(linear_model)

thickness_pivot <- comp |> 
  pivot_longer(cols = c(modeled_thickness, mean_thickness), 
               names_to = "measurement_type", values_to = "thickness") |> 
  select(date_time, measurement_type, thickness)