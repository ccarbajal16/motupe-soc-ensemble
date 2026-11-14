# 07_uncertainty.R

# Load data and models
task_motupe_scaled <- readRDS("data/task_motupe_scaled.RDS")
all_covariates_scaled_imputed <- readRDS("data/all_covariates_scaled_imputed.RDS")
motupe <- readRDS("data/motupe.RDS")

# 10. Bootstrap Ensemble Uncertainty Quantification
cat("\nStarting bootstrap ensemble uncertainty analysis...\n")

n_bootstrap <- 10
bootstrap_seeds <- sample(1:10000, n_bootstrap, replace = FALSE)

bootstrap_ensemble_prediction <- function(seed_val, task, all_covariates_scaled, task_data_soc, mean_soc_value) {
  tryCatch({
    suppressMessages({
      library(mlr3)
      library(terra)
      library(mlr3learners)
      if (!is.null(try(library(mlr3extralearners), silent = TRUE))) {
        library(mlr3extralearners)
      }
    })
    
    set.seed(seed_val)
    
    if (seed_val %% 10 == 0) {
      cat("Processing bootstrap iteration (seed:", seed_val, ")\n")
    }
    
    n_samples <- task$nrow
    bootstrap_indices <- sample(1:n_samples, n_samples, replace = TRUE)
    
    bootstrap_task <- task$clone()
    bootstrap_task$filter(bootstrap_indices)
    
    if (bootstrap_task$nrow < 10) {
      stop("Bootstrap task has too few samples (", bootstrap_task$nrow, ")")
    }
    
    models_trained <- list()
    
    models_trained$lm <- tryCatch({
      lrn_lm <- mlr3::lrn("regr.lm")
      lrn_lm$train(bootstrap_task)
      lrn_lm
    }, error = function(e) {
      stop("Linear model failed: ", e$message)
    })
    
    models_trained$rf <- tryCatch({
      if (requireNamespace("ranger", quietly = TRUE)) {
        lrn_rf <- mlr3::lrn("regr.ranger", num.trees = 30, importance = "none", 
                           verbose = FALSE, num.threads = 1, min.node.size = 3)
        lrn_rf$train(bootstrap_task)
        lrn_rf
      } else {
        models_trained$lm
      }
    }, error = function(e) {
      models_trained$lm
    })
    
    models_trained$tree <- tryCatch({
      lrn_tree <- mlr3::lrn("regr.rpart", cp = 0.02, minsplit = 10)
      lrn_tree$train(bootstrap_task)
      lrn_tree
    }, error = function(e) {
      models_trained$lm
    })
    
    predictions <- list()
    
    predictions$lm <- tryCatch({
      pred_result <- terra::predict(all_covariates_scaled, models_trained$lm, na.rm = TRUE)
      if (is.null(pred_result) || !inherits(pred_result, "SpatRaster")) {
        stop("Predict returned invalid result")
      }
      pred_result
    }, error = function(e) {
      r <- all_covariates_scaled[[1]]
      r[] <- mean_soc_value
      names(r) <- "fallback_lm"
      return(r)
    })
    
    predictions$rf <- tryCatch({
      if (identical(models_trained$rf, models_trained$lm)) {
        predictions$lm
      } else {
        pred_result <- terra::predict(all_covariates_scaled, models_trained$rf, na.rm = TRUE)
        if (is.null(pred_result) || !inherits(pred_result, "SpatRaster")) {
          predictions$lm
        } else {
          pred_result
        }
      }
    }, error = function(e) {
      predictions$lm
    })
    
    predictions$tree <- tryCatch({
      if (identical(models_trained$tree, models_trained$lm)) {
        predictions$lm
      } else {
        pred_result <- terra::predict(all_covariates_scaled, models_trained$tree, na.rm = TRUE)
        if (is.null(pred_result) || !inherits(pred_result, "SpatRaster")) {
          predictions$lm
        } else {
          pred_result
        }
      }
    }, error = function(e) {
      predictions$lm
    })
    
    valid_preds <- list()
    for (i in seq_along(predictions)) {
      pred <- predictions[[i]]
      if (!is.null(pred) && inherits(pred, "SpatRaster")) {
        pred_values <- values(pred)
        if (sum(!is.na(pred_values)) > 0) {
          valid_preds <- append(valid_preds, list(pred))
        }
      }
    }
    
    if (length(valid_preds) == 0) {
      stop("No valid predictions generated")
    }
    
    if (length(valid_preds) == 1) {
      ensemble_pred <- valid_preds[[1]]
    } else {
      ensemble_pred <- Reduce("+", valid_preds) / length(valid_preds)
    }
    
    names(ensemble_pred) <- paste0("bootstrap_", seed_val)
    
    if (!inherits(ensemble_pred, "SpatRaster")) {
      stop("Ensemble prediction is not a valid SpatRaster object")
    }
    
    pred_values <- values(ensemble_pred)
    if (sum(!is.na(pred_values)) < (length(pred_values) * 0.1)) {
      stop("Ensemble prediction has too many NA values")
    }
    
    return(ensemble_pred)
    
  }, error = function(e) {
    cat("Bootstrap iteration", seed_val, "failed:", e$message, "\n")
    return(NULL)
  })
}

