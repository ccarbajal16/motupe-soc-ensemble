# check_progress.R
# Diagnostic script to check which modules have been completed
# and what you need to run

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  PIPELINE PROGRESS CHECKER\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Define all expected files by module
files_by_module <- list(
  "Module 02: Preprocessing" = c(
    "data/task_motupe_scaled.RDS",
    "models/po_scale.RDS",
    "data/covariates_with_xy.RDS",
    "data/motupe.RDS",
    "data/covsoc_for_modeling.RDS"
  ),
  "Module 03: Model Definition/Tuning" = c(
    "models/svm_model.RDS",
    "models/ann_model.RDS",
    "models/rf_model.RDS",
    "models/xgb_model.RDS"
  ),
  "Module 03: Tuning Results (Optional)" = c(
    "models/svm_tuning_results.RDS",
    "models/ann_tuning_results.RDS",
    "models/rf_tuning_results.RDS",
    "models/xgb_tuning_results.RDS",
    "models/hyperparameter_tuning_summary.csv"
  ),
  "Module 04: Spatial CV" = c(
    "models/svm_cv.RDS",
    "models/ann_cv.RDS",
    "models/rf_cv.RDS",
    "models/xgb_cv.RDS"
  ),
  "Module 05: Ensemble" = c(
    "models/ensemble_weights.RDS",
    "models/svm_metrics.RDS",
    "models/ann_metrics.RDS",
    "models/rf_metrics.RDS",
    "models/xgb_metrics.RDS"
  ),
  "Module 06: Prediction" = c(
    "outputs/svm_prediction.tif",
    "outputs/ann_prediction.tif",
    "outputs/rf_prediction.tif",
    "outputs/xgb_prediction.tif",
    "outputs/ensemble_prediction.tif",
    "data/all_covariates_scaled_imputed.RDS"
  ),
  "Module 07: Uncertainty" = c(
    "outputs/prediction_uncertainty.tif"
  ),
  "Module 08: Evaluation & Report" = c(
    "plots/spatial_cv_partitioning_map.png"
  )
)

# Check each module
results <- list()
all_complete <- TRUE

for (module_name in names(files_by_module)) {
  files <- files_by_module[[module_name]]
  exists_count <- sum(file.exists(files))
  total_count <- length(files)
  is_complete <- exists_count == total_count

  results[[module_name]] <- list(
    exists = exists_count,
    total = total_count,
    complete = is_complete,
    missing = files[!file.exists(files)]
  )

  if (!is_complete && !grepl("Optional", module_name)) {
    all_complete <- FALSE
  }
}

# Display results
cat("MODULE STATUS:\n")
cat("══════════════════════════════════════════════════════════════\n\n")

for (module_name in names(results)) {
  result <- results[[module_name]]

  # Determine status symbol
  if (result$complete) {
    status <- "✓ COMPLETE"
    symbol <- "✓"
  } else if (result$exists > 0) {
    status <- "⚠ PARTIAL"
    symbol <- "⚠"
  } else {
    status <- "✗ NOT RUN"
    symbol <- "✗"
  }

  # Print module status
  cat(sprintf("%s %s\n", symbol, module_name))
  cat(sprintf("   Status: %s (%d/%d files)\n",
              status, result$exists, result$total))

  # Show missing files if incomplete
  if (!result$complete && length(result$missing) > 0) {
    cat("   Missing:\n")
    for (missing_file in result$missing) {
      cat(sprintf("     - %s\n", missing_file))
    }
  }

  cat("\n")
}

