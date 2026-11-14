# 04_spatial_cv.R

# Load preprocessed data and models
task_motupe_scaled <- readRDS("data/task_motupe_scaled.RDS")
svm_model <- readRDS("models/svm_model.RDS")
ann_model <- readRDS("models/ann_model.RDS")
rf_model <- readRDS("models/rf_model.RDS")
xgb_model <- readRDS("models/xgb_model.RDS")
covsoc_for_modeling <- readRDS("data/covsoc_for_modeling.RDS")

# 2.2. Set up spatial cross-validation
# We'll use spatial block cross-validation to account for spatial autocorrelation
set.seed(50) # For reproducibility

# Define spatial resampling strategy
spatial_cv <- mlr3::rsmp("spcv_block", folds = 5, cols = 3, rows = 3)
spatial_cv$instantiate(task_motupe_scaled)

# 3. Define measures for model evaluation
measure_rmse <- mlr3::msr("regr.rmse")
measure_mae <- mlr3::msr("regr.mae")
measure_rsq <- mlr3::msr("regr.rsq")  # R-squared

# Perform spatial cross-validation for each model
run_spatial_cv <- function(learner, task, resampling, measures) {
  return(run_single_model_cv(learner, task, resampling, measures))
}

# Simplified approach - run each model individually instead of using benchmark
run_single_model_cv <- function(learner, task, resampling, measures) {
  tryCatch({
    learner_clone <- learner$clone()
    
    if (!resampling$is_instantiated) {
      resampling$instantiate(task)
    }
    
    results <- list()
    predictions <- list()
    all_predictions <- data.frame()
    
    for (i in seq_len(resampling$iters)) {
      train_set <- resampling$train_set(i)
      test_set <- resampling$test_set(i)
      
      learner_clone$train(task, row_ids = train_set)
      
      pred <- learner_clone$predict(task, row_ids = test_set)
      predictions[[i]] <- pred
      
      # Store predictions and truth values
      fold_pred_df <- data.frame(
        fold = i,
        row_id = test_set,
        observed = pred$truth,
        predicted = pred$response
      )
      all_predictions <- rbind(all_predictions, fold_pred_df)
      
      fold_results <- list()
      for (measure in measures) {
        fold_results[[measure$id]] <- pred$score(measure)
      }
      results[[i]] <- fold_results
    }
    
    aggregated <- list()
    for (measure in measures) {
      measure_values <- sapply(results, function(x) x[[measure$id]])
      aggregated[[measure$id]] <- mean(measure_values, na.rm = TRUE)
    }
    
    final_model <- learner$clone()$train(task)
    
    return(list(
      results = aggregated,
      model = final_model,
      predictions = all_predictions
    ))
  }, error = function(e) {
    cat("Error in", learner$id, ":", e$message, "\n")
    return(list(
      results = list(regr.rmse = NA, regr.mae = NA, regr.rsq = NA),
      model = learner$clone()$train(task),
      predictions = data.frame()
    ))
  })
}

# Run spatial CV for each model with error handling
cat("Running spatial cross-validation for SVM model...\n")
svm_cv <- tryCatch({
  run_spatial_cv(svm_model, task_motupe_scaled, spatial_cv,
                list(measure_rmse, measure_mae, measure_rsq))
}, error = function(e) {
  cat("Error in SVM cross-validation:", e$message, "\n")
  list(
    results = list(regr.rmse = NA, regr.mae = NA, regr.rsq = NA),
    model = svm_model$clone()$train(task_motupe_scaled)
  )
})

cat("Running spatial cross-validation for ANN model...\n")
ann_cv <- tryCatch({
  run_spatial_cv(ann_model, task_motupe_scaled, spatial_cv,
                list(measure_rmse, measure_mae, measure_rsq))
}, error = function(e) {
  cat("Error in ANN cross-validation:", e$message, "\n")
  list(
    results = list(regr.rmse = NA, regr.mae = NA, regr.rsq = NA),
    model = ann_model$clone()$train(task_motupe_scaled)
  )
})

cat("Running spatial cross-validation for Random Forest model...\n")
rf_cv <- tryCatch({
  run_spatial_cv(rf_model, task_motupe_scaled, spatial_cv,
                list(measure_rmse, measure_mae, measure_rsq))
}, error = function(e) {
  cat("Error in Random Forest cross-validation:", e$message, "\n")
  list(
    results = list(regr.rmse = NA, regr.mae = NA, regr.rsq = NA),
    model = rf_model$clone()$train(task_motupe_scaled)
  )
})

cat("Running spatial cross-validation for XGBoost model...\n")
xgb_cv <- tryCatch({
  run_spatial_cv(xgb_model, task_motupe_scaled, spatial_cv,
                list(measure_rmse, measure_mae, measure_rsq))
}, error = function(e) {
  cat("Error in XGBoost cross-validation:", e$message, "\n")
  list(
    results = list(regr.rmse = NA, regr.mae = NA, regr.rsq = NA),
    model = xgb_model$clone()$train(task_motupe_scaled)
  )
})

# Save the CV results
saveRDS(svm_cv, "models/svm_cv.RDS")
saveRDS(ann_cv, "models/ann_cv.RDS")
saveRDS(rf_cv, "models/rf_cv.RDS")
saveRDS(xgb_cv, "models/xgb_cv.RDS")

