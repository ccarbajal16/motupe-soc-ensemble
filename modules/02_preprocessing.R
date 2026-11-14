# 02_preprocessing.R

# 1.2. Load and extract data
# 1.2.1. Stack rasters from folder with predictors
if (!dir.exists("predictors")) {
  dir.create("predictors")
}   
# Stack all raster files in the "predictors" folder
covariates <- terra::rast(list.files("predictors", pattern = "[.]tif$", full.names = TRUE))
# Export the stacked raster
terra::writeRaster(covariates, "data/predictors.tif", overwrite = TRUE)

# 1.2.2. Load data
covariates <- terra::rast("data/predictors.tif")

# We'll keep the original covariates without adding X and Y as predictors
covariates_with_xy <- covariates

covsoc <- sf::read_sf("data/suelos_motupe_model.gpkg")

# Verify if the datasets are numerical
str(covsoc)

# Convert character columns to numeric
numeric_columns <- c("X", "Y", "SOC")

covsoc <- covsoc %>%
  dplyr::mutate(across(all_of(numeric_columns), as.numeric))

# Verify the conversion worked
str(covsoc)
cat("Summary of converted data:\n")
summary(covsoc[numeric_columns])

motupe <- sf::read_sf("data/borde_motupe.gpkg") %>%
  st_transform(st_crs(covsoc))

# crop and mask covariates to motupe extent
covariates_with_xy <- terra::crop(covariates, motupe)
covariates_with_xy <- terra::mask(covariates, motupe)

# assign names of covariates
names(covariates_with_xy) <- c("Aspect", "BD", "Clay", "EC", "EVI", "GNDVI", "Hillshade", 
                            "pH", "Silt", "TPI", "TRI", "TWI", "Temp")

# 1.2.2. Extract data
covsoc <- terra::extract(covariates_with_xy, covsoc, bind = TRUE) %>%
  sf::st_as_sf()

# Remove X/Y columns if they exist to avoid conflicts
covsoc$X <- NULL
covsoc$Y <- NULL

# 2. Define task and preprocessing
# 2.1. Define task
# Use all available features (terrain covariates + soil properties) except the target
# This allows the models to use all available information for prediction
feature_cols <- c("Aspect", "BD", "Clay", "EC", "EVI", "GNDVI", "Hillshade", 
                            "pH", "Silt", "TPI", "TRI", "TWI", "Temp")

# Check which features are actually available in the data
available_features <- intersect(feature_cols, names(covsoc))
cat("Available features for modeling:", paste(available_features, collapse = ", "), "\n")

# Create a subset with only available predictors and target (SOC)
covsoc_for_modeling <- covsoc[, c(available_features, "SOC", "geometry")]

task_motupe <- mlr3spatial::as_task_regr_st(
  covsoc_for_modeling,
  target = "SOC",
  coordinate_names = "geometry",
  coords_as_features = FALSE,  # Don't include coordinates as features
  crs = st_crs(covsoc)
)

# 2.1.1 Scale features (important for models like SVM and ANN)
po_scale <- po("scale")
task_motupe_scaled <- po_scale$train(list(task_motupe))[[1]]

# Save the preprocessed data
saveRDS(task_motupe_scaled, "data/task_motupe_scaled.RDS")
saveRDS(po_scale, "models/po_scale.RDS")
saveRDS(covariates_with_xy, "data/covariates_with_xy.RDS")
saveRDS(motupe, "data/motupe.RDS")
saveRDS(covsoc_for_modeling, "data/covsoc_for_modeling.RDS")