# Overall summary
cat("═══════════════════════════════════════════════════════════════\n")
cat("OVERALL SUMMARY:\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Check if tuning was used
tuning_used <- results[["Module 03: Tuning Results (Optional)"]]$complete

if (all_complete && tuning_used) {
  cat("✓ Complete pipeline with hyperparameter tuning\n")
  cat("  All modules have been executed successfully!\n\n")
} else if (all_complete) {
  cat("✓ Complete pipeline without hyperparameter tuning\n")
  cat("  All modules have been executed successfully!\n\n")
} else {
  cat("⚠ Pipeline incomplete\n\n")
}

# Provide recommendations
cat("═══════════════════════════════════════════════════════════════\n")
cat("RECOMMENDATIONS:\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Determine what to recommend
if (all_complete && tuning_used) {
  cat("Your pipeline is complete with hyperparameter tuning.\n\n")
  cat("Options:\n")
  cat("1. Improve tuning settings:\n")
  cat("   - Edit modules/03_model_tuning_advanced.R\n")
  cat("   - Increase N_EVALS_* values for better optimization\n")
  cat("   - Run: Rscript modules/03_model_tuning_advanced.R\n")
  cat("   - Then: Rscript modules/04_spatial_cv.R onwards\n\n")
  cat("2. Try different tuning strategy:\n")
  cat("   - Change TUNING_STRATEGY in modules/03_model_tuning_advanced.R\n")
  cat("   - Options: 'grid_search', 'random_search', 'bayesian'\n\n")
  cat("3. Regenerate visualizations:\n")
  cat("   - Run: Rscript modules/compare_tuning_results.R\n\n")

} else if (all_complete && !tuning_used) {
  cat("Your pipeline is complete but WITHOUT hyperparameter tuning.\n\n")
  cat("RECOMMENDED: Add hyperparameter tuning for better performance!\n\n")
  cat("Quick start:\n")
  cat("   Rscript modules/03_model_tuning_advanced.R\n")
  cat("   Rscript modules/04_spatial_cv.R\n")
  cat("   Rscript modules/05_ensemble.R\n")
  cat("   Rscript modules/06_prediction.R\n")
  cat("   Rscript modules/compare_tuning_results.R\n\n")
  cat("Or run complete pipeline with tuning:\n")
  cat("   Rscript main_with_tuning.R\n\n")

} else if (results[["Module 02: Preprocessing"]]$complete) {
  cat("Preprocessing is complete. You can start from model tuning.\n\n")
  cat("Next steps:\n")
  cat("1. Run hyperparameter tuning:\n")
  cat("   Rscript modules/03_model_tuning_advanced.R\n\n")
  cat("2. Continue with rest of pipeline:\n")
  cat("   Rscript modules/04_spatial_cv.R\n")
  cat("   Rscript modules/05_ensemble.R\n")
  cat("   Rscript modules/06_prediction.R\n")
  cat("   Rscript modules/07_uncertainty.R\n")
  cat("   Rscript modules/08_evaluation_and_report.R\n")
  cat("   Rscript modules/compare_tuning_results.R\n\n")

} else {
  cat("Pipeline needs to be run from the beginning.\n\n")
  cat("RECOMMENDED: Run complete pipeline with tuning:\n")
  cat("   Rscript main_with_tuning.R\n\n")
  cat("Or run modules individually:\n")
  cat("   Rscript modules/01_setup_and_load.R\n")
  cat("   Rscript modules/02_preprocessing.R\n")
  cat("   Rscript modules/03_model_tuning_advanced.R\n")
  cat("   ... (and so on)\n\n")
}

# Time estimates
cat("═══════════════════════════════════════════════════════════════\n")
cat("TIME ESTIMATES:\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

if (results[["Module 02: Preprocessing"]]$complete) {
  cat("Starting from hyperparameter tuning:\n")
  cat("  - With default settings: ~2-4 hours\n")
  cat("  - With quick settings:   ~1-2 hours\n")
  cat("    (Reduce N_EVALS in module 03)\n\n")
} else {
  cat("Complete pipeline from scratch:\n")
  cat("  - With hyperparameter tuning: ~3-6 hours\n")
  cat("  - Without tuning:             ~1-2 hours\n\n")
}

# Show file sizes if available
cat("═══════════════════════════════════════════════════════════════\n")
cat("DISK USAGE:\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

dirs_to_check <- c("data", "models", "outputs", "plots")
for (dir_name in dirs_to_check) {
  if (dir.exists(dir_name)) {
    files <- list.files(dir_name, recursive = TRUE, full.names = TRUE)
    if (length(files) > 0) {
      sizes <- file.info(files)$size
      total_mb <- sum(sizes, na.rm = TRUE) / (1024^2)
      cat(sprintf("%s/: %d files, %.2f MB\n", dir_name, length(files), total_mb))
    } else {
      cat(sprintf("%s/: Empty\n", dir_name))
    }
  } else {
    cat(sprintf("%s/: Does not exist\n", dir_name))
  }
}

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("For detailed information, see:\n")
cat("  - MODULE_DEPENDENCIES.md\n")
cat("  - QUICK_START_TUNING.md\n")
cat("  - HYPERPARAMETER_TUNING_GUIDE.md\n")
cat("═══════════════════════════════════════════════════════════════\n\n")