# Export CV predictions to CSV files
cat("Exporting CV predictions to CSV files...\n")

# Create outputs directory if it doesn't exist
if (!dir.exists("outputs")) {
  dir.create("outputs")
}

# Export SVM predictions
if (!is.null(svm_cv$predictions) && nrow(svm_cv$predictions) > 0) {
  write.csv(svm_cv$predictions, "outputs/svm_cv_predictions.csv", row.names = FALSE)
  cat("SVM CV predictions saved to outputs/svm_cv_predictions.csv\n")
}

# Export ANN predictions
if (!is.null(ann_cv$predictions) && nrow(ann_cv$predictions) > 0) {
  write.csv(ann_cv$predictions, "outputs/ann_cv_predictions.csv", row.names = FALSE)
  cat("ANN CV predictions saved to outputs/ann_cv_predictions.csv\n")
}

# Export Random Forest predictions
if (!is.null(rf_cv$predictions) && nrow(rf_cv$predictions) > 0) {
  write.csv(rf_cv$predictions, "outputs/rf_cv_predictions.csv", row.names = FALSE)
  cat("Random Forest CV predictions saved to outputs/rf_cv_predictions.csv\n")
}

# Export XGBoost predictions
if (!is.null(xgb_cv$predictions) && nrow(xgb_cv$predictions) > 0) {
  write.csv(xgb_cv$predictions, "outputs/xgb_cv_predictions.csv", row.names = FALSE)
  cat("XGBoost CV predictions saved to outputs/xgb_cv_predictions.csv\n")
}

# Create spatial CV partitioning map
library(ggplot2)
library(sf)

# Load study area boundary
study_area <- sf::st_read("data/borde_motupe.gpkg", quiet = TRUE)

# Get the spatial coordinates from the original data (which should have coordinates)
coords_data <- covsoc_for_modeling

# Check available coordinate column names
coord_cols <- names(coords_data)
cat("Available columns:", paste(coord_cols, collapse = ", "), "\n")

# Try different possible coordinate column names
x_col <- NULL
y_col <- NULL

# Common coordinate column name patterns
x_patterns <- c("x", "X", "lon", "longitude", "Longitude", "LONGITUDE", "easting", "Easting")
y_patterns <- c("y", "Y", "lat", "latitude", "Latitude", "LATITUDE", "northing", "Northing")

for (pattern in x_patterns) {
  if (pattern %in% coord_cols) {
    x_col <- pattern
    break
  }
}

for (pattern in y_patterns) {
  if (pattern %in% coord_cols) {
    y_col <- pattern
    break
  }
}

if (is.null(x_col) || is.null(y_col)) {
  # If coordinates not found, check if it's an sf object
  if (inherits(coords_data, "sf")) {
    coords_sf <- coords_data
    coords_df <- sf::st_coordinates(coords_data)
    coords_df <- data.frame(
      x = coords_df[,1],
      y = coords_df[,2],
      SOC = coords_data$SOC
    )
  } else {
    stop("Could not find coordinate columns. Available columns: ", paste(coord_cols, collapse = ", "))
  }
} else {
  coords_df <- data.frame(
    x = coords_data[[x_col]],
    y = coords_data[[y_col]],
    SOC = coords_data$SOC
  )
}

cat("Successfully extracted", nrow(coords_df), "coordinate pairs\n")

# Create fold assignments for each point
fold_assignments <- data.frame(
  x = coords_df$x,
  y = coords_df$y,
  fold = NA
)

# Get fold assignments from spatial CV
for (i in seq_len(spatial_cv$iters)) {
  test_indices <- spatial_cv$test_set(i)
  fold_assignments$fold[test_indices] <- i
}

# Convert to sf object (use same CRS as study area)
coords_sf <- sf::st_as_sf(fold_assignments, coords = c("x", "y"), 
                          crs = sf::st_crs(study_area))

# Create the map
cv_map <- ggplot() +
  # Add study area boundary
  geom_sf(data = study_area, fill = NA, color = "black", linewidth = 1.2) +
  # Add points colored by fold
  geom_sf(data = coords_sf, aes(color = factor(fold)), size = 4, alpha = 0.8) +
  scale_color_viridis_d(name = "CV Fold", option = "viridis") +
  labs(
    title = "Spatial Block Cross-Validation Partitioning",
    subtitle = paste0("5-fold spatial CV with ", nrow(coords_df), " sampling points"),
    caption = ""
  ) +
  theme_minimal() +
  theme(
    axis.text = element_text(size = 16),
    axis.title = element_text(size = 12),
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 12),
    legend.title = element_text(size = 12),
    legend.text = element_text(size = 10),
    panel.grid = element_line(color = "grey90", linewidth = 0.3)
  ) +
  coord_sf(expand = FALSE)

# Create plots directory if it doesn't exist
if (!dir.exists("plots")) {
  dir.create("plots")
}

# Save the map at 600 DPI
ggsave(
  "plots/spatial_cv_partitioning_map.png", 
  plot = cv_map, 
  width = 12, 
  height = 10, 
  dpi = 600, 
  bg = "white"
)

cat("Spatial CV partitioning map saved to plots/spatial_cv_partitioning_map.png\n")
