# 08_evaluation_and_report.R

library(ggplot2)

# Load data and models
svm_cv <- readRDS("models/svm_cv.RDS")
ann_cv <- readRDS("models/ann_cv.RDS")
rf_cv <- readRDS("models/rf_cv.RDS")
xgb_cv <- readRDS("models/xgb_cv.RDS")
weights <- readRDS("models/ensemble_weights.RDS")
task_motupe_scaled <- readRDS("data/task_motupe_scaled.RDS")
covsoc_for_modeling <- readRDS("data/covsoc_for_modeling.RDS")
svm_metrics <- readRDS("models/svm_metrics.RDS")
ann_metrics <- readRDS("models/ann_metrics.RDS")
rf_metrics <- readRDS("models/rf_metrics.RDS")
xgb_metrics <- readRDS("models/xgb_metrics.RDS")

# 13. Calculate performance metrics for ensemble models on training data
svm_model_final <- svm_cv$model
ann_model_final <- ann_cv$model
rf_model_final <- rf_cv$model
xgb_model_final <- xgb_cv$model

svm_pred <- svm_model_final$predict(task_motupe_scaled)$response
ann_pred <- ann_model_final$predict(task_motupe_scaled)$response
rf_pred <- rf_model_final$predict(task_motupe_scaled)$response
xgb_pred <- xgb_model_final$predict(task_motupe_scaled)$response

actual <- task_motupe_scaled$data()$SOC

# --- DEBUGGING START ---
cat("\n--- Debugging Info ---\n")
cat("Length of svm_pred:", length(svm_pred), "\n")
cat("Length of ann_pred:", length(ann_pred), "\n")
cat("Length of rf_pred:", length(rf_pred), "\n")
cat("Length of xgb_pred:", length(xgb_pred), "\n")
cat("Structure of weights object:\n")
print(str(weights))
cat("--- End Debugging Info ---\n\n")
# --- DEBUGGING END ---

ensemble_avg_pred <- (svm_pred + ann_pred + rf_pred + xgb_pred) / 4

cat("Calculating ensemble_weighted_pred...\n")
ensemble_weighted_pred <- (weights$svm * svm_pred) + (weights$ann * ann_pred) + (weights$rf * rf_pred) + (weights$xgb * xgb_pred)
cat("...calculation of ensemble_weighted_pred complete.\n")


ensemble_avg_rmse <- sqrt(mean((actual - ensemble_avg_pred)^2))
ensemble_weighted_rmse <- sqrt(mean((actual - ensemble_weighted_pred)^2))

ensemble_avg_mae <- mean(abs(actual - ensemble_avg_pred))
ensemble_weighted_mae <- mean(abs(actual - ensemble_weighted_pred))

ss_total <- sum((actual - mean(actual))^2)
ensemble_avg_ss_residual <- sum((actual - ensemble_avg_pred)^2)
ensemble_weighted_ss_residual <- sum((actual - ensemble_weighted_pred)^2)

ensemble_avg_r2 <- 1 - (ensemble_avg_ss_residual / ss_total)
ensemble_weighted_r2 <- 1 - (ensemble_weighted_ss_residual / ss_total)

ensemble_avg_r2 <- max(0, min(1, ensemble_avg_r2))
ensemble_weighted_r2 <- max(0, min(1, ensemble_weighted_r2))

# 13.1 Create comparison table
model_comparison <- data.frame(
  Model = c("SVM", "ANN", "Random Forest", "XGBoost",
            "Ensemble (Average)", "Ensemble (Weighted)"),
  RMSE = c(svm_metrics$RMSE, ann_metrics$RMSE, rf_metrics$RMSE, xgb_metrics$RMSE,
           ensemble_avg_rmse, ensemble_weighted_rmse),
  MAE = c(svm_metrics$MAE, ann_metrics$MAE, rf_metrics$MAE, xgb_metrics$MAE,
          ensemble_avg_mae, ensemble_weighted_mae),
  R2 = c(svm_metrics$R2, ann_metrics$R2, rf_metrics$R2, xgb_metrics$R2,
         ensemble_avg_r2, ensemble_weighted_r2)
)

