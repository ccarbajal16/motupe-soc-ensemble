# 03_model_tuning.R
# Hyperparameter optimization with grid search for all models

# Load required libraries
library(mlr3tuning)
library(paradox)

cat("\n=== STARTING HYPERPARAMETER TUNING ===\n")

# Load the scaled task
task_motupe_scaled <- readRDS("data/task_motupe_scaled.RDS")

# Set up spatial cross-validation for tuning
set.seed(50)
spatial_cv_tuning <- mlr3::rsmp("spcv_block", folds = 5, cols = 3, rows = 3)

# Define performance measure for optimization
measure_rmse <- mlr3::msr("regr.rmse")

# ============================================================================
# 1. SVM MODEL TUNING
# ============================================================================
cat("\n--- Tuning SVM Model ---\n")

svm_model <- tryCatch({
  # Define base learner
  svm_learner <- mlr3::lrn(
    "regr.svm",
    kernel = "radial",
    type = "eps-regression"
  )

  # Define search space for SVM hyperparameters
  svm_search_space <- paradox::ps(
    cost = paradox::p_dbl(lower = 0.1, upper = 100),       # Regularization parameter
    gamma = paradox::p_dbl(lower = 0.001, upper = 1),      # Kernel coefficient
    epsilon = paradox::p_dbl(lower = 0.01, upper = 0.5)    # Epsilon in epsilon-insensitive loss
  )

  # Define grid for systematic search
  svm_grid <- paradox::generate_design_grid(
    svm_search_space,
    resolution = 3  # 3 values per parameter = 3^3 = 27 combinations
  )

  cat("SVM Grid size:", nrow(svm_grid$data), "combinations\n")

  # Create tuning instance
  svm_tuner <- mlr3tuning::tnr("grid_search", resolution = 3)

  # Run tuning with spatial CV
  svm_instance <- mlr3tuning::tune(
    tuner = svm_tuner,
    task = task_motupe_scaled,
    learner = svm_learner,
    resampling = spatial_cv_tuning,
    measures = measure_rmse,
    search_space = svm_search_space,
    term_evals = 27  # Total number of evaluations
  )

  # Get best hyperparameters
  cat("\nBest SVM hyperparameters:\n")
  print(svm_instance$result_learner_param_vals)
  cat("Best SVM RMSE:", round(svm_instance$result_y, 4), "\n")

  # Create model with best parameters
  svm_learner$param_set$values <- svm_instance$result_learner_param_vals
  svm_learner

}, error = function(e) {
  cat("SVM tuning failed:", e$message, "\n")
  cat("Using default SVM parameters or fallback model\n")
  mlr3::lrn("regr.lm")
})

# Save tuning results
if (exists("svm_instance")) {
  saveRDS(svm_instance, "models/svm_tuning_results.RDS")
}

# ============================================================================
# 2. NEURAL NETWORK (ANN) MODEL TUNING
# ============================================================================
cat("\n--- Tuning Neural Network Model ---\n")

ann_model <- tryCatch({
  # Define base learner
  ann_learner <- mlr3::lrn(
    "regr.nnet",
    trace = FALSE,
    linout = TRUE  # For regression
  )

  # Define search space
  ann_search_space <- paradox::ps(
    size = paradox::p_int(lower = 5, upper = 20),          # Hidden layer size
    decay = paradox::p_dbl(lower = 0.0001, upper = 0.1),   # Weight decay
    maxit = paradox::p_int(lower = 300, upper = 700)       # Max iterations
  )

  # Define grid
  ann_grid <- paradox::generate_design_grid(
    ann_search_space,
    resolution = 3  # 3 values per parameter = 27 combinations
  )

  cat("ANN Grid size:", nrow(ann_grid$data), "combinations\n")

  # Create tuning instance
  ann_tuner <- mlr3tuning::tnr("grid_search", resolution = 3)

  # Run tuning
  ann_instance <- mlr3tuning::tune(
    tuner = ann_tuner,
    task = task_motupe_scaled,
    learner = ann_learner,
    resampling = spatial_cv_tuning,
    measures = measure_rmse,
    search_space = ann_search_space,
    term_evals = 27
  )

  # Get best hyperparameters
  cat("\nBest ANN hyperparameters:\n")
  print(ann_instance$result_learner_param_vals)
  cat("Best ANN RMSE:", round(ann_instance$result_y, 4), "\n")

  # Create model with best parameters
  ann_learner$param_set$values <- ann_instance$result_learner_param_vals
  ann_learner

}, error = function(e) {
  cat("ANN tuning failed:", e$message, "\n")
  cat("Using default ANN parameters or fallback model\n")
  mlr3::lrn("regr.lm")
})

