# compare_tuning_results.R
# Compare performance before and after hyperparameter tuning

library(ggplot2)

cat("\n=== HYPERPARAMETER TUNING COMPARISON ===\n\n")

# ============================================================================
# LOAD RESULTS
# ============================================================================

# Check if tuning results exist
tuning_exists <- file.exists("models/hyperparameter_tuning_summary.csv")
cv_exists <- file.exists("models/svm_cv.RDS")

if (!tuning_exists) {
  stop("Tuning results not found. Please run hyperparameter tuning first.")
}

if (!cv_exists) {
  stop("Cross-validation results not found. Please run module 04 first.")
}

# Load tuning summary
tuning_summary <- read.csv("models/hyperparameter_tuning_summary.csv", stringsAsFactors = FALSE)

# Load CV results (after tuning)
svm_cv <- readRDS("models/svm_cv.RDS")
ann_cv <- readRDS("models/ann_cv.RDS")
rf_cv <- readRDS("models/rf_cv.RDS")
xgb_cv <- readRDS("models/xgb_cv.RDS")

# ============================================================================
# EXTRACT PERFORMANCE METRICS
# ============================================================================

# Function to safely extract metrics
get_metric <- function(cv_result, metric_name, default_value = NA) {
  if (!is.null(cv_result$results) && metric_name %in% names(cv_result$results)) {
    return(cv_result$results[[metric_name]])
  }
  return(default_value)
}

# Create comparison data frame
comparison <- data.frame(
  Model = c("SVM", "ANN", "Random Forest", "XGBoost"),
  Tuning_RMSE = c(
    tuning_summary$Best_RMSE[tuning_summary$Model == "SVM"],
    tuning_summary$Best_RMSE[tuning_summary$Model == "ANN"],
    tuning_summary$Best_RMSE[tuning_summary$Model == "Random Forest"],
    tuning_summary$Best_RMSE[tuning_summary$Model == "XGBoost"]
  ),
  CV_RMSE = c(
    get_metric(svm_cv, "regr.rmse"),
    get_metric(ann_cv, "regr.rmse"),
    get_metric(rf_cv, "regr.rmse"),
    get_metric(xgb_cv, "regr.rmse")
  ),
  CV_MAE = c(
    get_metric(svm_cv, "regr.mae"),
    get_metric(ann_cv, "regr.mae"),
    get_metric(rf_cv, "regr.mae"),
    get_metric(xgb_cv, "regr.mae")
  ),
  CV_R2 = c(
    get_metric(svm_cv, "regr.rsq"),
    get_metric(ann_cv, "regr.rsq"),
    get_metric(rf_cv, "regr.rsq"),
    get_metric(xgb_cv, "regr.rsq")
  ),
  stringsAsFactors = FALSE
)

# ============================================================================
# DISPLAY RESULTS
# ============================================================================

cat("Performance Comparison:\n")
cat("======================\n\n")

# Print formatted table
cat(sprintf("%-15s | %12s | %12s | %12s | %12s\n",
            "Model", "Tuning RMSE", "CV RMSE", "CV MAE", "CV R²"))
cat(paste(rep("-", 80), collapse = ""), "\n")

for (i in 1:nrow(comparison)) {
  cat(sprintf("%-15s | %12.4f | %12.4f | %12.4f | %12.4f\n",
              comparison$Model[i],
              comparison$Tuning_RMSE[i],
              comparison$CV_RMSE[i],
              comparison$CV_MAE[i],
              comparison$CV_R2[i]))
}

cat("\n")

# Calculate performance improvement (if baseline exists)
baseline_file <- "models/baseline_performance.csv"
if (file.exists(baseline_file)) {
  baseline <- read.csv(baseline_file, stringsAsFactors = FALSE)

  cat("\nPerformance Improvement from Baseline:\n")
  cat("======================================\n\n")

  for (i in 1:nrow(comparison)) {
    model_name <- comparison$Model[i]
    baseline_rmse <- baseline$RMSE[baseline$Model == model_name]

    if (length(baseline_rmse) > 0 && !is.na(baseline_rmse)) {
      tuned_rmse <- comparison$CV_RMSE[i]
      improvement <- ((baseline_rmse - tuned_rmse) / baseline_rmse) * 100

      cat(sprintf("%s:\n", model_name))
      cat(sprintf("  Baseline RMSE: %.4f\n", baseline_rmse))
      cat(sprintf("  Tuned RMSE:    %.4f\n", tuned_rmse))
      cat(sprintf("  Improvement:   %.2f%%\n\n", improvement))
    }
  }
} else {
  cat("\nNote: No baseline performance file found.\n")
  cat("To track improvement, save current non-tuned results as:\n")
  cat("  models/baseline_performance.csv\n\n")
}

# ============================================================================
# IDENTIFY BEST MODEL
# ============================================================================

best_model_idx <- which.min(comparison$CV_RMSE)
best_model <- comparison$Model[best_model_idx]
best_rmse <- comparison$CV_RMSE[best_model_idx]
best_r2 <- comparison$CV_R2[best_model_idx]

cat("\n=== BEST PERFORMING MODEL ===\n")
cat(sprintf("Model: %s\n", best_model))
cat(sprintf("RMSE:  %.4f\n", best_rmse))
cat(sprintf("MAE:   %.4f\n", comparison$CV_MAE[best_model_idx]))
cat(sprintf("R²:    %.4f\n", best_r2))

# ============================================================================
# CREATE VISUALIZATION
# ============================================================================