print(model_comparison)

if (!dir.exists("plots")) {
  dir.create("plots")
}

covsoc_for_modeling$svm_pred <- svm_pred
covsoc_for_modeling$ann_pred <- ann_pred
covsoc_for_modeling$rf_pred <- rf_pred
covsoc_for_modeling$xgb_pred <- xgb_pred
covsoc_for_modeling$ensemble_avg_pred <- ensemble_avg_pred
covsoc_for_modeling$ensemble_weighted_pred <- ensemble_weighted_pred

# Export observed vs predicted values to CSV files
if (!dir.exists("outputs")) {
  dir.create("outputs")
}

# Create data frames for each model with observed and predicted values
svm_data <- data.frame(
  Observed = actual,
  Predicted = svm_pred
)
write.csv(svm_data, "outputs/svm_observed_vs_predicted.csv", row.names = FALSE)

ann_data <- data.frame(
  Observed = actual,
  Predicted = ann_pred
)
write.csv(ann_data, "outputs/ann_observed_vs_predicted.csv", row.names = FALSE)

rf_data <- data.frame(
  Observed = actual,
  Predicted = rf_pred
)
write.csv(rf_data, "outputs/rf_observed_vs_predicted.csv", row.names = FALSE)

xgb_data <- data.frame(
  Observed = actual,
  Predicted = xgb_pred
)
write.csv(xgb_data, "outputs/xgb_observed_vs_predicted.csv", row.names = FALSE)

ensemble_avg_data <- data.frame(
  Observed = actual,
  Predicted = ensemble_avg_pred
)
write.csv(ensemble_avg_data, "outputs/ensemble_avg_observed_vs_predicted.csv", row.names = FALSE)

ensemble_weighted_data <- data.frame(
  Observed = actual,
  Predicted = ensemble_weighted_pred
)
write.csv(ensemble_weighted_data, "outputs/ensemble_weighted_observed_vs_predicted.csv", row.names = FALSE)

# Create combined CSV with all models
all_models_data <- data.frame(
  Observed = actual,
  SVM_Predicted = svm_pred,
  ANN_Predicted = ann_pred,
  RF_Predicted = rf_pred,
  XGBoost_Predicted = xgb_pred,
  Ensemble_Avg_Predicted = ensemble_avg_pred,
  Ensemble_Weighted_Predicted = ensemble_weighted_pred
)
write.csv(all_models_data, "outputs/all_models_observed_vs_predicted.csv", row.names = FALSE)

cat("Observed vs Predicted CSV files exported to outputs/ directory\n")

# Plots
cv_metrics_df <- data.frame(
  Model = c("SVM", "ANN", "Random Forest", "XGBoost"),
  RMSE = c(svm_metrics$RMSE, ann_metrics$RMSE, rf_metrics$RMSE, xgb_metrics$RMSE),
  MAE = c(svm_metrics$MAE, ann_metrics$MAE, rf_metrics$MAE, xgb_metrics$MAE),
  R2 = c(svm_metrics$R2, ann_metrics$R2, rf_metrics$R2, xgb_metrics$R2)
)

ggplot(cv_metrics_df, aes(x = reorder(Model, -RMSE), y = RMSE, fill = Model)) +
  geom_bar(stat = "identity", alpha = 0.8) +
  geom_text(aes(label = round(RMSE, 3)), vjust = -0.5, fontface = "bold") +
  scale_fill_manual(values = c("SVM" = "blue", "ANN" = "red", 
                              "Random Forest" = "green", "XGBoost" = "purple")) +
  labs(title = "Spatial Cross-Validation: RMSE Comparison",
       subtitle = "Lower values indicate better performance",
       x = "Model", y = "RMSE") +
  theme_minimal() +
  theme(legend.position = "none")
ggsave("plots/spatial_cv_rmse_comparison.png", width = 10, height = 6, dpi = 300)