# Save tuning results
if (exists("ann_instance")) {
  saveRDS(ann_instance, "models/ann_tuning_results.RDS")
}

# ============================================================================
# 3. RANDOM FOREST MODEL TUNING
# ============================================================================
cat("\n--- Tuning Random Forest Model ---\n")

rf_model <- tryCatch({
  # Define base learner
  rf_learner <- mlr3::lrn(
    "regr.ranger",
    importance = "impurity"
  )

  # Calculate mtry range based on number of features
  n_features <- length(task_motupe_scaled$feature_names)

  # Define search space
  rf_search_space <- paradox::ps(
    num.trees = paradox::p_int(lower = 100, upper = 500),                    # Number of trees
    mtry = paradox::p_int(lower = max(1, floor(n_features/3)),
                          upper = min(n_features, floor(2*n_features/3))),   # Variables per split
    min.node.size = paradox::p_int(lower = 1, upper = 10),                   # Minimum node size
    sample.fraction = paradox::p_dbl(lower = 0.5, upper = 1.0)               # Sampling fraction
  )

  # Define grid with fewer combinations for RF (computationally expensive)
  rf_tuner <- mlr3tuning::tnr("grid_search", resolution = 2)

  cat("RF Grid size: ~16 combinations (2 values per parameter)\n")

  # Run tuning
  rf_instance <- mlr3tuning::tune(
    tuner = rf_tuner,
    task = task_motupe_scaled,
    learner = rf_learner,
    resampling = spatial_cv_tuning,
    measures = measure_rmse,
    search_space = rf_search_space,
    term_evals = 16
  )

  # Get best hyperparameters
  cat("\nBest Random Forest hyperparameters:\n")
  print(rf_instance$result_learner_param_vals)
  cat("Best RF RMSE:", round(rf_instance$result_y, 4), "\n")

  # Create model with best parameters
  rf_learner$param_set$values <- rf_instance$result_learner_param_vals
  rf_learner

}, error = function(e) {
  cat("Random Forest tuning failed:", e$message, "\n")
  cat("Using default RF parameters or fallback model\n")
  mlr3::lrn("regr.rpart")
})

# Save tuning results
if (exists("rf_instance")) {
  saveRDS(rf_instance, "models/rf_tuning_results.RDS")
}

# ============================================================================
# 4. XGBOOST MODEL TUNING
# ============================================================================
cat("\n--- Tuning XGBoost Model ---\n")

xgb_model <- tryCatch({
  # Define base learner
  xgb_learner <- mlr3::lrn(
    "regr.xgboost",
    verbose = 0,
    importance = "gain"
  )

  # Define search space for XGBoost
  xgb_search_space <- paradox::ps(
    nrounds = paradox::p_int(lower = 50, upper = 300),             # Number of boosting rounds
    eta = paradox::p_dbl(lower = 0.01, upper = 0.3),               # Learning rate
    max_depth = paradox::p_int(lower = 3, upper = 10),             # Maximum tree depth
    subsample = paradox::p_dbl(lower = 0.5, upper = 1.0),          # Subsample ratio
    colsample_bytree = paradox::p_dbl(lower = 0.5, upper = 1.0),   # Feature sampling
    min_child_weight = paradox::p_int(lower = 1, upper = 7)        # Minimum sum of weights
  )

  # Define grid with moderate resolution
  xgb_tuner <- mlr3tuning::tnr("grid_search", resolution = 2)

  cat("XGBoost Grid size: ~64 combinations (2 values per parameter)\n")

  # Run tuning
  xgb_instance <- mlr3tuning::tune(
    tuner = xgb_tuner,
    task = task_motupe_scaled,
    learner = xgb_learner,
    resampling = spatial_cv_tuning,
    measures = measure_rmse,
    search_space = xgb_search_space,
    term_evals = 64
  )

  # Get best hyperparameters
  cat("\nBest XGBoost hyperparameters:\n")
  print(xgb_instance$result_learner_param_vals)
  cat("Best XGBoost RMSE:", round(xgb_instance$result_y, 4), "\n")

  # Create model with best parameters
  xgb_learner$param_set$values <- xgb_instance$result_learner_param_vals
  xgb_learner

}, error = function(e) {
  cat("XGBoost tuning failed:", e$message, "\n")
  cat("Using default XGBoost parameters or fallback model\n")
  mlr3::lrn("regr.rpart")
})

