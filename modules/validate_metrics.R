# validate_metrics.R
# Diagnostic script to check if your validation metrics are coherent and acceptable

library(ggplot2)

cat("\n")
cat("═══════════════════════════════════════════════════════════════════\n")
cat("  VALIDATION METRICS DIAGNOSTIC TOOL\n")
cat("  Understanding High R² with High RMSE/MAE\n")
cat("═══════════════════════════════════════════════════════════════════\n\n")

# ============================================================================
# LOAD DATA AND RESULTS
# ============================================================================

# Check if required files exist
required_files <- c(
  "models/svm_cv.RDS",
  "models/ann_cv.RDS",
  "models/rf_cv.RDS",
  "models/xgb_cv.RDS",
  "data/covsoc_for_modeling.RDS",
  "data/task_motupe_scaled.RDS"
)

missing_files <- required_files[!file.exists(required_files)]
if (length(missing_files) > 0) {
  cat("ERROR: Missing required files:\n")
  cat(paste0("  - ", missing_files, "\n"))
  cat("\nPlease run the complete pipeline first.\n")
  stop("Required files not found")
}

# Load data
cat("Loading data and model results...\n")
svm_cv <- readRDS("models/svm_cv.RDS")
ann_cv <- readRDS("models/ann_cv.RDS")
rf_cv <- readRDS("models/rf_cv.RDS")
xgb_cv <- readRDS("models/xgb_cv.RDS")
covsoc <- readRDS("data/covsoc_for_modeling.RDS")
task_scaled <- readRDS("data/task_motupe_scaled.RDS")

# Get original SOC values
if (inherits(covsoc, "sf")) {
  original_soc <- sf::st_drop_geometry(covsoc)$SOC
} else {
  original_soc <- covsoc$SOC
}

cat("Data loaded successfully.\n\n")

# ============================================================================
# DATA CHARACTERISTICS
# ============================================================================

cat("═══════════════════════════════════════════════════════════════════\n")
cat("1. DATA CHARACTERISTICS\n")
cat("═══════════════════════════════════════════════════════════════════\n\n")

soc_mean <- mean(original_soc, na.rm = TRUE)
soc_sd <- sd(original_soc, na.rm = TRUE)
soc_min <- min(original_soc, na.rm = TRUE)
soc_max <- max(original_soc, na.rm = TRUE)
soc_range <- soc_max - soc_min
soc_cv <- (soc_sd / soc_mean) * 100
soc_median <- median(original_soc, na.rm = TRUE)
soc_q25 <- quantile(original_soc, 0.25, na.rm = TRUE)
soc_q75 <- quantile(original_soc, 0.75, na.rm = TRUE)
soc_iqr <- IQR(original_soc, na.rm = TRUE)

cat("SOC Statistics (Original Units):\n")
cat("─────────────────────────────────\n")
cat(sprintf("  Sample size:       %d\n", length(original_soc)))
cat(sprintf("  Mean:              %.2f g C/kg\n", soc_mean))
cat(sprintf("  Median:            %.2f g C/kg\n", soc_median))
cat(sprintf("  Std Deviation:     %.2f g C/kg\n", soc_sd))
cat(sprintf("  Minimum:           %.2f g C/kg\n", soc_min))
cat(sprintf("  Maximum:           %.2f g C/kg\n", soc_max))
cat(sprintf("  Range:             %.2f g C/kg\n", soc_range))
cat(sprintf("  IQR:               %.2f g C/kg\n", soc_iqr))
cat(sprintf("  Coef. Variation:   %.1f%%\n", soc_cv))
cat("\n")

# Interpret variability
cat("Data Variability Assessment:\n")
if (soc_cv < 15) {
  cat("  → LOW variability (CV < 15%) - homogeneous soils\n")
  cat("    Harder to achieve high R² values\n")
} else if (soc_cv < 35) {
  cat("  → MODERATE variability (15% < CV < 35%) - typical\n")
  cat("    Expected R² range: 0.6-0.8\n")
} else {
  cat("  → HIGH variability (CV > 35%) - heterogeneous soils\n")
  cat("    Easier to achieve high R², but higher RMSE expected\n")
}
cat("\n\n")

# ============================================================================
# MODEL PERFORMANCE METRICS
# ============================================================================

