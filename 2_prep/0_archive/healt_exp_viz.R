library(tidyverse)
library(haven)

library(tidyverse)
library(haven)
library(scales) # For nice percentage formatting

# --- LOAD DATA ---
# (Assuming df_finance is already loaded as per your previous code)

# --- PREPARE DATA ---
# (Same logic, just ensuring clean column names)
plot_data_fin <- df_finance %>%
  group_by(quintile_pcep) %>%
  summarise(
    che_10 = weighted.mean(che_10, w = pop_wt, na.rm = TRUE) * 100,
    distress = weighted.mean(distress_hh, w = pop_wt, na.rm = TRUE) * 100
  ) %>%
  pivot_longer(cols = c(che_10, distress), names_to = "Indicator", values_to = "Percentage") %>%
  # Make "Distress" appear second in the legend/grouping for better logic
  mutate(Indicator = factor(Indicator, levels = c("che_10", "distress")))

# --- PLOT: PUBLICATION QUALITY ---
ggplot(plot_data_fin, aes(x = factor(quintile_pcep), y = Percentage, fill = Indicator)) +
  
  # 1. BARS: Use 'width' to make them slimmer and 'alpha' for a softer look
  geom_bar(stat = "identity", position = position_dodge(width = 0.8), width = 0.7, color = "white", size = 0.2) +
  
  # 2. LABELS: Add value labels on top of bars (so you don't have to guess the number)
  geom_text(aes(label = sprintf("%.1f", Percentage)), 
            position = position_dodge(width = 0.8), 
            vjust = -0.5, size = 3.5, fontface = "bold", color = "#444444") +
  
  # 3. COLORS: Professional "Financial Times" style colors
  # "che_10" (Burnt Red) for the Problem, "distress" (Slate Blue) for the Coping
  scale_fill_manual(values = c("che_10" = "#c0392b", "distress" = "#2980b9"),
                    labels = c("Catastrophic Expenditure (>10%)", "Distress Financing")) +
  
  # 4. SCALES: Remove gap at bottom of bars and format Y-axis
  scale_y_continuous(expand = expansion(mult = c(0, 0.1)), labels = function(x) paste0(x, "%")) +
  
  # 5. TITLES & LABELS
  labs(title = "Financial Burden of Health in Nepal",
       subtitle = "Catastrophic health expenditure is highest among poor, and they are the ones who are \n forced to borrow (Blue)",
       x = "Expenditure Quintile (1 = Poorest, 5 = Richest)",
       y = NULL, # Remove Y label since % signs are on the axis
       fill = NULL) + # Remove Legend Title (it's obvious)
  
  # 6. THEME: The "Clean" Look
  theme_minimal(base_size = 14) + # Increase base font size
  theme(
    plot.title = element_text(face = "bold", size = 16, margin = margin(b = 5)),
    plot.subtitle = element_text(size = 12, color = "#666666", margin = margin(b = 20)),
    
    panel.grid.major.x = element_blank(), # Remove vertical gridlines
    panel.grid.minor = element_blank(),   # Remove minor gridlines
    panel.grid.major.y = element_line(color = "#e5e5e5", linetype = "dashed"), # Light horizontal lines
    
    axis.text.x = element_text(color = "black", margin = margin(t = 5)),
    axis.title.x = element_text(margin = margin(t = 15), face = "bold", size = 11),
    
    legend.position = "top", # Move legend to top
    legend.justification = "left", # Align legend left
    legend.margin = margin(t = 0, b = 0),
    legend.text = element_text(size = 10)
  )
# --- 3. VISUALIZATION 2: DOUBLE BURDEN OF DISEASE (The "X") ---
# We use the Individual Dataset for this

library(tidyverse)
library(haven)
library(scales)

# --- LOAD DATA ---
# (Assuming df_disease is already loaded)

# --- PREPARE DATA ---
plot_data_dis <- df_disease %>%
  group_by(quintile_pcep) %>%
  summarise(
    Chronic = weighted.mean(chronic_illness, w = pop_wt, na.rm = TRUE) * 100,
    Acute = weighted.mean(acute_illness, w = pop_wt, na.rm = TRUE) * 100
  ) %>%
  pivot_longer(cols = c(Chronic, Acute), names_to = "Disease_Type", values_to = "Prevalence")

# --- THE ECONOMIST THEME PLOT (LARGE TEXT VERSION) ---

# 1. Define Economist Colors
eco_bg   <- "#f0f6f7"   # Pale Blue-Grey Background
eco_blue <- "#015c7e"   # Deep Teal/Blue
eco_red  <- "#db444b"   # Economist Red
eco_grid <- "white"     # White Gridlines

ggplot(plot_data_dis, aes(x = quintile_pcep, y = Prevalence, color = Disease_Type)) +
  
  # 2. GRIDLINES (Manual White Lines)
  geom_hline(yintercept = seq(10, 25, by = 5), color = eco_grid, size = 1.2) +
  
  # 3. LINES & POINTS
  geom_line(size = 2.5) + # Thicker lines
  geom_point(size = 5, shape = 21, fill = "white", stroke = 2.5) + # Larger points
  
  # 4. COLORS
  scale_color_manual(values = c("Chronic" = eco_blue, "Acute" = eco_red)) +
  
  # 5. DIRECT LABELING (LARGER TEXT)
  # Increased size from default (~3.5) to 6 (roughly 14pt-16pt font equivalent)
  annotate("text", x = 1.1, y = 13.5, label = "Chronic (NCDs)", color = eco_blue, fontface = "bold", size = 6, hjust = 0) +
  annotate("text", x = 1.1, y = 22.0, label = "Acute (Infections)", color = eco_red, fontface = "bold", size = 6, hjust = 0) +
  
  # 6. SCALES & AXES
  scale_y_continuous(position = "right", limits = c(10, 25)) + 
  scale_x_continuous(breaks = 1:5, labels = c("Poorest", "2", "3", "4", "Richest")) +
  
  # 7. TITLES
  labs(title = "The double burden",
       subtitle = "Prevalence of illness by expenditure quintile, Nepal (%)",
       x = NULL, 
       y = NULL,
       caption = "Source: Nepal Living Standards Survey IV") +
  
  # 8. THEME ADJUSTMENTS (LARGER FONTS)
  theme_minimal(base_family = "sans", base_size = 16) + # Set base size to 16
  theme(
    # Backgrounds
    plot.background = element_rect(fill = eco_bg, color = NA),
    panel.background = element_rect(fill = eco_bg, color = NA),
    
    # Text - Large Title
    plot.title = element_text(face = "bold", size = 22, margin = margin(b = 10), hjust = 0),
    
    # Text - Large Subtitle
    plot.subtitle = element_text(size = 16, margin = margin(b = 25), hjust = 0),
    
    # Text - Caption
    plot.caption = element_text(size = 10, color = "#555555", margin = margin(t = 15), hjust = 0),
    
    # Axes - Large Labels
    axis.text = element_text(size = 14, color = "#333333", face = "bold"),
    axis.text.y = element_text(margin = margin(l = 10)), 
    
    panel.grid = element_blank(), 
    legend.position = "none" 
  )