# rDEM: Professional Topographic Map

This repository contains a R script designed to transform Digital Elevation Models (DEMs) into professional topographic maps using ray-tracing and hillshading techniques.

## Features
- **Advanced Shaded Relief**: Uses `rayshader` for realistic multi-directional shadows and ambient occlusion.
- **Precision Contours**: Automatic generation of smooth index and minor contours.
- **Classic Cartography**: Includes high-contrast neatlines, professional north arrows, and scale bars.
- **Technical Accuracy**: Automatically handles geographic (Lat/Lon) to metric scaling and displays CRS metadata.

## Prerequisites
You will need **R** installed on your system. The script will automatically attempt to install the following packages if you don't have them:
- `terra`
- `rayshader`
- `ggplot2`
- `tidyterra`
- `metR`
- `colorspace`
- `ggspatial`

## How to Use

### 1. Provide Your Data
> [!IMPORTANT]
> You must provide your own Digital Elevation Model (DEM) file (typically a `.tif` or `.hgt` file).

1.  Place your DEM file in the project folder.
2.  Open `dem.R`.
3.  **Go to line 19** and change the file path to match your own DEM file:
    ```r
    dem_path <- "your_dem_file.tif" # Update this on line 19
    ```

### 2. Run the Script
Execute the entire script in your R environment (e.g., RStudio). The script will:
1.  Load and preprocess your terrain data.
2.  Calculate advanced hillshading and texture maps.
3.  Generate the final topographic layout.
4.  Export a high-resolution image named `topomap_contour_final.png`.

## Credits
- **Script Logic**: Developed by Antigravity AI
- **Mapped by**: Frederick Cuario
- **Engine**: Powered by R and the `rayshader` package.
