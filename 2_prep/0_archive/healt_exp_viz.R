library(tidyverse)
library(grid)

# Colors
eco_bg   <- "#f4f7f7"
eco_blue <- "#0b5c7a"
eco_red  <- "#d7303f"
eco_grid <- "#dfe6e9"
eco_text <- "#1f2d3d"


# Load data
data_path <- "C:/Users/Arpan Acharya/OneDrive - HERD/Documents/Personal/CIH-project/1_data/4_tmp/"
df_finance <- read_dta(paste0(data_path, "health_financial_protection_hh.dta"))

# --- PLOT ---

plot_data <- df_finance %>%
  summarise(
    `>10%` = weighted.mean(che_10, w = pop_wt, na.rm = TRUE) * 100,
    `>15%` = weighted.mean(che_15, w = pop_wt, na.rm = TRUE) * 100,
    `>25%` = weighted.mean(che_25, w = pop_wt, na.rm = TRUE) * 100,
    `>40%*` = weighted.mean(che_40, w = pop_wt, na.rm = TRUE) * 100
  ) %>%
  pivot_longer(everything(), names_to = "Threshold", values_to = "Incidence") %>%
  mutate(Threshold = factor(Threshold, levels = c(">10%", ">15%", ">25%", ">40%*")))

p <- ggplot(plot_data, aes(x = Threshold, y = Incidence, fill = Threshold)) +
  
  # Subtle horizontal gridlines
  geom_hline(yintercept = seq(0, 30, by = 5),
             color = eco_grid, size = 0.6) +
  
  # Bars
  geom_col(width = 0.55) +
  
  # Colors
  scale_fill_manual(values = c(
    ">10%"  = eco_blue,
    ">15%"  = eco_blue,
    ">25%"  = eco_blue,
    ">40%*" = eco_red
  )) +
  
  # Labels on top of bars
  geom_text(aes(label = sprintf("%.1f%%", Incidence)),
            vjust = -0.6,
            size = 5.5,
            fontface = "bold",
            color = eco_text) +
  
  # Titles
  labs(
    title = "Incidence of Catastrophic Health Expenditure by Threshold",
    subtitle = "Share of households facing catastrophic health expenditure (%) in Nepal",
    caption = "* spent greater than 40% of their disposable income (money left after buying food) on health.\nSource: Nepal Living Standards Survey IV",
    x = NULL,
    y = NULL
  ) +
  
  # Y scale
  scale_y_continuous(
    limits = c(0, max(plot_data$Incidence) * 1.15),
    expand = c(0, 0),
    position = "right"
  ) +
  
  # Minimal theme base
  theme_minimal(base_size = 16) +
  
  theme(
    # Background
    plot.background  = element_rect(fill = eco_bg, color = NA),
    panel.background = element_rect(fill = eco_bg, color = NA),
    
    # Titles
    plot.title = element_text(
      face = "bold",
      size = 24,
      hjust = 0,
      margin = margin(b = 6)
    ),
    
    plot.subtitle = element_text(
      size = 15,
      hjust = 0,
      margin = margin(b = 20)
    ),
    
    # Axis
    axis.text.x = element_text(
      size = 14,
      face = "bold",
      color = eco_text,
      margin = margin(t = 8)
    ),
    axis.text.y = element_blank(),
    
    # Remove default grid
    panel.grid = element_blank(),
    
    # Remove legend
    legend.position = "none",
    
    # Caption
    plot.caption = element_text(
      size = 11,
      hjust = 0,
      color = "#4d4d4d",
      margin = margin(t = 18)
    ),
    
    # Add breathing space
    plot.margin = margin(20, 30, 20, 20)
  )

# Add Economist-style red tag (cleaner positioning)
p +
  annotation_custom(
    grob = rectGrob(gp = gpar(fill = eco_red, col = NA)),
    xmin = -Inf, xmax = -Inf,
    ymin = Inf, ymax = Inf
  ) +
  coord_cartesian(clip = "off")

ggsave(
  filename = "1graph_economist_style.png",
  plot = p,
  width = 12,
  height = 7,
  dpi = 300,
  bg = eco_bg
)