start_time <- Sys.time()

task_data_soc <- task_motupe_scaled$data()$SOC
mean_soc_value <- mean(task_data_soc, na.rm = TRUE)

bootstrap_predictions <- list()

for (i in seq_along(bootstrap_seeds)) {
  seed_val <- bootstrap_seeds[i]
  if (i %% 5 == 0) {
    cat("Processing bootstrap iteration", i, "of", length(bootstrap_seeds), "(seed:", seed_val, ")\n")
  }
  
  pred <- bootstrap_ensemble_prediction(seed_val, task_motupe_scaled, 
                                       all_covariates_scaled_imputed, task_data_soc, mean_soc_value)
  
  if (!is.null(pred) && inherits(pred, "SpatRaster")) {
    pred_values <- values(pred)
    if (sum(!is.na(pred_values)) > (length(pred_values) * 0.1)) {
      bootstrap_predictions <- append(bootstrap_predictions, list(pred))
      if (i %% 5 == 0) {
        cat("Success: Bootstrap iteration", i, "completed successfully\n")
      }
    } else {
      cat("Excluding bootstrap prediction", i, "- too many NA values\n")
    }
  } else {
    cat("Excluding bootstrap prediction", i, "- invalid prediction\n")
  }
}

end_time <- Sys.time()
cat("Bootstrap analysis completed in", round(difftime(end_time, start_time, units = "mins"), 2), "minutes\n")

if (length(bootstrap_predictions) > 1) {
  valid_predictions <- list()
  reference_extent <- NULL
  reference_crs <- NULL
  
  for (i in seq_along(bootstrap_predictions)) {
    pred <- bootstrap_predictions[[i]]
    if (!is.null(pred) && inherits(pred, "SpatRaster")) {
      if (is.null(reference_extent)) {
        reference_extent <- ext(pred)
        reference_crs <- crs(pred)
      }
      
      spatial_match <- TRUE
      tryCatch({
        if (!identical(ext(pred), reference_extent)) {
          pred <- crop(pred, reference_extent)
        }
        if (crs(pred) != reference_crs) {
          pred <- project(pred, reference_crs)
        }
      }, error = function(e) {
        spatial_match <- FALSE
      })
      
      if (spatial_match) {
        pred_values <- values(pred, na.rm = FALSE)
        valid_ratio <- sum(!is.na(pred_values)) / length(pred_values)
        
        if (valid_ratio > 0.3) { 
          valid_predictions <- append(valid_predictions, list(pred)) 
        } 
      }
    } 
  }
  
  if (length(valid_predictions) >= 5) { 
    bootstrap_stack <- do.call(c, valid_predictions)
    names(bootstrap_stack) <- paste0("boot_", 1:nlyr(bootstrap_stack))
  
  bootstrap_mean <- mean(bootstrap_stack, na.rm = TRUE)
  names(bootstrap_mean) <- "Bootstrap_Mean"
  
  bootstrap_sd <- stdev(bootstrap_stack, na.rm = TRUE)
  names(bootstrap_sd) <- "Bootstrap_StdDev"
  
  bootstrap_cv <- (bootstrap_sd / abs(bootstrap_mean)) * 100
  bootstrap_cv[bootstrap_mean <= 0] <- NA
  names(bootstrap_cv) <- "Bootstrap_CV_percent"
  
  bootstrap_q05 <- quantile(bootstrap_stack, 0.05, na.rm = TRUE)
  bootstrap_q25 <- quantile(bootstrap_stack, 0.25, na.rm = TRUE)
  bootstrap_q50 <- quantile(bootstrap_stack, 0.50, na.rm = TRUE)  # Median for PIR
  bootstrap_q75 <- quantile(bootstrap_stack, 0.75, na.rm = TRUE)
  bootstrap_q95 <- quantile(bootstrap_stack, 0.95, na.rm = TRUE)

  names(bootstrap_q05) <- "Bootstrap_Q05"
  names(bootstrap_q25) <- "Bootstrap_Q25"
  names(bootstrap_q50) <- "Bootstrap_Q50_Median"
  names(bootstrap_q75) <- "Bootstrap_Q75"
  names(bootstrap_q95) <- "Bootstrap_Q95"
  
  bootstrap_pi90 <- bootstrap_q95 - bootstrap_q05
  names(bootstrap_pi90) <- "Bootstrap_PI90_Width"
  
  bootstrap_pi90_rel <- (bootstrap_pi90 / abs(bootstrap_mean)) * 100
  bootstrap_pi90_rel[bootstrap_mean <= 0] <- NA
  names(bootstrap_pi90_rel) <- "Bootstrap_PI90_Relative_percent"

  # Prediction Interval Ratio (PIR): 90% PI width / median (50th percentile)
  bootstrap_pir <- bootstrap_pi90 / abs(bootstrap_q50)
  bootstrap_pir[bootstrap_q50 <= 0] <- NA
  names(bootstrap_pir) <- "Bootstrap_PIR_90"
  
  } else {
    bootstrap_stack <- NULL
  }
} else {
  bootstrap_stack <- NULL
}

