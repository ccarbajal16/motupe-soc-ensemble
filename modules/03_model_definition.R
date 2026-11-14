# 03_model_definition.R

# 4. Define models
# 4.1 SVM model - using the correct learner ID from mlr3extralearners
svm_model <- tryCatch({
  mlr3::lrn(
    "regr.svm",
    kernel = "radial",
    type = "eps-regression", 
    cost = 10,
    gamma = 0.1,
    epsilon = 0.1
  )
}, error = function(e) {
  cat("SVM learner not available, trying alternative...\n")
  # Alternative: use a simple linear model if SVM is not available
  mlr3::lrn("regr.lm")
})

# 4.2 ANN model - using nnet
ann_model <- tryCatch({
  mlr3::lrn(
    "regr.nnet",
    size = 10,
    maxit = 500,
    decay = 0.01,
    trace = FALSE,
    linout = TRUE  # For regression
  )
}, error = function(e) {
  cat("Neural network learner not available, trying alternative...\n")
  # Alternative: use a simple linear model if nnet is not available
  mlr3::lrn("regr.lm")
})

# 4.3 Random Forest model
rf_model <- tryCatch({
  mlr3::lrn(
    "regr.ranger",
    num.trees = 500,
    mtry = floor(sqrt(length(task_motupe_scaled$feature_names))),
    min.node.size = 5,
    importance = "impurity"  # Enable feature importance calculation
  )
}, error = function(e) {
  cat("Ranger learner not available, trying rpart...\n")
  # Alternative: use rpart if ranger is not available
  mlr3::lrn("regr.rpart")
})

# 4.4 XGBoost model
xgb_model <- tryCatch({
  mlr3::lrn(
    "regr.xgboost",
    nrounds = 100,
    eta = 0.1,
    max_depth = 6,
    subsample = 0.7,
    colsample_bytree = 0.7,
    verbose = 0,  # Suppress verbose output
    importance = "gain"  # Enable feature importance calculation
  )
}, error = function(e) {
  cat("XGBoost learner not available, trying alternative...\n")
  # Alternative: use a simple tree model if XGBoost is not available
  mlr3::lrn("regr.rpart")
})

# Print the models that will be used
cat("\nModels to be used:\n")
cat("SVM model ID:", svm_model$id, "\n")
cat("ANN model ID:", ann_model$id, "\n") 
cat("RF model ID:", rf_model$id, "\n")
cat("XGBoost model ID:", xgb_model$id, "\n")

# Save the models
saveRDS(svm_model, "models/svm_model.RDS")
saveRDS(ann_model, "models/ann_model.RDS")
saveRDS(rf_model, "models/rf_model.RDS")
saveRDS(xgb_model, "models/xgb_model.RDS")