plot_data <- df_finance %>%
  group_by(quintile_pcep) %>% # Use 'quintile_pcep' if that is your variable name
  summarise(
    avg_share = weighted.mean(health_share_real, w = pop_wt, na.rm = TRUE)
  )
# Calculate Weighted Mean
average_share <- weighted.mean(df_finance$health_share_real, w = df_finance$pop_wt, na.rm = TRUE)

nat_avg <- weighted.mean(df_finance$health_share_real, w = df_finance$pop_wt, na.rm = TRUE)
# Print the result
print(paste("Average Health Share:", round(average_share, 2), "%"))

library(grid)

# Dynamic upper limit for spacing
y_max <- max(plot_data$avg_share)
y_limit <- y_max * 1.25

final_plot2 <- ggplot(plot_data, 
                      aes(x = factor(quintile_pcep), y = avg_share)) +
  
  # Subtle horizontal gridlines
  geom_hline(yintercept = seq(0, ceiling(y_limit), by = 2),
             color = eco_grid, size = 0.6) +
  
  # National average reference line
  geom_hline(yintercept = nat_avg,
             color = eco_red,
             linetype = "longdash",
             size = 1) +
  
  # Bars
  geom_col(fill = eco_blue, width = 0.6) +
  
  # Bar labels
  geom_text(aes(label = sprintf("%.1f%%", avg_share)),
            vjust = -0.6,
            size = 5,
            fontface = "bold",
            color = "#1f2d3d") +
  
  # National average label (clean right-side placement)
  annotate("text",
           x = 5,
           y = nat_avg,
           label = paste0("National average: ", sprintf("%.1f%%", nat_avg)),
           color = eco_red,
           fontface = "bold",
           hjust = 0,
           size = 4.5) +
  
  # Titles
  labs(
    title = "Household Health Spending Share by Income Quintile(%)",
    subtitle = "The figure represents health expenditure as a share of total consumption expenditure (real)",
    caption = "Source: Nepal Living Standards Survey IV",
    x = NULL,
    y = NULL
  ) +
  
  # Scales
  scale_y_continuous(
    limits = c(0, y_limit),
    expand = c(0, 0),
    position = "right"
  ) +
  
  scale_x_discrete(
    labels = c("Poorest", "2", "3", "4", "Richest")
  ) +
  
  coord_cartesian(clip = "off") +
  
  # Theme
  theme_minimal(base_size = 16) +
  theme(
    plot.background  = element_rect(fill = eco_bg, color = NA),
    panel.background = element_rect(fill = eco_bg, color = NA),
    
    plot.title = element_text(
      face = "bold",
      size = 24,
      hjust = 0,
      margin = margin(b = 6)
    ),
    
    plot.subtitle = element_text(
      size = 15,
      hjust = 0,
      margin = margin(b = 20)
    ),
    
    axis.text.x = element_text(
      size = 14,
      face = "bold",
      color = "#1f2d3d",
      margin = margin(t = 8)
    ),
    
    axis.text.y = element_blank(),
    panel.grid = element_blank(),
    
    plot.caption = element_text(
      hjust = 0,
      size = 11,
      color = "#4d4d4d",
      margin = margin(t = 18)
    ),
    
    plot.margin = margin(30, 60, 40, 40)
  )

# Add Economist red tag
final_plot2 +
  annotation_custom(
    grob = rectGrob(gp = gpar(fill = eco_red, col = NA)),
    xmin = -Inf, xmax = -Inf,
    ymin = Inf, ymax = Inf
  )

ggsave(
  "2graphhealth_budget_quintile_economist.png",
  width = 12,
  height = 7,
  dpi = 300,
  bg = eco_bg
)












library(tidyverse)
library(grid)