if (is.null(bootstrap_stack)) {
  ensemble_raster_prediction <- rast("outputs/ensemble_avg_spatial_cv.tif")
  bootstrap_mean <- ensemble_raster_prediction
  bootstrap_sd <- bootstrap_cv <- bootstrap_pi90 <- bootstrap_pi90_rel <- bootstrap_pir <- ensemble_raster_prediction
  bootstrap_q05 <- bootstrap_q25 <- bootstrap_q50 <- bootstrap_q75 <- bootstrap_q95 <- ensemble_raster_prediction
  
  bootstrap_sd[] <- 0.1 * abs(values(bootstrap_mean))
  bootstrap_cv[] <- 10
  bootstrap_pi90[] <- bootstrap_pi90_rel[] <- bootstrap_pir[] <- NA
  bootstrap_q05[] <- bootstrap_q25[] <- bootstrap_q50[] <- bootstrap_q75[] <- bootstrap_q95[] <- NA
  
  names(bootstrap_sd) <- "Bootstrap_StdDev_Fallback"
  names(bootstrap_cv) <- "Bootstrap_CV_Fallback"
}

# Save uncertainty rasters
study_area <- st_read("data/borde_motupe.gpkg") |> st_cast("POLYGON")
bootstrap_mean <- mask(crop(bootstrap_mean, study_area), study_area)
bootstrap_sd <- mask(crop(bootstrap_sd, study_area), study_area)
bootstrap_cv <- mask(crop(bootstrap_cv, study_area), study_area)
bootstrap_pi90 <- mask(crop(bootstrap_pi90, study_area), study_area)
bootstrap_pi90_rel <- mask(crop(bootstrap_pi90_rel, study_area), study_area)
bootstrap_q05 <- mask(crop(bootstrap_q05, study_area), study_area)
bootstrap_q50 <- mask(crop(bootstrap_q50, study_area), study_area)
bootstrap_q95 <- mask(crop(bootstrap_q95, study_area), study_area)
bootstrap_pir <- mask(crop(bootstrap_pir, study_area), study_area)

writeRaster(bootstrap_mean, "outputs/bootstrap_mean_spatial_cv.tif", overwrite = TRUE)
writeRaster(bootstrap_sd, "outputs/bootstrap_stdev_spatial_cv.tif", overwrite = TRUE)
writeRaster(bootstrap_cv, "outputs/bootstrap_cv_spatial_cv.tif", overwrite = TRUE)
writeRaster(bootstrap_pi90, "outputs/bootstrap_pi90_width_spatial_cv.tif", overwrite = TRUE)
writeRaster(bootstrap_pi90_rel, "outputs/bootstrap_pi90_relative_spatial_cv.tif", overwrite = TRUE)
writeRaster(bootstrap_q05, "outputs/bootstrap_q05_spatial_cv.tif", overwrite = TRUE)
writeRaster(bootstrap_q50, "outputs/bootstrap_q50_median_spatial_cv.tif", overwrite = TRUE)
writeRaster(bootstrap_q95, "outputs/bootstrap_q95_spatial_cv.tif", overwrite = TRUE)
writeRaster(bootstrap_pir, "outputs/bootstrap_pir_90_spatial_cv.tif", overwrite = TRUE)

uncertainty_stack <- c(bootstrap_mean, bootstrap_sd, bootstrap_cv,
                      bootstrap_pi90, bootstrap_pi90_rel, bootstrap_q05, bootstrap_q50, bootstrap_q95, bootstrap_pir)
names(uncertainty_stack) <- c("Mean", "StdDev", "CV_percent", "PI90_Width",
                             "PI90_Relative_percent", "Q05", "Q50_Median", "Q95", "PIR_90")
writeRaster(uncertainty_stack, "outputs/bootstrap_uncertainty_stack_spatial_cv.tif", 
            overwrite = TRUE)