ggplot(cv_metrics_df, aes(x = reorder(Model, R2), y = R2, fill = Model)) +
  geom_bar(stat = "identity", alpha = 0.8) +
  geom_text(aes(label = round(R2, 3)), vjust = -0.5, fontface = "bold") +
  scale_fill_manual(values = c("SVM" = "blue", "ANN" = "red", 
                              "Random Forest" = "green", "XGBoost" = "purple")) +
  labs(title = "Spatial Cross-Validation: R² Comparison",
       subtitle = "Higher values indicate better performance",
       x = "Model", y = "R²") +
  ylim(0, max(cv_metrics_df$R2, na.rm = TRUE) * 1.1) +
  theme_minimal() +
  theme(legend.position = "none")
ggsave("plots/spatial_cv_r2_comparison.png", width = 10, height = 6, dpi = 300)

# ---- Uncertainty Analysis Statistics ----
cat("Loading uncertainty analysis results...\n")

# Load uncertainty rasters from Module 07
uncertainty_files <- list(
  mean = "outputs/bootstrap_mean_spatial_cv.tif",
  stdev = "outputs/bootstrap_stdev_spatial_cv.tif", 
  cv = "outputs/bootstrap_cv_spatial_cv.tif",
  pi90_width = "outputs/bootstrap_pi90_width_spatial_cv.tif",
  pi90_relative = "outputs/bootstrap_pi90_relative_spatial_cv.tif",
  q05 = "outputs/bootstrap_q05_spatial_cv.tif",
  q95 = "outputs/bootstrap_q95_spatial_cv.tif"
)

# Calculate uncertainty statistics
uncertainty_stats <- data.frame()

for (i in seq_along(uncertainty_files)) {
  metric_name <- names(uncertainty_files)[i]
  file_path <- uncertainty_files[[i]]
  
  if (file.exists(file_path)) {
    tryCatch({
      # Load raster
      raster_data <- terra::rast(file_path)
      values_data <- terra::values(raster_data, na.rm = TRUE)
      
      if (length(values_data) > 0) {
        # Calculate comprehensive statistics
        stats_row <- data.frame(
          Metric = metric_name,
          Mean = round(mean(values_data, na.rm = TRUE), 4),
          Median = round(median(values_data, na.rm = TRUE), 4),
          StdDev = round(sd(values_data, na.rm = TRUE), 4),
          Min = round(min(values_data, na.rm = TRUE), 4),
          Max = round(max(values_data, na.rm = TRUE), 4),
          Q25 = round(quantile(values_data, 0.25, na.rm = TRUE), 4),
          Q75 = round(quantile(values_data, 0.75, na.rm = TRUE), 4),
          IQR = round(IQR(values_data, na.rm = TRUE), 4),
          CV_percent = round((sd(values_data, na.rm = TRUE) / mean(values_data, na.rm = TRUE)) * 100, 2),
          N_pixels = length(values_data),
          stringsAsFactors = FALSE
        )
        
        uncertainty_stats <- rbind(uncertainty_stats, stats_row)
      } else {
        cat("Warning: No valid values found in", file_path, "\n")
      }
    }, error = function(e) {
      cat("Error processing", file_path, ":", e$message, "\n")
    })
  } else {
    cat("Warning: File not found:", file_path, "\n")
  }
}

# Add additional derived metrics
if (nrow(uncertainty_stats) > 0) {
  # Calculate uncertainty quality metrics
  mean_row <- uncertainty_stats[uncertainty_stats$Metric == "mean", ]
  stdev_row <- uncertainty_stats[uncertainty_stats$Metric == "stdev", ]
  
  if (nrow(mean_row) > 0 && nrow(stdev_row) > 0) {
    # Signal-to-noise ratio
    snr <- mean_row$Mean / stdev_row$Mean
    
    # Add summary row
    summary_stats <- data.frame(
      Metric = "SUMMARY",
      Mean = round(mean_row$Mean, 4),  # Overall prediction mean
      Median = NA,
      StdDev = round(stdev_row$Mean, 4),  # Average uncertainty
      Min = NA,
      Max = NA,
      Q25 = NA,
      Q75 = NA,
      IQR = NA,
      CV_percent = round((stdev_row$Mean / mean_row$Mean) * 100, 2),  # Overall relative uncertainty
      N_pixels = mean_row$N_pixels,
      stringsAsFactors = FALSE
    )
    
    uncertainty_stats <- rbind(uncertainty_stats, summary_stats)
    
    cat("Signal-to-Noise Ratio (Mean/StdDev):", round(snr, 3), "\n")
    cat("Average Relative Uncertainty:", round((stdev_row$Mean / mean_row$Mean) * 100, 2), "%\n")
  }
}

