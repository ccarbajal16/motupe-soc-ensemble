# 05_ensemble.R

# Load CV results
svm_cv <- readRDS("models/svm_cv.RDS")
ann_cv <- readRDS("models/ann_cv.RDS")
rf_cv <- readRDS("models/rf_cv.RDS")
xgb_cv <- readRDS("models/xgb_cv.RDS")
task_motupe_scaled <- readRDS("data/task_motupe_scaled.RDS")

# Extract CV results
extract_metrics <- function(cv_result) {
  tryCatch({
    if (is.null(cv_result$results) || length(cv_result$results) == 0) {
      return(list(
        RMSE = NA,
        MAE = NA,
        R2 = NA
      ))
    }

    rmse_val <- cv_result$results[["regr.rmse"]]
    mae_val <- cv_result$results[["regr.mae"]]
    r2_val <- cv_result$results[["regr.rsq"]]

    if (is.null(rmse_val) || is.na(rmse_val)) rmse_val <- NA
    if (is.null(mae_val) || is.na(mae_val)) mae_val <- NA
    if (is.null(r2_val) || is.na(r2_val)) r2_val <- NA

    if (is.na(r2_val) || r2_val <= 0) {
      model <- cv_result$model
      pred <- model$predict(task_motupe_scaled)
      actual <- task_motupe_scaled$data()$SOC
      predicted <- pred$response
      ss_total <- sum((actual - mean(actual))^2)
      ss_residual <- sum((actual - predicted)^2)
      r2_val <- 1 - (ss_residual / ss_total)
      r2_val <- max(0, min(1, r2_val))
    }

    list(
      RMSE = rmse_val,
      MAE = mae_val,
      R2 = r2_val
    )
  }, error = function(e) {
    cat("Error extracting metrics:", e$message, "\n")
    list(
      RMSE = NA,
      MAE = NA,
      R2 = NA
    )
  })
}

svm_metrics <- extract_metrics(svm_cv)
ann_metrics <- extract_metrics(ann_cv)
rf_metrics <- extract_metrics(rf_cv)
xgb_metrics <- extract_metrics(xgb_cv)

# 7. Create ensemble weights based on CV performance
svm_r2 <- max(0.1, svm_metrics$R2)
ann_r2 <- max(0.1, ann_metrics$R2)
rf_r2 <- max(0.1, rf_metrics$R2)
xgb_r2 <- max(0.1, xgb_metrics$R2)

total_weight <- svm_r2 + ann_r2 + rf_r2 + xgb_r2
svm_weight <- svm_r2 / total_weight
ann_weight <- ann_r2 / total_weight
rf_weight <- rf_r2 / total_weight
xgb_weight <- xgb_r2 / total_weight

# Print weights
cat("\nEnsemble Weights (based on spatial CV performance):\n")
cat("SVM weight:", round(svm_weight, 4), "\n")
cat("ANN weight:", round(ann_weight, 4), "\n")
cat("RF weight:", round(rf_weight, 4), "\n")
cat("XGBoost weight:", round(xgb_weight, 4), "\n")

# Save the weights
weights <- list(
  svm = svm_weight,
  ann = ann_weight,
  rf = rf_weight,
  xgb = xgb_weight
)
saveRDS(weights, "models/ensemble_weights.RDS")
saveRDS(svm_metrics, "models/svm_metrics.RDS")
saveRDS(ann_metrics, "models/ann_metrics.RDS")
saveRDS(rf_metrics, "models/rf_metrics.RDS")
saveRDS(xgb_metrics, "models/xgb_metrics.RDS")