# Save tuning results
if (exists("xgb_instance")) {
  saveRDS(xgb_instance, "models/xgb_tuning_results.RDS")
}

# ============================================================================
# SAVE OPTIMIZED MODELS
# ============================================================================

# Print final models
cat("\n=== OPTIMIZED MODELS SUMMARY ===\n")
cat("SVM model ID:", svm_model$id, "\n")
cat("ANN model ID:", ann_model$id, "\n")
cat("RF model ID:", rf_model$id, "\n")
cat("XGBoost model ID:", xgb_model$id, "\n")

# Save the optimized models
saveRDS(svm_model, "models/svm_model.RDS")
saveRDS(ann_model, "models/ann_model.RDS")
saveRDS(rf_model, "models/rf_model.RDS")
saveRDS(xgb_model, "models/xgb_model.RDS")

# Create a summary report of all tuning results
cat("\n=== CREATING TUNING SUMMARY REPORT ===\n")

tuning_summary <- data.frame(
  Model = character(),
  Best_RMSE = numeric(),
  Parameters = character(),
  stringsAsFactors = FALSE
)

# Add SVM results
if (exists("svm_instance")) {
  svm_params <- paste(names(svm_instance$result_learner_param_vals),
                      unlist(svm_instance$result_learner_param_vals),
                      sep = "=", collapse = ", ")
  tuning_summary <- rbind(tuning_summary, data.frame(
    Model = "SVM",
    Best_RMSE = round(svm_instance$result_y, 4),
    Parameters = svm_params
  ))
}

# Add ANN results
if (exists("ann_instance")) {
  ann_params <- paste(names(ann_instance$result_learner_param_vals),
                      unlist(ann_instance$result_learner_param_vals),
                      sep = "=", collapse = ", ")
  tuning_summary <- rbind(tuning_summary, data.frame(
    Model = "ANN",
    Best_RMSE = round(ann_instance$result_y, 4),
    Parameters = ann_params
  ))
}

# Add RF results
if (exists("rf_instance")) {
  rf_params <- paste(names(rf_instance$result_learner_param_vals),
                     unlist(rf_instance$result_learner_param_vals),
                     sep = "=", collapse = ", ")
  tuning_summary <- rbind(tuning_summary, data.frame(
    Model = "Random Forest",
    Best_RMSE = round(rf_instance$result_y, 4),
    Parameters = rf_params
  ))
}

# Add XGBoost results
if (exists("xgb_instance")) {
  xgb_params <- paste(names(xgb_instance$result_learner_param_vals),
                      unlist(xgb_instance$result_learner_param_vals),
                      sep = "=", collapse = ", ")
  tuning_summary <- rbind(tuning_summary, data.frame(
    Model = "XGBoost",
    Best_RMSE = round(xgb_instance$result_y, 4),
    Parameters = xgb_params
  ))
}

# Print summary
print(tuning_summary)

# Save summary to file
write.csv(tuning_summary, "models/hyperparameter_tuning_summary.csv", row.names = FALSE)
cat("\nTuning summary saved to models/hyperparameter_tuning_summary.csv\n")

cat("\n=== HYPERPARAMETER TUNING COMPLETE ===\n")
