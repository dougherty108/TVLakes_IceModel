

if (!require('pacman')) install.packages('pacman'); library('pacman')
# remotes::install_github("MilesMcBain/breakerofchains")

# p_update(update = FALSE)  #Tells you which packages are out of date
# p_update()  #actually updates the out of date packages

##Load all the libraries your heart desires
pacman::p_load("lubridate",
               "tidyverse",
               "ggpubr",
               "renv",
               "here",
               "patchwork",
               "ggrepel", 
               "viridis",
               "ggthemes",
               "vroom", 
               "progress")

#Use renv for version control.  Beginner guide here:
# https://rstudio.github.io/renv/articles/renv.html

# if (!require('renv')) install.packages('renv'); library('renv')
# renv::restore()

rename <- dplyr::rename
select <- dplyr::select
summarize <- dplyr::summarize
mutate <- dplyr::mutate