# --- 1. MANUAL DATA ENTRY ---
plot_data <- tibble(
  Metric = c("Greater than 10%\n(Total Budget)", 
             "Greater than 15%\n(Total Budget)", 
             "Greater than 25%\n(Total Budget)", 
             "Greater than 40%\n(Non-Food Budget)*"),
  Poor = c(11.5, 7.8, 5.1, 7.3),
  `Non-Poor` = c(8.2, 5.1, 2.5, 3.9)
) %>%
  pivot_longer(cols = c(Poor, `Non-Poor`), names_to = "Status", values_to = "Incidence") %>%
  # Set Order: "Non-Food" at the top
  mutate(Metric = factor(Metric, levels = c("Greater than 40%\n(Non-Food Budget)*", 
                                            "Greater than 25%\n(Total Budget)", 
                                            "Greater than 15%\n(Total Budget)", 
                                            "Greater than 10%\n(Total Budget)")))

# --- 2. ECONOMIST STYLE PLOT ---

# Define Colors
eco_bg   <- "#f0f6f7"
eco_blue <- "#015c7e" # Non-Poor
eco_red  <- "#db444b" # Poor

p <- ggplot(plot_data, aes(x = Incidence, y = Metric)) +
  
  # A. Vertical Gridlines
  geom_vline(xintercept = seq(0, 14, by = 2), color = "white", size = 1) +
  
  # B. The Connector Line
  geom_line(aes(group = Metric), color = "#7f8c8d", size = 3) +
  
  # C. The Points
  geom_point(aes(color = Status), size = 9) +
  
  # D. Value Labels (Below the dots)
  geom_text(aes(label = sprintf("%.1f", Incidence), color = Status), 
            vjust = 2.5, # Pushes text DOWN below the dot
            size = 5, 
            fontface = "bold", 
            show.legend = FALSE) +
  
  # E. Colors
  scale_color_manual(values = c("Non-Poor" = eco_blue, "Poor" = eco_red)) +
  
  # F. Titles & Captions
  labs(
    title = "Catastrophic health expenditure incidence",
    subtitle = "Poor vs. Non-Poor (%)",
    caption = "*Refers to Capacity to Pay metric (Standard is >40% of non-food consumption).\nSource: Nepal Living Standards Survey IV",
    x = NULL, y = NULL
  ) +
  
  # G. Scales
  scale_x_continuous(limits = c(0, 15), breaks = seq(0, 14, by = 2), position = "top") +
  
  # H. Theme Formatting
  theme_minimal(base_family = "sans", base_size = 14) +
  theme(
    plot.background = element_rect(fill = eco_bg, color = NA),
    panel.background = element_rect(fill = eco_bg, color = NA),
    
    plot.title = element_text(face = "bold", size = 24, margin = margin(b = 10), hjust = 0),
    plot.subtitle = element_text(size = 16, margin = margin(b = 25), color = "#4d4d4d", hjust = 0),
    
    axis.text.y = element_text(face = "bold", size = 12, color = "#2c3e50", margin = margin(r = 15)),
    axis.text.x = element_text(size = 12, color = "#555555"),
    
    panel.grid = element_blank(),
    
    # --- LEGEND SETTINGS (MOVED TO BOTTOM) ---
    legend.position = "bottom",
    legend.justification = "center",
    legend.direction = "horizontal",
    legend.title = element_blank(),
    legend.text = element_text(size = 12, face = "bold", margin = margin(r = 20)), # Spacing between items
    legend.box.margin = margin(t = 20, b = 10), # Space above/below legend
    
    plot.margin = margin(t = 40, r = 20, b = 20, l = 20),
    plot.caption = element_text(hjust = 0, size = 10, color = "#555555", margin = margin(t = 10))
  ) +
  coord_cartesian(clip = "off")

# --- 3. DRAW PLOT WITH RED TAG ---
grid.newpage()
print(p)

# The Signature Red Rectangle (Top Left Corner)
grid.draw(rectGrob(gp = gpar(fill = eco_red, col = NA), 
                   x = unit(0.02, "npc"), y = unit(0.95, "npc"), 
                   width = unit(0.04, "npc"), height = unit(0.025, "npc"), 
                   just = c("left", "top")))

ggsave(
  "3graphhealth_budget_quintile_economist.png",
  width = 12,
  height = 7,
  dpi = 300,
  bg = eco_bg
)