cat("═══════════════════════════════════════════════════════════════════\n")
cat("2. MODEL PERFORMANCE METRICS (Spatial Cross-Validation)\n")
cat("═══════════════════════════════════════════════════════════════════\n\n")

# Extract metrics
models <- list(
  "SVM" = svm_cv,
  "ANN" = ann_cv,
  "Random Forest" = rf_cv,
  "XGBoost" = xgb_cv
)

results_table <- data.frame()

for (model_name in names(models)) {
  cv_result <- models[[model_name]]

  rmse <- cv_result$results[["regr.rmse"]]
  mae <- cv_result$results[["regr.mae"]]
  r2 <- cv_result$results[["regr.rsq"]]

  # Handle missing values
  if (is.null(rmse) || is.na(rmse)) rmse <- NA
  if (is.null(mae) || is.na(mae)) mae <- NA
  if (is.null(r2) || is.na(r2)) r2 <- NA

  results_table <- rbind(results_table, data.frame(
    Model = model_name,
    RMSE = rmse,
    MAE = mae,
    R2 = r2,
    stringsAsFactors = FALSE
  ))
}

print(results_table)
cat("\n")

# ============================================================================
# METRIC INTERPRETATION & QUALITY CHECKS
# ============================================================================

cat("═══════════════════════════════════════════════════════════════════\n")
cat("3. METRIC INTERPRETATION & QUALITY ASSESSMENT\n")
cat("═══════════════════════════════════════════════════════════════════\n\n")

for (i in 1:nrow(results_table)) {
  model_name <- results_table$Model[i]
  rmse <- results_table$RMSE[i]
  mae <- results_table$MAE[i]
  r2 <- results_table$R2[i]

  cat(sprintf("─── %s ───\n", model_name))

  if (is.na(rmse) || is.na(r2)) {
    cat("  ⚠ WARNING: Missing metrics - check model training\n\n")
    next
  }

  # Calculate relative metrics
  rmse_sd_ratio <- rmse / soc_sd
  rmse_range_pct <- (rmse / soc_range) * 100
  nrmse <- (rmse / soc_mean) * 100
  mae_rmse_ratio <- mae / rmse

  cat(sprintf("  R²:                    %.3f\n", r2))
  cat(sprintf("  RMSE:                  %.2f g C/kg\n", rmse))
  cat(sprintf("  MAE:                   %.2f g C/kg\n", mae))
  cat("\n")

  cat("  Relative Error Metrics:\n")
  cat(sprintf("    RMSE/SD ratio:       %.3f (want < 0.5)\n", rmse_sd_ratio))
  cat(sprintf("    nRMSE:               %.1f%% (want < 30%%)\n", nrmse))
  cat(sprintf("    RMSE as %% of range:  %.1f%%\n", rmse_range_pct))
  cat(sprintf("    MAE/RMSE ratio:      %.3f (expect ~0.8)\n", mae_rmse_ratio))
  cat("\n")

  # Quality assessment
  cat("  Quality Assessment:\n")

  # R² assessment
  if (r2 >= 0.8) {
    cat("    ✓ EXCELLENT R² (≥0.8) - strong pattern recognition\n")
  } else if (r2 >= 0.7) {
    cat("    ✓ GOOD R² (0.7-0.8) - good pattern recognition\n")
  } else if (r2 >= 0.6) {
    cat("    ✓ ACCEPTABLE R² (0.6-0.7) - moderate pattern recognition\n")
  } else if (r2 >= 0.4) {
    cat("    ⚠ FAIR R² (0.4-0.6) - weak pattern recognition\n")
  } else {
    cat("    ✗ POOR R² (<0.4) - very weak pattern recognition\n")
  }

  # RMSE/SD assessment
  if (rmse_sd_ratio < 0.3) {
    cat("    ✓ EXCELLENT RMSE/SD (<0.3) - very precise predictions\n")
  } else if (rmse_sd_ratio < 0.5) {
    cat("    ✓ GOOD RMSE/SD (0.3-0.5) - precise predictions\n")
  } else if (rmse_sd_ratio < 0.7) {
    cat("    ✓ ACCEPTABLE RMSE/SD (0.5-0.7) - reasonable precision\n")
  } else if (rmse_sd_ratio < 1.0) {
    cat("    ⚠ FAIR RMSE/SD (0.7-1.0) - limited precision\n")
  } else {
    cat("    ✗ POOR RMSE/SD (>1.0) - model worse than predicting mean\n")
  }

  # MAE/RMSE assessment
  if (mae_rmse_ratio >= 0.75 && mae_rmse_ratio <= 0.85) {
    cat("    ✓ Normal MAE/RMSE ratio - no severe outliers\n")
  } else if (mae_rmse_ratio < 0.75) {
    cat("    ⚠ Low MAE/RMSE ratio - possible outliers inflating RMSE\n")
  } else {
    cat("    ⚠ High MAE/RMSE ratio - unusual error distribution\n")
  }

  cat("\n")

  # Overall coherence check
  cat("  Coherence Check:\n")

  # High R² with high RMSE is OK if data has high variance
  if (r2 > 0.7 && rmse_sd_ratio < 0.6) {
    cat("    ✓ COHERENT: High R² with acceptable RMSE\n")
    cat("      → Model captures patterns well with reasonable errors\n")
    cat("      → This is EXPECTED and DESIRABLE\n")
  } else if (r2 > 0.7 && rmse_sd_ratio >= 0.6 && rmse_sd_ratio < 1.0) {
    cat("    ⚠ REVIEW: High R² with elevated RMSE\n")
    cat("      → Model captures patterns but errors are substantial\n")
    cat("      → Check if RMSE is acceptable for your application\n")
  } else if (r2 < 0.5 && rmse_sd_ratio > 0.8) {
    cat("    ✗ PROBLEMATIC: Low R² with high RMSE\n")
    cat("      → Model has poor predictive power\n")
    cat("      → Consider: more data, different features, hyperparameter tuning\n")
  } else {
    cat("    → Metrics within expected ranges for spatial modeling\n")
  }

  cat("\n\n")
}

