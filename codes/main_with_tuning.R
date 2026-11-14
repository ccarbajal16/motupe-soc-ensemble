# main_with_tuning.R
# Complete pipeline with hyperparameter tuning

cat("\n╔════════════════════════════════════════════════════════════════╗\n")
cat("║  SOC Prediction Pipeline with Hyperparameter Optimization    ║\n")
cat("╚════════════════════════════════════════════════════════════════╝\n\n")

# ============================================================================
# CONFIGURATION
# ============================================================================

# Choose tuning module:
# - "basic": Basic grid search (03_model_tuning.R) - faster, systematic
# - "advanced": Advanced multi-strategy (03_model_tuning_advanced.R) - more thorough
# - "none": No tuning, use fixed hyperparameters (03_model_definition.R)

USE_TUNING <- "advanced"  # Change this to "basic", "advanced", or "none"

cat("Configuration:\n")
cat("  Hyperparameter tuning:", USE_TUNING, "\n\n")

# ============================================================================
# STEP 1: SETUP AND LOAD PACKAGES
# ============================================================================

cat("STEP 1/9: Setup and load packages\n")
cat("──────────────────────────────────\n")
source("modules/01_setup_and_load.R")
cat("✓ Complete\n\n")

# ============================================================================
# STEP 2: DATA PREPROCESSING
# ============================================================================

cat("STEP 2/9: Data preprocessing\n")
cat("──────────────────────────────\n")
source("modules/02_preprocessing.R")
cat("✓ Complete\n\n")

# ============================================================================
# STEP 3: MODEL DEFINITION / TUNING
# ============================================================================

cat("STEP 3/9: Model definition and hyperparameter tuning\n")
cat("─────────────────────────────────────────────────────\n")

if (USE_TUNING == "basic") {
  cat("Using BASIC GRID SEARCH tuning\n")
  source("modules/03_model_tuning.R")
} else if (USE_TUNING == "advanced") {
  cat("Using ADVANCED tuning (configurable strategy)\n")
  source("modules/03_model_tuning_advanced.R")
} else {
  cat("Using FIXED hyperparameters (no tuning)\n")
  source("modules/03_model_definition.R")
}

cat("✓ Complete\n\n")

# ============================================================================
# STEP 4: SPATIAL CROSS-VALIDATION
# ============================================================================

cat("STEP 4/9: Spatial cross-validation\n")
cat("───────────────────────────────────\n")
source("modules/04_spatial_cv.R")
cat("✓ Complete\n\n")

# ============================================================================
# STEP 5: ENSEMBLE MODELING
# ============================================================================

cat("STEP 5/9: Ensemble modeling\n")
cat("────────────────────────────\n")
source("modules/05_ensemble.R")
cat("✓ Complete\n\n")

# ============================================================================
# STEP 6: SPATIAL PREDICTION
# ============================================================================

cat("STEP 6/9: Spatial prediction\n")
cat("─────────────────────────────\n")
source("modules/06_prediction.R")
cat("✓ Complete\n\n")

# ============================================================================
# STEP 7: UNCERTAINTY ANALYSIS
# ============================================================================

cat("STEP 7/9: Uncertainty analysis\n")
cat("───────────────────────────────\n")
source("modules/07_uncertainty.R")
cat("✓ Complete\n\n")

# ============================================================================
# STEP 8: EVALUATION AND REPORTING
# ============================================================================

cat("STEP 8/9: Evaluation and reporting\n")
cat("───────────────────────────────────\n")
source("modules/08_evaluation_and_report.R")
cat("✓ Complete\n\n")

# ============================================================================
# STEP 9: TUNING COMPARISON (if tuning was used)
# ============================================================================

if (USE_TUNING != "none") {
  cat("STEP 9/9: Hyperparameter tuning comparison\n")
  cat("───────────────────────────────────────────\n")
  source("modules/compare_tuning_results.R")
  cat("✓ Complete\n\n")
} else {
  cat("STEP 9/9: Skipped (no tuning performed)\n\n")
}

# ============================================================================
# CLEANUP
# ============================================================================

if (exists("cl") && !is.null(cl)) {
  tryCatch({
    stopCluster(cl)
    registerDoSEQ()
    cat("✓ Parallel processing cleanup completed\n")
  }, error = function(e) {
    cat("Note: Parallel cluster was already stopped\n")
  })
}

# ============================================================================
# SUMMARY
# ============================================================================

cat("\n╔════════════════════════════════════════════════════════════════╗\n")
cat("║                    ANALYSIS COMPLETE                          ║\n")
cat("╚════════════════════════════════════════════════════════════════╝\n\n")

cat("Pipeline Summary:\n")
cat("  Tuning approach:", USE_TUNING, "\n")
cat("  Output directories:\n")
cat("    - models/      : Trained models and tuning results\n")
cat("    - outputs/     : Prediction rasters and CSV files\n")
cat("    - plots/       : Visualizations and maps\n")
cat("    - data/        : Processed datasets\n\n")

if (USE_TUNING != "none") {
  cat("Hyperparameter Tuning Results:\n")
  if (file.exists("models/hyperparameter_tuning_summary.csv")) {
    tuning_summary <- read.csv("models/hyperparameter_tuning_summary.csv")
    print(tuning_summary[, c("Model", "Best_RMSE", "N_Evaluations")])
  }
  cat("\n")
}

cat("Key Outputs:\n")
if (file.exists("models/tuning_comparison_results.csv")) {
  cat("  ✓ Tuning comparison: models/tuning_comparison_results.csv\n")
}
if (file.exists("plots/tuning_comparison_rmse.png")) {
  cat("  ✓ Performance plots: plots/tuning_comparison_*.png\n")
}
if (file.exists("outputs/ensemble_prediction.tif")) {
  cat("  ✓ Ensemble prediction: outputs/ensemble_prediction.tif\n")
}
if (file.exists("outputs/prediction_uncertainty.tif")) {
  cat("  ✓ Uncertainty map: outputs/prediction_uncertainty.tif\n")
}

cat("\nNext Steps:\n")
cat("  1. Review tuning results in models/hyperparameter_tuning_summary.csv\n")
cat("  2. Examine performance plots in plots/\n")
cat("  3. Analyze prediction maps in outputs/\n")
cat("  4. Check the final report in outputs/\n\n")

cat("Thank you for using the SOC Prediction Pipeline!\n\n")
