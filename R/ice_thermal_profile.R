##### Ice Thermal Profile data viz #####

# libraries
library(tidyverse)

# load file
profile = read_csv("Data/ice_thermal_profile/ELB_CR1000X_reconfig_25_tempprofile.dat", 
                   skip = 1) |> 
  mutate(TIMESTAMP = ymd_hms(TIMESTAMP)) |> 
  drop_na(TIMESTAMP) |> 
  select(-c(
    `TempData(1)`, `TempData(2)`, `TempData(3)`, `TempData(4)`
    )) |> 
  rename(
    `0` = `TempData(5)`, 
    `50` = `TempData(6)`, 
    `100` = `TempData(7)`, 
    `150` = `TempData(8)`,
    `200` = `TempData(9)`,
    `250` = `TempData(10)`,
    `300` = `TempData(11)`,
    `350` = `TempData(12)`,
    `400` = `TempData(13)`,
    `500` = `TempData(14)`
  )


profile_pivot = profile |> 
  pivot_longer(cols = c(`0`, `50`, `100`, `150`, `200`, 
                        `250`, `300`, `350`, `400`, `500`)) |> 
  select(-c(tempstring)) |> 
  mutate(value = as.numeric(value))


ggplot(profile_pivot, aes(TIMESTAMP, value)) + 
  geom_path(aes(color = name))

####### load the calibration data to correct TempString deployment #######

temp_cal = read_csv("Data/ice_thermal_profile/tempprofile_calibration_final.dat", skip = 1) |> 
  mutate(TIMESTAMP = ymd_hms(TIMESTAMP),
         RECORD = as.numeric(RECORD)) |> 
  select(-c(`TempData(1)`, `TempData(2)`, `TempData(3)`, `TempData(4)`)) |> 
  rename(
    `0` = `TempData(5)`, 
    `50` = `TempData(6)`, 
    `100` = `TempData(7)`, 
    `150` = `TempData(8)`,
    `200` = `TempData(9)`,
    `250` = `TempData(10)`,
    `300` = `TempData(11)`,
    `350` = `TempData(12)`,
    `400` = `TempData(13)`,
    `500` = `TempData(14)`
  ) |> 
  filter(RECORD > 179 & RECORD < 312) |> 
  pivot_longer(cols = matches("^[0-9]+$")) |> 
  mutate(value = as.numeric(value))



temp_grouped = temp_cal |> 
  group_by(name) |> 
  summarize(offset = mean(value, na.rm = TRUE))


######################################################
profile_corrected = profile_pivot |> 
  left_join(temp_grouped, by = "name") |> 
  mutate(value_corrected = value - offset) |> 
  filter(name != "0" & name != "500" &
           name != "400" & name != "350")


ggplot(profile_corrected, aes(TIMESTAMP, value_corrected, color = name)) +
  geom_path() +
  scale_color_brewer(palette = "Spectral") +
  labs(
    title = "Calibrated Ice Thermal Profile",
    x = "Timestamp",
    y = "Temperature (°C)",
    color = "Depth (cm)"
  ) + 
  theme_bw()

#### pull in Air Temp dataset from this past season (BOYM and ELBBB) and compare, what's going on?
ELBBB <- read_delim('Data/ice_thermal_profile/ELB_CR1000X_reconfig_25_ELB15min.dat', 
                    delim = ",", 
                    skip = 1) |> 
  mutate(across(2:24, ~ as.numeric(.)), 
         TIMESTAMP = ymd_hms(TIMESTAMP))

# filter down to just the airtemp and timestamp, and join to the temp_profile object

temp_air_ice = ELBBB |> 
  select(TIMESTAMP, Air_Temp_Avg, Temp_stg_Avg) |> 
  left_join(profile_corrected, by = join_by(TIMESTAMP)) |> 
  drop_na(RECORD)


ggplot(temp_air_ice, aes(TIMESTAMP, value_corrected, color = name)) +
  geom_path() +
  scale_color_brewer(palette = "Spectral") +
  labs(
    title = "Calibrated Ice Thermal Profile",
    x = "Timestamp",
    y = "Temperature (°C)",
    color = "Depth (cm)"
  ) + 
  geom_line(aes(TIMESTAMP, Air_Temp_Avg), color = "RED") + 
  theme_bw()

## directly plot air temperature against ice thermal temp
temp_air_ice |> 
  filter(TIMESTAMP > "2025-06-15 00:00:00") |>
  ggplot(aes(Air_Temp_Avg, value)) + 
  geom_point(shape = 21) + 
  geom_smooth(method = "lm") + 
  facet_wrap(vars(name))

# For portions of ice closer to the atmosphere, air temp is more strongly correlated 
# with ice temperature. But what about the lower sections, nearer the water column?
# plot water temp against ice column temp
temp_air_ice |> 
  filter(TIMESTAMP > "2025-06-15 00:00:00") |>
  ggplot(aes(Temp_stg_Avg, value)) + 
  geom_point(shape = 21) + 
  geom_smooth(method = "lm") + 
  facet_wrap(vars(name))

ggplot(temp_air_ice, aes(TIMESTAMP, Temp_stg_Avg)) + 
  geom_path()