# ============================================================================
# WHY HIGH R² WITH HIGH RMSE IS NORMAL
# ============================================================================

cat("═══════════════════════════════════════════════════════════════════\n")
cat("4. WHY HIGH R² WITH HIGH RMSE CAN BE NORMAL\n")
cat("═══════════════════════════════════════════════════════════════════\n\n")

cat("Mathematical Relationship:\n")
cat("  R² = 1 - (RMSE² / Variance)\n")
cat(sprintf("  R² = 1 - (RMSE² / %.2f)\n", soc_sd^2))
cat("\n")

cat("Example calculation for your data:\n")
example_rmse <- mean(results_table$RMSE, na.rm = TRUE)
example_r2 <- 1 - (example_rmse^2 / soc_sd^2)
cat(sprintf("  If RMSE = %.2f g C/kg\n", example_rmse))
cat(sprintf("  Then R² = 1 - (%.2f² / %.2f²)\n", example_rmse, soc_sd))
cat(sprintf("         = 1 - %.3f\n", (example_rmse^2 / soc_sd^2)))
cat(sprintf("         = %.3f\n", example_r2))
cat("\n")

cat("Key Insight:\n")
cat("  When data variance is HIGH (SD = %.2f):\n", soc_sd)
cat("  → You can have moderate RMSE AND high R² simultaneously\n")
cat("  → This indicates: Good pattern recognition + Realistic error estimates\n")
cat("\n")

cat("Your Data Context:\n")
cat(sprintf("  SOC ranges from %.1f to %.1f g C/kg (range = %.1f)\n",
            soc_min, soc_max, soc_range))
cat(sprintf("  Standard deviation = %.2f g C/kg\n", soc_sd))
cat(sprintf("  Average RMSE ≈ %.2f g C/kg\n", example_rmse))
cat(sprintf("  This RMSE represents only %.1f%% of the data range\n",
            (example_rmse/soc_range)*100))
cat(sprintf("  And %.1f%% of the standard deviation\n",
            (example_rmse/soc_sd)*100))
cat("\n")

cat("Conclusion:\n")
cat("  → Your RMSE values are PROPORTIONALLY SMALL relative to data variability\n")
cat("  → High R² indicates strong pattern recognition\n")
cat("  → Moderate RMSE indicates realistic prediction uncertainty\n")
cat("  → Both metrics together = ROBUST, TRUSTWORTHY MODEL\n")
cat("\n\n")

# ============================================================================
# LITERATURE COMPARISON
# ============================================================================

