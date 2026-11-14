# 03_model_tuning_advanced.R
# Advanced hyperparameter optimization with multiple strategies
# Supports: Grid Search, Random Search, and Bayesian Optimization

# Load required libraries
library(mlr3tuning)
library(paradox)

cat("\n=== ADVANCED HYPERPARAMETER TUNING ===\n")

# ============================================================================
# CONFIGURATION
# ============================================================================

# Choose tuning strategy: "grid_search", "random_search", or "bayesian"
TUNING_STRATEGY <- "random_search"  # Change this to switch strategies

# Number of evaluations for each model
N_EVALS_SVM <- 30
N_EVALS_ANN <- 30
N_EVALS_RF <- 25
N_EVALS_XGB <- 40

# Number of CV folds
N_FOLDS <- 5

# Random seed for reproducibility
SEED <- 50

cat("Tuning strategy:", TUNING_STRATEGY, "\n")
cat("Number of CV folds:", N_FOLDS, "\n\n")

# ============================================================================
# SETUP
# ============================================================================

# Load the scaled task
task_motupe_scaled <- readRDS("data/task_motupe_scaled.RDS")

# Set up spatial cross-validation for tuning
set.seed(SEED)
spatial_cv_tuning <- mlr3::rsmp("spcv_block", folds = N_FOLDS, cols = 3, rows = 3)

# Define performance measure for optimization
measure_rmse <- mlr3::msr("regr.rmse")

# ============================================================================
# HELPER FUNCTION: Select tuning method
# ============================================================================

