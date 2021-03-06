# Script for filtering and plotting survey data for flow preference analysis

# Keith Jennings
# kjennings@lynkertech.com
# 2020-06-19

# Load packages
library(tidyverse)
library(here)
library(cowplot); theme_set(theme_cowplot())

# Import data
# Note .RData files are in gitignore, so these must be on your local machine
load(file = here("flow_pref", "survey-analysis", "respondend-attributes.Rdata"))
load(file = here("flow_pref", "survey-analysis", "flow-pref-data.Rdata"))

# Convert flow to numeric
flowpref.dat <- flowpref.dat %>% 
  mutate(flow = as.numeric(flow))

# Assign all users an experience code
respondent.attributes <- respondent.attributes %>% 
  mutate(skill = case_when(skill.novice == T ~ "novice",
                           skill.intermediate == T ~ "intermed",
                           skill.advanced == T ~ "advanced",
                           skill.expert == T ~ "expert"))

# Next a list of unqualified respondent IDs based on:
# 1) skill level (remove novice)
# 2) trip frequency (remove 1 trip per season)
# 3) reporting confidence (remove Not comfortable at all)

# Create thresholds for each category
skill_thresh = "novice"
trip_thresh = "1 time a season"
confidence_thresh = "Not comfortable at all"

# Filter to respondent IDs above the thresholds
respondent.id.valid = respondent.attributes %>% 
  filter(., skill != skill_thresh,
         trip.frequency != trip_thresh,
         reporting.confidence != confidence_thresh) %>% 
  pull(., respondent.id)

# Make a vector of segment names
segments <- unique(flowpref.dat$segment.name)

# Loop through each segment
# calculate flow preference
# and plot the data
for(i in 1:length(segments)){
  segment_name = segments[i]
  segment_name2 = str_replace_all(segment_name, pattern = " ", replacement = "")
  results <- flowpref.dat %>%
    
    # Remove NAs and select a specific segment
    filter(!is.na(preference.code) & 
             segment.name == segment_name &
             respondent.id %in% respondent.id.valid) %>%
    
    # calculate the average pref score and PCI2 statistic of each flow bin
    group_by(flow) %>%
    summarize(pref.average = mean(preference.code),   # average preference
              d = sum(abs(dist(preference.code))),    # sum of the score distance vector
              m = sum(abs(dist(rep(c(-3,3),n())))),   # maximum possible sum of distance vector
              pci2 = d/m,                             # PCI2 = d/m
              n_obs = length(flow))                   # count # of observations
  
  
  # Plot
  flow_pref_plot <- 
    ggplot() +
    geom_jitter(data = filter(flowpref.dat, segment.name == segment_name), 
                aes(x = as.numeric(flow), 
                    y = preference.code), 
                size = 1, alpha = 0.3) +
    geom_point(data = filter(results, n_obs > 2), 
               aes(x = flow, y = pref.average, size = pci2), 
               color = 'blue') +
    geom_hline(yintercept = 0)
  
  # Add axis labels and titles
  # Some reaches have stage values, others have flow
  # So use if-else to assign correct label
  if(max(results$flow, na.rm = T) < 100){
    flow_pref_plot <- flow_pref_plot +
      labs(x = "Stage (ft.)",
           y = "Preference Score",
           title = paste0(segment_name, " Stage Preference Curve"))
  }else{
    flow_pref_plot <- flow_pref_plot +
      labs(x = "Flow (cfs)",
           y = "Preference Score",
           title = paste0(segment_name, " Flow Preference Curve"))  
    }

  # Export plot
  save_plot(filename = paste0("plots/flow_pref/flow_pref_",
                              segment_name2,
                              ".png"),
            plot = flow_pref_plot,
            base_width = 7)
  
}