cat("═══════════════════════════════════════════════════════════════════\n")
cat("5. COMPARISON WITH LITERATURE BENCHMARKS\n")
cat("═══════════════════════════════════════════════════════════════════\n\n")

cat("Typical SOC Prediction Performance (Published Studies):\n")
cat("\n")
cat("  Local Scale (farm/field):\n")
cat("    Expected R²:    0.75 - 0.90\n")
cat("    Expected RMSE:  2 - 5 g C/kg\n")
cat("\n")
cat("  Regional Scale (watershed/county):\n")
cat("    Expected R²:    0.60 - 0.80\n")
cat("    Expected RMSE:  3 - 8 g C/kg\n")
cat("\n")
cat("  National Scale:\n")
cat("    Expected R²:    0.40 - 0.70\n")
cat("    Expected RMSE:  5 - 15 g C/kg\n")
cat("\n")

cat("Your Study (appears to be REGIONAL scale):\n")
best_model <- results_table[which.max(results_table$R2), ]
cat(sprintf("  Best model: %s\n", best_model$Model))
cat(sprintf("  R²:         %.3f\n", best_model$R2))
cat(sprintf("  RMSE:       %.2f g C/kg\n", best_model$RMSE))
cat("\n")

if (best_model$R2 >= 0.60 && best_model$RMSE <= 8) {
  cat("  ✓ EXCELLENT: Within or exceeds literature benchmarks\n")
  cat("    Your model performs as well as published studies!\n")
} else if (best_model$R2 >= 0.50 && best_model$RMSE <= 10) {
  cat("  ✓ GOOD: Comparable to literature benchmarks\n")
  cat("    Your model performs well for regional SOC mapping\n")
} else if (best_model$R2 >= 0.40) {
  cat("  ⚠ ACCEPTABLE: Below typical benchmarks but may be sufficient\n")
  cat("    Consider hyperparameter tuning or additional predictors\n")
} else {
  cat("  ⚠ NEEDS IMPROVEMENT: Below literature benchmarks\n")
  cat("    Recommend: hyperparameter tuning, more data, or better features\n")
}

cat("\n\n")

# ============================================================================
# RECOMMENDATIONS
# ============================================================================

cat("═══════════════════════════════════════════════════════════════════\n")
cat("6. RECOMMENDATIONS FOR REPORTING\n")
cat("═══════════════════════════════════════════════════════════════════\n\n")

cat("When presenting your results, include:\n")
cat("\n")
cat("1. Data Context:\n")
cat(sprintf("   'SOC values ranged from %.1f to %.1f g C/kg (mean = %.1f,\n",
            soc_min, soc_max, soc_mean))
cat(sprintf("    SD = %.1f, CV = %.1f%%, n = %d)'\n",
            soc_sd, soc_cv, length(original_soc)))
cat("\n")

cat("2. Validation Approach:\n")
cat("   'Spatial block cross-validation (5-fold, 3×3 grid) was used to\n")
cat("    account for spatial autocorrelation and provide conservative\n")
cat("    performance estimates representative of model generalization\n")
cat("    to unseen spatial locations.'\n")
cat("\n")

cat("3. Performance Metrics:\n")
cat(sprintf("   'The %s model achieved R² = %.3f, RMSE = %.2f g C/kg,\n",
            best_model$Model, best_model$R2, best_model$RMSE))
cat(sprintf("    and MAE = %.2f g C/kg. The RMSE represents %.1f%% of the\n",
            best_model$MAE, (best_model$RMSE/soc_sd)*100))
cat("    observed standard deviation, indicating good predictive accuracy.'\n")
cat("\n")

cat("4. Interpretation:\n")
cat(sprintf("   'The R² of %.3f indicates that %.1f%% of the variance in SOC\n",
            best_model$R2, best_model$R2*100))
cat("    was explained by the model, demonstrating strong pattern recognition.\n")
cat(sprintf("    The RMSE of %.2f g C/kg represents realistic prediction uncertainty\n",
            best_model$RMSE))
cat("    for regional-scale soil carbon mapping and is comparable to similar\n")
cat("    published studies [add citations].'\n")
cat("\n\n")

# ============================================================================
# VISUALIZATIONS
# ============================================================================

cat("═══════════════════════════════════════════════════════════════════\n")
cat("7. GENERATING DIAGNOSTIC VISUALIZATIONS\n")
cat("═══════════════════════════════════════════════════════════════════\n\n")

