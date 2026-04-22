# 1. DEPENDENCIES CHECK & LOADING
required_packages <- c("terra", "rayshader", "ggplot2", "tidyterra", "metR", "colorspace", "ggspatial")
missing_packages <- required_packages[!(required_packages %in% installed.packages()[, "Package"])]

if (length(missing_packages) > 0) {
  message("Installing missing packages: ", paste(missing_packages, collapse = ", "))
  install.packages(missing_packages)
}

library(terra)
library(rayshader)
library(ggplot2)
library(tidyterra)
library(metR)
library(colorspace)
library(ggspatial)

# 2. DATA LOADING & PREPROCESSING
dem_path <- "dem_rod.tif"
if (!file.exists(dem_path)) {
  stop("DEM file not found: ", dem_path)
}

message("Loading DEM...")
r <- rast(dem_path)

# Handle potential outliers or NoData (rayshader needs a matrix)
el_mat <- raster_to_matrix(r)

# 3. HILLSHADE GENERATION
message("Calculating hillshades (this may take a moment)...")

# Calculate zscale: if units are lat/lon, elevation needs to be scaled
is_latlon <- is.lonlat(r)
if (is_latlon) {
  # Average meters per degree at this latitude
  mean_lat <- mean(ext(r)[3:4])
  # Correct zscale: how many Z-units (meters) are in one X/Y-unit (degree)
  zscale <- 111132 * cos(mean_lat * pi / 180)
  # "Push down" factor: increase zscale to compress elevation further
  zscale <- zscale * 1.5 
  message("Geographic CRS detected. Using corrected zscale: ", round(zscale, 2))
} else {
  # For projected maps, zscale = 1 is natural, 1.5 pushes it down
  zscale <- 1.5
}

# Advanced components
ambmat <- ambient_shade(el_mat, zscale = zscale, multicore = TRUE)
raymat <- ray_shade(el_mat, zscale = zscale, sunangle = 315, sunaltitude = 45, lambert = TRUE, multicore = TRUE)
texmat <- texture_shade(el_mat, detail = 8/10, contrast = 3) # Extra ridge detail

# Combine for a beautiful texture
message("Rendering texture...")

# Define a professional terrain palette for the map itself
terrain_pal <- c("#336633", "#669966", "#99CC99", "#CCCC99", "#CC9966", "#996633", "#663300")

map_texture <- el_mat %>%
  # Use height_shade to make the map colors match the elevation data
  height_shade(texture = grDevices::colorRampPalette(terrain_pal)(256)) %>%
  add_shadow(texmat, 0.3) %>%
  add_shadow(raymat, 0.6) %>%
  add_shadow(ambmat, 0.6)

# 4. DATA ANALYSIS (PEAKS & CONTOURS)
message("Analyzing terrain...")

# Smooth a copy of the DEM for better-looking (non-jagged) contours
r_smooth <- focal(r, w = matrix(1/25, 5, 5), fun = "mean")

# Find the highest peak
max_el <- max(el_mat, na.rm = TRUE)
max_pos <- which(el_mat == max_el, arr.ind = TRUE)[1,]
# Convert matrix coordinates to spatial coordinates
peak_x <- xFromCol(r, max_pos[2])
peak_y <- yFromRow(r, max_pos[1])
peak_df <- data.frame(x = peak_x, y = peak_y, el = max_el)

# Determine contour intervals
elev_range <- range(el_mat, na.rm = TRUE)
# Major contours every 200m, minor every 50m for a professional look
major_interval <- 200
minor_interval <- 50
index_breaks <- seq(floor(elev_range[1]/major_interval)*major_interval,
                    ceiling(elev_range[2]/major_interval)*major_interval,
                    by = major_interval)
minor_breaks <- seq(floor(elev_range[1]/minor_interval)*minor_interval,
                    ceiling(elev_range[2]/minor_interval)*minor_interval,
                    by = minor_interval)

# 5. FINAL COMPOSITION (GGPLOT2) ----
message("Finalizing layout...")

img_raster <- rast(map_texture * 255)
ext(img_raster) <- ext(r)
crs(img_raster) <- crs(r)

