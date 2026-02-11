library(tidyverse)
library(grid)

# --- 1. DATA PREPARATION ---
# We manually define the order so "Poorest" appears at the top
plot_data <- data.frame(
  Quintile = factor(c("Poorest", "2", "3", "4", "Richest"), 
                    levels = c("Richest", "4", "3", "2", "Poorest")), # Reverse order for ggplot Y-axis
  Distress = c(15.5, 11.5, 9.1, 6.8, 5.5)
)

national_avg <- 9.7

# --- 2. ECONOMIST PLOT DEFINITION ---

# Colors
eco_bg   <- "#f0f6f7"
eco_blue <- "#015c7e"
eco_red  <- "#db444b"

p <- ggplot(plot_data, aes(x = Distress, y = Quintile)) +
  
  # A. Vertical Gridlines (White)
  geom_vline(xintercept = seq(0, 16, by = 2), color = "white", size = 1) +
  
  # B. National Average Line (Red Dashed)
  geom_vline(xintercept = national_avg, color = eco_red, linetype = "dashed", size = 1) +
  
  # C. The Bars
  geom_col(fill = eco_blue, width = 0.65) +
  
  # D. Value Labels (Right of the bars)
  geom_text(aes(label = sprintf("%.1f", Distress)), 
            hjust = -0.3, # Push slightly right
            size = 5, 
            fontface = "bold", 
            color = "#2c3e50") +
  
  # E. National Average Label
  annotate("text", x = national_avg + 0.2, y = 1, 
           label = paste0("National Avg: ", national_avg, "%"), 
           color = eco_red, hjust = 0, vjust = -1, fontface = "bold.italic", size = 4.5) +
  
  # F. Titles & Labels
  labs(
    title = "Running on empty",
    subtitle = "Share of households utilizing distress financing by income quintile (%)",
    caption = "Source: Nepal Living Standards Survey IV",
    x = NULL, y = NULL
  ) +
  
  # G. Scales
  scale_x_continuous(limits = c(0, 17), expand = c(0, 0), breaks = seq(0, 16, by = 4)) +
  
  # H. Theme
  theme_minimal(base_family = "sans", base_size = 14) +
  theme(
    plot.background = element_rect(fill = eco_bg, color = NA),
    panel.background = element_rect(fill = eco_bg, color = NA),
    
    plot.title = element_text(face = "bold", size = 22, margin = margin(b = 10), hjust = 0),
    plot.subtitle = element_text(size = 16, margin = margin(b = 25), color = "#4d4d4d", hjust = 0),
    
    axis.text.y = element_text(face = "bold", size = 13, color = "#2c3e50", margin = margin(r = 10)),
    axis.text.x = element_blank(), # Hide X axis numbers (labels are on bars)
    
    panel.grid = element_blank(), # We drew our own vertical lines
    
    plot.margin = margin(t = 40, r = 20, b = 20, l = 20),
    plot.caption = element_text(hjust = 0, size = 10, color = "#555555", margin = margin(t = 20))
  ) +
  coord_cartesian(clip = "off")

# --- 3. DRAW PLOT WITH RED TAG ---
grid.newpage()
print(p)

# The Signature Red Rectangle
grid.draw(rectGrob(gp = gpar(fill = eco_red, col = NA), 
                   x = unit(0.02, "npc"), y = unit(0.95, "npc"), 
                   width = unit(0.04, "npc"), height = unit(0.025, "npc"), 
                   just = c("left", "top")))

ggsave(
  "4graphhealth_budget_quintile_economist.png",
  width = 12,
  height = 7,
  dpi = 300,
  bg = eco_bg
)