cat("\n=== CREATING COMPARISON PLOTS ===\n")

# Ensure plots directory exists
if (!dir.exists("plots")) {
  dir.create("plots")
}

# Prepare data for plotting
plot_data <- comparison[, c("Model", "Tuning_RMSE", "CV_RMSE")]
plot_data_long <- data.frame(
  Model = rep(plot_data$Model, 2),
  Stage = rep(c("During Tuning", "Final CV"), each = nrow(plot_data)),
  RMSE = c(plot_data$Tuning_RMSE, plot_data$CV_RMSE)
)

# Plot 1: RMSE Comparison
p1 <- ggplot(plot_data_long, aes(x = Model, y = RMSE, fill = Stage)) +
  geom_bar(stat = "identity", position = "dodge", width = 0.7) +
  geom_text(aes(label = sprintf("%.3f", RMSE)),
            position = position_dodge(width = 0.7),
            vjust = -0.5, size = 3.5) +
  scale_fill_manual(values = c("During Tuning" = "steelblue", "Final CV" = "darkgreen")) +
  labs(
    title = "Model Performance: Tuning vs Final Cross-Validation",
    subtitle = "Lower RMSE indicates better performance",
    x = "Model",
    y = "RMSE (Root Mean Square Error)",
    fill = "Evaluation Stage"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 11),
    axis.title = element_text(size = 11),
    axis.text = element_text(size = 10),
    axis.text.x = element_text(angle = 0),
    legend.position = "bottom"
  )

ggsave(
  "plots/tuning_comparison_rmse.png",
  plot = p1,
  width = 10,
  height = 6,
  dpi = 300
)

cat("Saved: plots/tuning_comparison_rmse.png\n")

# Plot 2: R² Comparison
p2 <- ggplot(comparison, aes(x = reorder(Model, CV_R2), y = CV_R2)) +
  geom_bar(stat = "identity", fill = "steelblue", width = 0.6) +
  geom_text(aes(label = sprintf("%.3f", CV_R2)), vjust = -0.5, size = 4) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  labs(
    title = "Model Performance: R² Scores",
    subtitle = "Higher R² indicates better predictive power (closer to 1 is better)",
    x = "Model",
    y = "R² (Coefficient of Determination)"
  ) +
  ylim(0, max(comparison$CV_R2, na.rm = TRUE) * 1.1) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 11),
    axis.title = element_text(size = 11),
    axis.text = element_text(size = 10)
  )

ggsave(
  "plots/tuning_comparison_r2.png",
  plot = p2,
  width = 10,
  height = 6,
  dpi = 300
)

cat("Saved: plots/tuning_comparison_r2.png\n")

# Plot 3: Multi-metric comparison
metrics_long <- data.frame(
  Model = rep(comparison$Model, 3),
  Metric = rep(c("RMSE", "MAE", "R²"), each = nrow(comparison)),
  Value = c(comparison$CV_RMSE, comparison$CV_MAE, comparison$CV_R2)
)

# Normalize metrics to 0-1 scale for comparison
metrics_long$Value_normalized <- NA
for (metric in unique(metrics_long$Metric)) {
  idx <- metrics_long$Metric == metric
  values <- metrics_long$Value[idx]

  if (metric == "R²") {
    # For R², higher is better, so keep as is (assuming 0-1 range)
    metrics_long$Value_normalized[idx] <- values
  } else {
    # For RMSE and MAE, lower is better, so invert
    metrics_long$Value_normalized[idx] <- 1 - (values - min(values, na.rm = TRUE)) /
      (max(values, na.rm = TRUE) - min(values, na.rm = TRUE))
  }
}

p3 <- ggplot(metrics_long, aes(x = Model, y = Value_normalized, fill = Metric)) +
  geom_bar(stat = "identity", position = "dodge", width = 0.7) +
  scale_fill_brewer(palette = "Set2") +
  labs(
    title = "Multi-Metric Model Comparison (Normalized)",
    subtitle = "All metrics scaled to 0-1, higher is better",
    x = "Model",
    y = "Normalized Performance (higher is better)",
    fill = "Metric"
  ) +
  ylim(0, 1) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 11),
    axis.title = element_text(size = 11),
    axis.text = element_text(size = 10),
    legend.position = "bottom"
  )

ggsave(
  "plots/tuning_comparison_multimetric.png",
  plot = p3,
  width = 10,
  height = 6,
  dpi = 300
)

cat("Saved: plots/tuning_comparison_multimetric.png\n")

# ============================================================================
# SAVE COMPARISON RESULTS
# ============================================================================

write.csv(comparison, "models/tuning_comparison_results.csv", row.names = FALSE)
cat("\nComparison results saved to: models/tuning_comparison_results.csv\n")

# ============================================================================
# PRINT HYPERPARAMETER DETAILS
# ============================================================================

cat("\n=== OPTIMIZED HYPERPARAMETERS ===\n\n")

for (i in 1:nrow(tuning_summary)) {
  cat(sprintf("%s:\n", tuning_summary$Model[i]))
  cat(sprintf("  %s\n", tuning_summary$Parameters[i]))
  cat(sprintf("  Evaluations: %d\n", tuning_summary$N_Evaluations[i]))
  cat(sprintf("  Strategy: %s\n\n", tuning_summary$Strategy[i]))
}

cat("\n=== COMPARISON COMPLETE ===\n")
cat("Review the plots in the plots/ directory for visual comparison\n")
