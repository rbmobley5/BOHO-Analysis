# Load necessary libraries
library(tidyquant) # For data fetching
library(tidyverse) # For data wrangling
library(patchwork) # For layout
library(lubridate) # For date handling
library(TTR)       # Specifically for Technical Analysis functions like SMA

# 1. Data Acquisition
prices <- c("ZL=F", "HO=F") %>%
  tq_get(get = "stock.prices", from = "2018-01-01")

# 2. Data Transformation & Normalization
boho_data <- prices %>%
  select(symbol, date, close) %>%
  pivot_wider(names_from = symbol, values_from = close) %>%
  # Clean names to avoid backtick issues
  rename(soy_oil = `ZL=F`, heating_oil = `HO=F`) %>%
  drop_na(soy_oil, heating_oil) %>% 
  mutate(
    # Normalization: Soy (cents/lb * 7.5 lbs/gal) vs Heating Oil (USD/gal * 100)
    soy_gal_equiv = soy_oil * 7.5,      
    ho_gal_equiv = heating_oil * 100,       
    boho_spread = soy_gal_equiv - ho_gal_equiv,
    # Time variables for analysis
    month = lubridate::month(date, label = TRUE, abbr = TRUE),
    # Moving Averages using TTR package
    spread_ma_50 = TTR::SMA(boho_spread, n = 50),
    spread_ma_200 = TTR::SMA(boho_spread, n = 200)
  )

# 3. ANALYSIS A: Market Regime Visualization
p1 <- ggplot(boho_data, aes(x = date)) +
  geom_line(aes(y = boho_spread, color = "Daily Spread"), alpha = 0.4) +
  geom_line(aes(y = spread_ma_50, color = "50-Day MA"), linewidth = 1) +
  geom_line(aes(y = spread_ma_200, color = "200-Day MA"), linewidth = 1) +
  scale_color_manual(values = c("Daily Spread" = "gray", "50-Day MA" = "blue", "200-Day MA" = "red")) +
  labs(title = "BOHO Spread Technicals", 
       subtitle = "Market regimes and crossover analysis", 
       y = "Cents/Gal",
       color = "Metric") +
  theme_minimal()

# 4. ANALYSIS B: Seasonal Demand Patterns
seasonal_summary <- boho_data %>%
  group_by(month) %>%
  summarise(avg_spread = mean(boho_spread, na.rm = TRUE))

p2 <- ggplot(seasonal_summary, aes(x = month, y = avg_spread)) +
  geom_col(fill = "darkgreen", alpha = 0.7) +
  labs(title = "Average BOHO Spread by Month", 
       subtitle = "Seasonality of biofuel blending profitability", 
       y = "Avg Spread (Cents/Gal)",
       x = "Month") +
  theme_minimal()

# Combine and print
(p1 / p2)

# 5. EXPORT FOR REPORTING
# Create the 'output' directory if it doesn't exist
if(!dir.exists("output")) dir.create("output")

# Save plots as high-resolution PNGs for the markdown report
ggsave("output/boho_technicals.png", plot = p1, width = 10, height = 5, dpi = 300)
ggsave("output/boho_seasonality.png", plot = p2, width = 10, height = 4, dpi = 300)