get_tuner <- function(strategy, n_evals) {
  tuner <- switch(
    strategy,
    "grid_search" = {
      # Calculate resolution based on number of parameters
      # For 3 params: resolution=3 gives 27 evals, resolution=4 gives 64 evals
      resolution <- ceiling(n_evals^(1/3))
      mlr3tuning::tnr("grid_search", resolution = resolution)
    },
    "random_search" = {
      mlr3tuning::tnr("random_search")
    },
    "bayesian" = {
      # Requires mlr3mbo package
      tryCatch({
        library(mlr3mbo)
        mlr3tuning::tnr("mbo")
      }, error = function(e) {
        cat("Bayesian optimization requires mlr3mbo package. Falling back to random search.\n")
        mlr3tuning::tnr("random_search")
      })
    },
    {
      cat("Unknown strategy. Using random search.\n")
      mlr3tuning::tnr("random_search")
    }
  )
  return(tuner)
}

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

  # Define search space for SVM hyperparameters (expanded)
  svm_search_space <- paradox::ps(
    cost = paradox::p_dbl(lower = 0.01, upper = 200, logscale = TRUE),    # Regularization
    gamma = paradox::p_dbl(lower = 0.0001, upper = 2, logscale = TRUE),   # Kernel coefficient
    epsilon = paradox::p_dbl(lower = 0.001, upper = 0.5)                  # Loss function epsilon
  )

  # Get appropriate tuner
  svm_tuner <- get_tuner(TUNING_STRATEGY, N_EVALS_SVM)

  cat("Evaluating", N_EVALS_SVM, "hyperparameter combinations...\n")

  # Run tuning with spatial CV
  svm_instance <- mlr3tuning::tune(
    tuner = svm_tuner,
    task = task_motupe_scaled,
    learner = svm_learner,
    resampling = spatial_cv_tuning,
    measures = measure_rmse,
    search_space = svm_search_space,
    term_evals = N_EVALS_SVM
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
  cat("Using fallback model\n")
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
    linout = TRUE,
    MaxNWts = 5000  # Increase max weights for larger networks
  )

  # Define search space (expanded)
  ann_search_space <- paradox::ps(
    size = paradox::p_int(lower = 3, upper = 25),              # Hidden layer size
    decay = paradox::p_dbl(lower = 1e-5, upper = 0.5, logscale = TRUE),  # Weight decay
    maxit = paradox::p_int(lower = 200, upper = 1000)          # Max iterations
  )

  # Get appropriate tuner
  ann_tuner <- get_tuner(TUNING_STRATEGY, N_EVALS_ANN)

  cat("Evaluating", N_EVALS_ANN, "hyperparameter combinations...\n")

  # Run tuning
  ann_instance <- mlr3tuning::tune(
    tuner = ann_tuner,
    task = task_motupe_scaled,
    learner = ann_learner,
    resampling = spatial_cv_tuning,
    measures = measure_rmse,
    search_space = ann_search_space,
    term_evals = N_EVALS_ANN
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
  cat("Using fallback model\n")
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

  # Define search space (expanded)
  rf_search_space <- paradox::ps(
    num.trees = paradox::p_int(lower = 100, upper = 1000),                  # Number of trees
    mtry = paradox::p_int(lower = max(1, floor(n_features/4)),
                          upper = n_features),                              # Variables per split
    min.node.size = paradox::p_int(lower = 1, upper = 15),                  # Minimum node size
    sample.fraction = paradox::p_dbl(lower = 0.4, upper = 1.0),             # Sampling fraction
    max.depth = paradox::p_int(lower = 5, upper = 30)                       # Maximum tree depth
  )

  # Get appropriate tuner
  rf_tuner <- get_tuner(TUNING_STRATEGY, N_EVALS_RF)

  cat("Evaluating", N_EVALS_RF, "hyperparameter combinations...\n")

  # Run tuning
  rf_instance <- mlr3tuning::tune(
    tuner = rf_tuner,
    task = task_motupe_scaled,
    learner = rf_learner,
    resampling = spatial_cv_tuning,
    measures = measure_rmse,
    search_space = rf_search_space,
    term_evals = N_EVALS_RF
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
  cat("Using fallback model\n")
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
    importance = "gain",
    nthread = 1  # Single thread for stability in tuning
  )

  # Define comprehensive search space for XGBoost
  xgb_search_space <- paradox::ps(
    nrounds = paradox::p_int(lower = 50, upper = 500),                  # Boosting rounds
    eta = paradox::p_dbl(lower = 0.001, upper = 0.5, logscale = TRUE),  # Learning rate
    max_depth = paradox::p_int(lower = 2, upper = 12),                  # Tree depth
    subsample = paradox::p_dbl(lower = 0.5, upper = 1.0),               # Row sampling
    colsample_bytree = paradox::p_dbl(lower = 0.4, upper = 1.0),        # Column sampling
    min_child_weight = paradox::p_int(lower = 1, upper = 10),           # Min sum of weights
    gamma = paradox::p_dbl(lower = 0, upper = 5),                       # Min loss reduction
    lambda = paradox::p_dbl(lower = 0, upper = 2),                      # L2 regularization
    alpha = paradox::p_dbl(lower = 0, upper = 2)                        # L1 regularization
  )

  # Get appropriate tuner
  xgb_tuner <- get_tuner(TUNING_STRATEGY, N_EVALS_XGB)

  cat("Evaluating", N_EVALS_XGB, "hyperparameter combinations...\n")

  # Run tuning
  xgb_instance <- mlr3tuning::tune(
    tuner = xgb_tuner,
    task = task_motupe_scaled,
    learner = xgb_learner,
    resampling = spatial_cv_tuning,
    measures = measure_rmse,
    search_space = xgb_search_space,
    term_evals = N_EVALS_XGB
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
  cat("Using fallback model\n")
  mlr3::lrn("regr.rpart")
})

# Save tuning results
if (exists("xgb_instance")) {
  saveRDS(xgb_instance, "models/xgb_tuning_results.RDS")
}

# ============================================================================
# SAVE OPTIMIZED MODELS AND CREATE REPORTS
# ============================================================================

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

# ============================================================================
# CREATE DETAILED TUNING SUMMARY REPORT
# ============================================================================

cat("\n=== CREATING DETAILED TUNING REPORT ===\n")

# Initialize summary data frame
tuning_summary <- data.frame(
  Model = character(),
  Best_RMSE = numeric(),
  N_Evaluations = integer(),
  Strategy = character(),
  Parameters = character(),
  stringsAsFactors = FALSE
)

# Add SVM results
if (exists("svm_instance")) {
  svm_params <- paste(names(svm_instance$result_learner_param_vals),
                      sapply(svm_instance$result_learner_param_vals, function(x) round(x, 4)),
                      sep = "=", collapse = ", ")
  tuning_summary <- rbind(tuning_summary, data.frame(
    Model = "SVM",
    Best_RMSE = round(svm_instance$result_y, 4),
    N_Evaluations = N_EVALS_SVM,
    Strategy = TUNING_STRATEGY,
    Parameters = svm_params
  ))
}

