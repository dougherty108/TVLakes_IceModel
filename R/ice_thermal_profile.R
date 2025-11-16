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