# Export uncertainty statistics to CSV
if (nrow(uncertainty_stats) > 0) {
  write.csv(uncertainty_stats, "outputs/uncertainty_analysis_statistics.csv", row.names = FALSE)
  cat("Uncertainty statistics exported to: outputs/uncertainty_analysis_statistics.csv\n")
  
  # Print uncertainty summary
  cat("\n=== UNCERTAINTY ANALYSIS SUMMARY ===\n")
  print(uncertainty_stats)
  cat("=====================================\n\n")
} else {
  cat("Warning: No uncertainty statistics calculated\n")
}

# Report
cat("# Spatial Cross-Validation Ensemble Model Report\n\n",
    file = "outputs/spatial_cv_report.md")

cat("## Model Performance Metrics\n\n",
    file = "outputs/spatial_cv_report.md", append = TRUE)
cat("```\n", file = "outputs/spatial_cv_report.md", append = TRUE)
capture.output(print(model_comparison),
               file = "outputs/spatial_cv_report.md", append = TRUE)
cat("```\n\n", file = "outputs/spatial_cv_report.md", append = TRUE)

# Add uncertainty analysis section to report
if (nrow(uncertainty_stats) > 0) {
  cat("## Uncertainty Analysis Statistics\n\n",
      file = "outputs/spatial_cv_report.md", append = TRUE)
  cat("```\n", file = "outputs/spatial_cv_report.md", append = TRUE)
  capture.output(print(uncertainty_stats),
                 file = "outputs/spatial_cv_report.md", append = TRUE)
  cat("```\n\n", file = "outputs/spatial_cv_report.md", append = TRUE)
  
  cat("### Key Uncertainty Metrics\n\n",
      file = "outputs/spatial_cv_report.md", append = TRUE)
  
  # Extract key metrics for report
  mean_uncertainty <- uncertainty_stats[uncertainty_stats$Metric == "mean", "Mean"]
  avg_std <- uncertainty_stats[uncertainty_stats$Metric == "stdev", "Mean"]
  avg_cv <- uncertainty_stats[uncertainty_stats$Metric == "cv", "Mean"]
  
  if (length(mean_uncertainty) > 0) {
    cat(paste0("- **Average Prediction**: ", mean_uncertainty, " (SOC units)\n"),
        file = "outputs/spatial_cv_report.md", append = TRUE)
  }
  if (length(avg_std) > 0) {
    cat(paste0("- **Average Standard Deviation**: ", avg_std, " (SOC units)\n"),
        file = "outputs/spatial_cv_report.md", append = TRUE)
  }
  if (length(avg_cv) > 0) {
    cat(paste0("- **Average Coefficient of Variation**: ", avg_cv, "%\n"),
        file = "outputs/spatial_cv_report.md", append = TRUE)
  }
  
  cat("\n", file = "outputs/spatial_cv_report.md", append = TRUE)
}

# Metrics objects for ensemble plots
ensemble_avg_metrics <- list(RMSE = ensemble_avg_rmse, MAE = ensemble_avg_mae, R2 = ensemble_avg_r2)
ensemble_weighted_metrics <- list(RMSE = ensemble_weighted_rmse, MAE = ensemble_weighted_mae, R2 = ensemble_weighted_r2)