# Plotting
p <- ggplot() +
  # Background Hillshade
  geom_spatraster_rgb(data = img_raster) +

  # Contours (using the smoothed DEM for elegant lines)
  geom_contour(data = as.data.frame(r_smooth, xy = TRUE),
               aes(x = x, y = y, z = .data[[names(r_smooth)[1]]]),
               breaks = minor_breaks,
               color = "white", alpha = 0.15, linewidth = 0.1) +

  # Index Contours (No Labels)
  geom_contour(data = as.data.frame(r_smooth, xy = TRUE),
               aes(x = x, y = y, z = .data[[names(r_smooth)[1]]]),
               breaks = index_breaks,
               color = "white", alpha = 0.4, linewidth = 0.5) +

  # Peak Marker (Symbol only)
  geom_point(data = peak_df, aes(x = x, y = y), shape = 17, size = 3.5, color = "#c0392b", alpha = 0.7) +

  # Legend (Bottom Horizontal)
  geom_spatraster(data = r, aes(fill = .data[[names(r)[1]]]), alpha = 0) +
  scale_fill_gradientn(colors = terrain_pal, name = "Elevation (m)",
                       labels = scales::label_comma(),
                       guide = guide_colorbar(title.position = "top", 
                                              title.hjust = 0.5,
                                              barwidth = 20, 
                                              barheight = 0.5)) +

  # Coordination system: Zoom out by adding a buffer
  coord_sf(crs = crs(r), expand = TRUE,
           xlim = c(ext(r)[1] - (ext(r)[2]-ext(r)[1])*0.05, ext(r)[2] + (ext(r)[2]-ext(r)[1])*0.05),
           ylim = c(ext(r)[3] - (ext(r)[4]-ext(r)[3])*0.05, ext(r)[4] + (ext(r)[4]-ext(r)[3])*0.05)) +

  # Labels and Layout
  labs(
    title = "TOPOGRAPHIC SHADED RELIEF",
    subtitle = "RODRIGUEZ, RIZAL",
    caption = paste0("CRS: UTM ZONE 51N (WGS84)\nCREATED WITH R & RAYSHADER | MAPPED BY: FREDERICK CUARIO")
  ) +
  # Scale Bar: Bottom right
  annotation_scale(location = "br", width_hint = 0.3, style = "bar",
                   text_family = "serif", unit_category = "metric",
                   pad_x = unit(0.5, "in"), pad_y = unit(0.5, "in")) +

  # North Arrow: Top Left
  annotation_north_arrow(location = "tl", which_north = "true",
                         pad_x = unit(0.5, "in"), pad_y = unit(0.5, "in"),
                         height = unit(2.0, "cm"), width = unit(2.0, "cm"),
                         style = north_arrow_fancy_orienteering(text_family = "serif")) +

  # Aesthetic Theme
  theme_minimal() +
  theme(
    text = element_text(family = "serif", color = "#1a1a1a"),
    plot.title = element_text(size = 38, face = "bold", hjust = 0.5, margin = margin(t = 30, b = 10)),
    plot.subtitle = element_text(size = 20, hjust = 0.5, margin = margin(b = 30), color = "#4d4d4d"),
    plot.caption = element_text(size = 11, color = "#1a1a1a", margin = margin(t = 20), hjust = 1, lineheight = 1.2, face = "italic"),
    # Legend at bottom with better spacing to avoid overlap
    legend.position = "bottom",
    legend.box.margin = margin(t = 10, b = 10),
    # Professional Graticule Styling
    panel.grid.major = element_line(color = "#1a1a1a", linewidth = 0.05, linetype = "dotted"),
    panel.grid.minor = element_blank(),
    # "Museum Style" Neatline (Double border effect)
    panel.border = element_rect(color = "#1a1a1a", fill = NA, linewidth = 2),
    plot.background = element_rect(fill = "#ffffff", color = NA),
    panel.background = element_rect(fill = "#fdfcf0", color = NA),
    axis.text = element_blank(),
    axis.title = element_blank(),
    # Increased bottom margin to accommodate the legend
    plot.margin = margin(40, 40, 60, 40)
  )

# 6. EXPORT
output_file <- "topomap_contour_final.png"
message("Exporting to ", output_file, "...")
ggsave(output_file, p, width = 16, height = 14, dpi = 300)