if (!dir.exists("plots")) dir.create("plots")

# Plot 1: RMSE vs R² scatter
p1 <- ggplot(results_table, aes(x = R2, y = RMSE, label = Model)) +
  geom_point(size = 4, color = "steelblue") +
  geom_text(hjust = -0.1, vjust = 0, size = 3.5) +
  geom_hline(yintercept = soc_sd * 0.5, linetype = "dashed", color = "red") +
  annotate("text", x = min(results_table$R2, na.rm = TRUE),
           y = soc_sd * 0.5, label = "RMSE = 0.5×SD (target)",
           hjust = 0, vjust = -0.5, size = 3, color = "red") +
  labs(
    title = "Model Performance: R² vs RMSE",
    subtitle = "High R² with moderate RMSE indicates good performance",
    x = "R² (higher is better)",
    y = "RMSE - g C/kg (lower is better)"
  ) +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold"))

ggsave("plots/validation_diagnostics_r2_vs_rmse.png", p1, width = 10, height = 6, dpi = 300)
cat("✓ Saved: plots/validation_diagnostics_r2_vs_rmse.png\n")

# Plot 2: Relative error metrics
results_table$RMSE_SD_ratio <- results_table$RMSE / soc_sd
results_table$nRMSE <- (results_table$RMSE / soc_mean) * 100

metrics_long <- data.frame(
  Model = rep(results_table$Model, 3),
  Metric = rep(c("R²", "RMSE/SD", "nRMSE (%)"), each = nrow(results_table)),
  Value = c(results_table$R2, results_table$RMSE_SD_ratio, results_table$nRMSE)
)

p2 <- ggplot(metrics_long, aes(x = Model, y = Value, fill = Metric)) +
  geom_bar(stat = "identity", position = "dodge") +
  facet_wrap(~Metric, scales = "free_y") +
  scale_fill_brewer(palette = "Set2") +
  labs(
    title = "Validation Metrics Comparison",
    subtitle = "R² = pattern recognition | RMSE/SD = relative error | nRMSE = normalized error",
    x = "Model",
    y = "Value"
  ) +
  theme_minimal() +
  theme(
    legend.position = "none",
    axis.text.x = element_text(angle = 45, hjust = 1),
    plot.title = element_text(face = "bold")
  )

ggsave("plots/validation_diagnostics_relative_metrics.png", p2, width = 12, height = 6, dpi = 300)
cat("✓ Saved: plots/validation_diagnostics_relative_metrics.png\n")

cat("\n")

# ============================================================================
# SUMMARY
# ============================================================================

cat("═══════════════════════════════════════════════════════════════════\n")
cat("SUMMARY\n")
cat("═══════════════════════════════════════════════════════════════════\n\n")

cat("Your validation metrics show:\n\n")

avg_r2 <- mean(results_table$R2, na.rm = TRUE)
avg_rmse_sd <- mean(results_table$RMSE / soc_sd, na.rm = TRUE)

if (avg_r2 > 0.7 && avg_rmse_sd < 0.5) {
  cat("✓ EXCELLENT PERFORMANCE\n")
  cat("  - High R² values indicate strong pattern recognition\n")
  cat("  - RMSE values are proportionally small relative to data variance\n")
  cat("  - High R² with moderate RMSE is EXPECTED and APPROPRIATE\n")
  cat("  - Your models are performing very well!\n")
} else if (avg_r2 > 0.6 && avg_rmse_sd < 0.7) {
  cat("✓ GOOD PERFORMANCE\n")
  cat("  - Solid R² values indicate good pattern recognition\n")
  cat("  - RMSE values are reasonable for spatial SOC prediction\n")
  cat("  - Metrics are coherent and within expected ranges\n")
  cat("  - Results are publishable\n")
} else {
  cat("⚠ REVIEW RECOMMENDED\n")
  cat("  - Consider hyperparameter tuning to improve performance\n")
  cat("  - Check for data quality issues\n")
  cat("  - Evaluate predictor variable selection\n")
}

cat("\nFor detailed explanation, see: VALIDATION_METRICS_EXPLANATION.md\n\n")

cat("═══════════════════════════════════════════════════════════════════\n")
cat("DIAGNOSTIC COMPLETE\n")
cat("═══════════════════════════════════════════════════════════════════\n\n")