# ---- Observed vs Predicted scatter plots (with metrics) ----
plot_observed_vs_predicted <- function(df, actual_col, pred_col, model_name, metrics) {
  # Coerce to plain numeric data.frame to avoid list/sf column issues
  d <- data.frame(
    actual = as.numeric(df[[actual_col]]),
    pred   = as.numeric(df[[pred_col]])
  )
  # Remove NA/Inf
  d <- d[is.finite(d$actual) & is.finite(d$pred), , drop = FALSE]

  label_txt <- paste0(
    "RMSE: ", round(metrics$RMSE, 3),
    "\nMAE: ", round(metrics$MAE, 3),
    "\nR²: ", round(metrics$R2, 3)
  )

  p <- ggplot(d, aes(x = actual, y = pred)) +
    geom_point(alpha = 0.6) +
    geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "red") +
    labs(
      title = paste0(model_name, ": Observed vs Predicted SOC"),
      x = "Observed SOC",
      y = "Predicted SOC"
    ) +
    theme_minimal() +
    # Place metrics at upper-left
    annotate(
      "text",
      x = min(d$actual, na.rm = TRUE),
      y = max(d$pred,   na.rm = TRUE),
      hjust = 0, vjust = 1,
      label = label_txt,
      fontface = "bold", size = 4
    )

  out_name <- paste0(
    "plots/",
    tolower(gsub("[^A-Za-z0-9]+", "_", model_name)),
    "_observed_vs_predicted.png"
  )
  ggsave(out_name, plot = p, width = 8, height = 6, dpi = 300)
  p
}

# Generate and save plots
plot_observed_vs_predicted(covsoc_for_modeling, "SOC", "svm_pred", "SVM", svm_metrics)
plot_observed_vs_predicted(covsoc_for_modeling, "SOC", "ann_pred", "ANN", ann_metrics)
plot_observed_vs_predicted(covsoc_for_modeling, "SOC", "rf_pred", "Random Forest", rf_metrics)
plot_observed_vs_predicted(covsoc_for_modeling, "SOC", "xgb_pred", "XGBoost", xgb_metrics)
plot_observed_vs_predicted(covsoc_for_modeling, "SOC", "ensemble_avg_pred", "Ensemble Average", ensemble_avg_metrics)
plot_observed_vs_predicted(covsoc_for_modeling, "SOC", "ensemble_weighted_pred", "Ensemble Weighted", ensemble_weighted_metrics)

# ---- Random Forest Feature Importance (Impurity) ----
get_rf_impurity_importance <- function(learner, task) {
  # Try mlr3 importance() if available
  imp <- tryCatch(learner$importance(), error = function(e) NULL)
  if (!is.null(imp)) return(imp)

  # Try underlying model variable.importance (e.g., ranger)
  m <- tryCatch(learner$model, error = function(e) NULL)
  vi <- tryCatch({
    if (!is.null(m) && !is.null(m$variable.importance)) m$variable.importance else NULL
  }, error = function(e) NULL)
  if (!is.null(vi)) return(vi)

  # Fallback: refit a quick ranger model with impurity importance (if package present)
  if (requireNamespace("ranger", quietly = TRUE)) {
    df <- task$data()
    f <- stats::as.formula(paste(task$target_names, "~ ."))
    rf_fit <- ranger::ranger(f, data = df, importance = "impurity", num.trees = 500, write.forest = FALSE)
    return(rf_fit$variable.importance)
  }

  warning("Could not derive Random Forest impurity importance (ranger not available and learner/model lacks importance).")
  NULL
}

rf_imp <- get_rf_impurity_importance(rf_model_final, task_motupe_scaled)
if (!is.null(rf_imp)) {
  rf_importance_df <- data.frame(
    feature = names(rf_imp),
    importance = as.numeric(rf_imp),
    row.names = NULL
  )

  p_imp <- ggplot(rf_importance_df, aes(x = reorder(feature, importance), y = importance)) +
    geom_bar(stat = "identity", fill = "#2E86AB") +
    coord_flip() +
    labs(
      title = "",
      subtitle = "",
      x = "Feature",
      y = "Importance"
    ) +
    theme_minimal() +
    theme(
      legend.position = "none",
      axis.text.x = element_text(size = 16),
      axis.text.y = element_text(size = 16),
      axis.title.x = element_text(size = 16, face = "bold"),
      axis.title.y = element_text(size = 16, face = "bold")
    )

  ggsave("plots/rf_feature_importance_impurity.png", plot = p_imp, width = 10, height = 8, dpi = 300)
}