# Add ANN results
if (exists("ann_instance")) {
  ann_params <- paste(names(ann_instance$result_learner_param_vals),
                      sapply(ann_instance$result_learner_param_vals, function(x) round(x, 4)),
                      sep = "=", collapse = ", ")
  tuning_summary <- rbind(tuning_summary, data.frame(
    Model = "ANN",
    Best_RMSE = round(ann_instance$result_y, 4),
    N_Evaluations = N_EVALS_ANN,
    Strategy = TUNING_STRATEGY,
    Parameters = ann_params
  ))
}

# Add RF results
if (exists("rf_instance")) {
  rf_params <- paste(names(rf_instance$result_learner_param_vals),
                     sapply(rf_instance$result_learner_param_vals, function(x) round(x, 4)),
                     sep = "=", collapse = ", ")
  tuning_summary <- rbind(tuning_summary, data.frame(
    Model = "Random Forest",
    Best_RMSE = round(rf_instance$result_y, 4),
    N_Evaluations = N_EVALS_RF,
    Strategy = TUNING_STRATEGY,
    Parameters = rf_params
  ))
}

# Add XGBoost results
if (exists("xgb_instance")) {
  xgb_params <- paste(names(xgb_instance$result_learner_param_vals),
                      sapply(xgb_instance$result_learner_param_vals, function(x) round(x, 4)),
                      sep = "=", collapse = ", ")
  tuning_summary <- rbind(tuning_summary, data.frame(
    Model = "XGBoost",
    Best_RMSE = round(xgb_instance$result_y, 4),
    N_Evaluations = N_EVALS_XGB,
    Strategy = TUNING_STRATEGY,
    Parameters = xgb_params
  ))
}

# Print summary
cat("\nTuning Summary:\n")
print(tuning_summary)

# Save summary to file
write.csv(tuning_summary, "models/hyperparameter_tuning_summary.csv", row.names = FALSE)
cat("\nTuning summary saved to: models/hyperparameter_tuning_summary.csv\n")

# ============================================================================
# CREATE TUNING VISUALIZATION (OPTIONAL)
# ============================================================================

# Create visualization of tuning history if available
if (requireNamespace("ggplot2", quietly = TRUE)) {
  library(ggplot2)

  # Create plots directory if it doesn't exist
  if (!dir.exists("plots")) {
    dir.create("plots")
  }

  # Function to plot tuning history
  plot_tuning_history <- function(instance, model_name) {
    if (!is.null(instance) && !is.null(instance$archive)) {
      archive_data <- as.data.frame(instance$archive$data)

      if (nrow(archive_data) > 0 && "regr.rmse" %in% names(archive_data)) {
        p <- ggplot(archive_data, aes(x = seq_len(nrow(archive_data)), y = regr.rmse)) +
          geom_line(color = "steelblue", linewidth = 1) +
          geom_point(color = "darkblue", size = 2) +
          geom_hline(yintercept = min(archive_data$regr.rmse, na.rm = TRUE),
                     linetype = "dashed", color = "red", linewidth = 1) +
          labs(
            title = paste(model_name, "Hyperparameter Tuning Progress"),
            subtitle = paste("Strategy:", TUNING_STRATEGY),
            x = "Iteration",
            y = "RMSE (lower is better)"
          ) +
          theme_minimal() +
          theme(
            plot.title = element_text(size = 14, face = "bold"),
            plot.subtitle = element_text(size = 11),
            axis.title = element_text(size = 11),
            axis.text = element_text(size = 10)
          )

        ggsave(
          paste0("plots/", tolower(gsub(" ", "_", model_name)), "_tuning_history.png"),
          plot = p,
          width = 10,
          height = 6,
          dpi = 300
        )

        cat("Saved tuning plot for", model_name, "\n")
      }
    }
  }

  # Generate plots for all models
  if (exists("svm_instance")) plot_tuning_history(svm_instance, "SVM")
  if (exists("ann_instance")) plot_tuning_history(ann_instance, "ANN")
  if (exists("rf_instance")) plot_tuning_history(rf_instance, "Random Forest")
  if (exists("xgb_instance")) plot_tuning_history(xgb_instance, "XGBoost")
}

cat("\n=== ADVANCED HYPERPARAMETER TUNING COMPLETE ===\n")
cat("Total time for tuning: Check system logs\n")
cat("Next step: Run spatial cross-validation with optimized models\n")
