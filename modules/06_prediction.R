# 06_prediction.R

# Load data and models
po_scale <- readRDS("models/po_scale.RDS")
covariates_with_xy <- readRDS("data/covariates_with_xy.RDS")
svm_cv <- readRDS("models/svm_cv.RDS")
ann_cv <- readRDS("models/ann_cv.RDS")
rf_cv <- readRDS("models/rf_cv.RDS")
xgb_cv <- readRDS("models/xgb_cv.RDS")
weights <- readRDS("models/ensemble_weights.RDS")
motupe <- readRDS("data/motupe.RDS")
task_motupe_scaled <- readRDS("data/task_motupe_scaled.RDS")

# 8. Train final models on the full dataset
svm_model_final <- svm_cv$model
ann_model_final <- ann_cv$model
rf_model_final <- rf_cv$model
xgb_model_final <- xgb_cv$model

# 9. Prepare for raster prediction
all_covariates <- rast("data/predictors.tif")

expected_names <- c("Aspect", "BD", "Clay", "EC", "EVI", "GNDVI", "Hillshade", 
                            "pH", "Silt", "TPI", "TRI", "TWI", "Temp")
if (nlyr(all_covariates) == length(expected_names)) {
  names(all_covariates) <- expected_names
} else {
  names(all_covariates) <- expected_names[1:nlyr(all_covariates)]
}

required_features <- task_motupe_scaled$feature_names
available_features <- names(all_covariates)
missing_features <- setdiff(required_features, available_features)

if (length(missing_features) > 0) {
  stop("Cannot proceed with prediction - missing required features")
}

# 9.2 Scale the covariates
scale_params <- po_scale$state$scale
center_params <- po_scale$state$center

scale_raster <- function(rast, scale_params, center_params) {
  names_rast <- names(rast)
  for (i in seq_along(names_rast)) {
    name <- names_rast[i]
    if (name %in% names(scale_params)) {
      rast[[name]] <- (rast[[name]] - center_params[name]) / scale_params[name]
    }
  }
  rast
}

all_covariates_scaled <- scale_raster(all_covariates, scale_params, center_params)

impute_raster_na <- function(rast) {
  for (i in 1:nlyr(rast)) {
    layer <- rast[[i]]
    if (any(is.na(values(layer)))) {
      layer_mean <- mean(values(layer), na.rm = TRUE)
      values(layer)[is.na(values(layer))] <- layer_mean
      rast[[i]] <- layer
    }
  }
  rast
}

all_covariates_scaled_imputed <- impute_raster_na(all_covariates_scaled)

# 10.1 Generate raster predictions
svm_raster_prediction <- terra::predict(all_covariates_scaled_imputed, svm_model_final)
ann_raster_prediction <- terra::predict(all_covariates_scaled_imputed, ann_model_final)
rf_raster_prediction <- terra::predict(all_covariates_scaled_imputed, rf_model_final)
xgb_raster_prediction <- terra::predict(all_covariates_scaled_imputed, xgb_model_final)

# 10.2 Create ensemble raster predictions
ensemble_raster_prediction <- (svm_raster_prediction + ann_raster_prediction +
                              rf_raster_prediction + xgb_raster_prediction) / 4
names(ensemble_raster_prediction) <- "Ensemble_Average"

weighted_ensemble_raster_prediction <- (weights$svm * svm_raster_prediction) +
                                      (weights$ann * ann_raster_prediction) +
                                      (weights$rf * rf_raster_prediction) +
                                      (weights$xgb * xgb_raster_prediction)
names(weighted_ensemble_raster_prediction) <- "Ensemble_Weighted"

# Crop and mask from polygon of study area
study_area <- st_read("data/borde_motupe.gpkg") |> st_cast("POLYGON")
svm_raster_prediction <- mask(crop(svm_raster_prediction, study_area), study_area)
ann_raster_prediction <- mask(crop(ann_raster_prediction, study_area), study_area)
rf_raster_prediction <- mask(crop(rf_raster_prediction, study_area), study_area)
xgb_raster_prediction <- mask(crop(xgb_raster_prediction, study_area), study_area)
ensemble_raster_prediction <- mask(crop(ensemble_raster_prediction, study_area), study_area)
weighted_ensemble_raster_prediction <- mask(crop(weighted_ensemble_raster_prediction, study_area), study_area)  

# Save prediction rasters
writeRaster(svm_raster_prediction, "outputs/svm_prediction_spatial_cv.tif", overwrite = TRUE)
writeRaster(ann_raster_prediction, "outputs/ann_prediction_spatial_cv.tif", overwrite = TRUE)
writeRaster(rf_raster_prediction, "outputs/rf_prediction_spatial_cv.tif", overwrite = TRUE)
writeRaster(xgb_raster_prediction, "outputs/xgb_prediction_spatial_cv.tif", overwrite = TRUE)
writeRaster(ensemble_raster_prediction, "outputs/ensemble_avg_spatial_cv.tif", overwrite = TRUE)
writeRaster(weighted_ensemble_raster_prediction, "outputs/ensemble_weighted_spatial_cv.tif", overwrite = TRUE)

saveRDS(all_covariates_scaled_imputed, "data/all_covariates_scaled_imputed.RDS")
