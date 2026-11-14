# Methodology for Spatial Prediction of Soil Organic Carbon Using Ensemble Machine Learning with Bootstrap Uncertainty Quantification

## Abstract

A comprehensive spatial modeling approach was implemented to predict Soil Organic Carbon (SOC) in the Motupe region using ensemble machine learning techniques combined with bootstrap uncertainty quantification. The methodology integrated four machine learning algorithms (Support Vector Machine, Artificial Neural Network, Random Forest, and XGBoost) within a spatial cross-validation framework to account for spatial autocorrelation. Bootstrap resampling was employed to quantify prediction uncertainty, providing reliability estimates for management applications.

---

## 1. Study Area and Data Collection

### 1.1 Study Area
The analysis was conducted in the Motupe region, Peru, where spatial predictions were constrained to the study area boundary defined by the borde_motupe.gpkg vector file. The study area was characterized by diverse topographic conditions, land uses, and soil properties suitable for comprehensive SOC modeling.

### 1.2 Soil Data
Soil samples were collected and analyzed for SOC content, with sampling locations and corresponding SOC values stored in the suelos_motupe_model.gpkg spatial dataset. The soil data were converted from character to numeric format to ensure compatibility with the modeling framework. Spatial coordinates were extracted from the geometry column and used for spatial analysis procedures.

### 1.3 Environmental Predictors
Thirteen environmental predictor variables were assembled from various sources, including:
- **Topographic variables**: Aspect, hillshade, Topographic Position Index (TPI), Topographic Ruggedness Index (TRI), Topographic Wetness Index (TWI)
- **Soil properties**: Bulk Density (BD), Clay content, pH, Silt content
- **Climatic variables**: Temperature (Temp), Electrical Conductivity (EC)
- **Vegetation indices**: Enhanced Vegetation Index (EVI), Green Normalized Difference Vegetation Index (GNDVI)

Individual raster files were stacked into a multi-layer raster dataset (predictors.tif) and subsequently cropped and masked to the study area boundary.

---

## 2. Data Preprocessing and Task Definition

### 2.1 Feature Extraction
Environmental predictor values were extracted at soil sampling locations using the terra::extract() function. The extraction process bound the predictor values to the soil sample points, creating a comprehensive dataset for model training.

### 2.2 Spatial Task Creation
A spatial regression task was created using the mlr3spatial framework (as_task_regr_st function) with SOC as the target variable. Coordinates were included as spatial information but were not used as predictive features (coords_as_features = FALSE) to maintain proper spatial modeling practices.

### 2.3 Feature Standardization
All predictor variables were standardized using z-score normalization (po_scale preprocessing) to ensure equal contribution across variables with different scales and units. The scaling parameters (mean and standard deviation) were stored for consistent application to prediction rasters.

---

## 3. Spatial Cross-Validation Framework

### 3.1 Spatial Partitioning Strategy
Spatial block cross-validation (spcv_block) was implemented to address spatial autocorrelation in the data. The study area was partitioned into a 3×3 grid with 5 cross-validation folds, ensuring that training and testing samples were spatially separated to provide realistic performance estimates.

### 3.2 Visualization of Spatial Partitions
The spatial partitioning was visualized using both ggplot2 and base R graphics, with automatic fallback to base R plotting in case of ggplot2 failures. The visualization included study area boundaries and fold assignments to demonstrate the spatial separation of training and testing data.

---

## 4. Machine Learning Model Implementation

### 4.1 Model Selection and Configuration
Four machine learning algorithms were selected to capture different aspects of the SOC-environment relationships:

#### 4.1.1 Support Vector Machine (SVM)
- **Algorithm**: regr.svm with radial basis function kernel
- **Parameters**: cost = 10, gamma = 0.1, epsilon = 0.1
- **Fallback**: regr.lm (linear model) if SVM implementation failed

#### 4.1.2 Artificial Neural Network (ANN)
- **Algorithm**: regr.nnet (single hidden layer neural network)
- **Parameters**: size = 10 neurons, maxit = 500 iterations, decay = 0.01
- **Configuration**: linout = TRUE for regression, trace = FALSE for silent operation
- **Fallback**: regr.lm if neural network implementation failed

#### 4.1.3 Random Forest (RF)
- **Algorithm**: regr.ranger (fast Random Forest implementation)
- **Parameters**: num.trees = 500, mtry = floor(√(number of features)), min.node.size = 5
- **Feature importance**: importance = "impurity" for Gini-based importance calculation
- **Fallback**: regr.rpart (decision tree) if ranger implementation failed

#### 4.1.4 XGBoost
- **Algorithm**: regr.xgboost (gradient boosting)
- **Parameters**: nrounds = 100, eta = 0.1, max_depth = 6, subsample = 0.7, colsample_bytree = 0.7
- **Feature importance**: importance = "gain" for information gain-based importance
- **Configuration**: verbose = 0 for silent operation
- **Fallback**: regr.rpart if XGBoost implementation failed

### 4.2 Spatial Cross-Validation Execution
Each model was trained and validated using the spatial cross-validation framework through a custom function (run_single_model_cv) that:
- Cloned learners to avoid conflicts between iterations
- Executed training on spatial training folds
- Generated predictions on spatial testing folds
- Calculated performance metrics (RMSE, MAE, R²) for each fold
- Aggregated performance across all folds using mean values

### 4.3 Error Handling and Robustness
Comprehensive error handling was implemented at multiple levels:
- Model-level fallbacks to simpler algorithms if advanced methods failed
- Cross-validation error handling with default performance values
- Graceful degradation while maintaining analysis continuity

---

## 5. Ensemble Model Development

### 5.1 Performance-Based Weighting
Ensemble weights were calculated based on spatial cross-validation R² performance:
- Individual model R² values were normalized to ensure non-negative weights (minimum 0.1)
- Weights were calculated as the proportion of each model's R² relative to total R² across all models
- Final weights summed to unity for proper ensemble combination

### 5.2 Ensemble Prediction Methods
Two ensemble approaches were implemented:
- **Simple average ensemble**: Equal weighting of all four models (weight = 0.25 each)
- **Performance-weighted ensemble**: Weights based on spatial CV performance

### 5.3 Final Model Training
Final models were trained on the complete dataset after cross-validation to maximize the use of available training data for prediction generation.

---

## 6. Feature Importance Analysis

### 6.1 Random Forest Importance
Feature importance was extracted from the Random Forest model using Gini impurity reduction as the importance measure. The importance values were normalized and ranked to identify the most influential predictors.

### 6.2 XGBoost Importance
Feature importance was calculated from the XGBoost model using information gain as the importance metric. The xgb.importance function was used to extract and rank predictor variables.

### 6.3 Comparative Analysis
A combined feature importance analysis was conducted by:
- Normalizing importance scores from both models to a 0-1 scale
- Creating comparative visualizations showing importance rankings
- Exporting importance data as CSV files for further analysis

---

## 7. Bootstrap Uncertainty Quantification

### 7.1 Bootstrap Sampling Strategy
Bootstrap uncertainty analysis was implemented using 10 iterations with sequential processing to ensure reliability with complex spatial objects. Each bootstrap iteration involved:
- Random sampling with replacement from the original training dataset
- Training simplified models (linear model, Random Forest, decision tree) for computational efficiency
- Generating spatial predictions across the study area
- Implementing comprehensive quality control measures

### 7.2 Spatial Validation and Quality Control
Extensive validation procedures were applied to bootstrap predictions:
- **Spatial consistency checks**: Verification of extent and coordinate reference system matching
- **Quality filtering**: Minimum 30% valid pixel values required per prediction
- **Ensemble validation**: Minimum 5 valid bootstrap predictions required for uncertainty analysis
- **Error handling**: Failed predictions were excluded with informative warnings

### 7.3 Uncertainty Metric Calculation
Multiple uncertainty metrics were calculated from the bootstrap prediction ensemble:
- **Standard Deviation**: Absolute uncertainty in SOC predictions
- **Coefficient of Variation (CV)**: Relative uncertainty as percentage of predicted value
- **90% Prediction Intervals**: Lower (5th percentile) and upper (95th percentile) bounds
- **Prediction Interval Width**: Absolute and relative width of 90% confidence intervals

---

## 8. Spatial Prediction Generation

### 8.1 Raster Preprocessing
Environmental predictor rasters were preprocessed for prediction:
- Scaling applied using stored parameters from training data preprocessing
- Missing values imputed using layer-specific mean values
- Spatial extent and resolution maintained consistent with original data

### 8.2 Individual Model Predictions
Spatial predictions were generated for each of the four trained models using the terra::predict() function with comprehensive error handling. Failed predictions were replaced with dummy rasters containing NA values while maintaining spatial properties.

### 8.3 Ensemble Predictions
Both simple average and weighted ensemble predictions were calculated by combining individual model predictions according to the established weighting schemes.

---

## 9. Performance Evaluation and Visualization

### 9.1 Cross-Validation Performance Analysis
Spatial cross-validation results were analyzed and visualized through:
- Comparison of RMSE, MAE, and R² across models
- Normalized performance metrics for comparative analysis
- Ensemble weight visualization based on performance rankings

### 9.2 Training Data Performance Assessment
Model performance was evaluated on training data through observed vs. predicted scatter plots for all models, including:
- Individual model performance visualization
- Ensemble model performance comparison
- Statistical metrics annotation on plots

### 9.3 Uncertainty Visualization
Bootstrap uncertainty was visualized through:
- Multi-panel uncertainty maps showing standard deviation, CV, and prediction intervals
- Uncertainty distribution histograms
- Summary statistics tables

---

## 10. Output Generation and Documentation

### 10.1 Raster Output
All prediction and uncertainty rasters were:
- Cropped and masked to the study area boundary
- Exported as GeoTIFF files with descriptive naming conventions
- Organized into prediction rasters, uncertainty rasters, and composite stacks

### 10.2 Model Persistence
Trained models and preprocessing objects were saved as RDS files to enable:
- Model reuse for future predictions
- Reproducibility of results
- Application to new datasets with consistent preprocessing

### 10.3 Comprehensive Reporting
A detailed markdown report was generated automatically, including:
- Spatial cross-validation results and interpretation
- Feature importance rankings and analysis
- Bootstrap uncertainty statistics and interpretation
- Method documentation and recommendations

---

## 11. Quality Assurance and Validation

### 11.1 Internal Validation Procedures
Multiple quality assurance measures were implemented:
- Spatial consistency validation for all raster outputs
- Statistical validation of uncertainty estimates
- Cross-validation performance benchmarking
- Error rate monitoring and reporting

### 11.2 Memory Management and Computational Efficiency
Resource management strategies included:
- Automatic core detection with conservative limits (maximum 8 cores)
- Sequential processing for bootstrap analysis to ensure reliability
- Explicit garbage collection and memory cleanup
- Large object removal after processing completion

### 11.3 Reproducibility Measures
Reproducibility was ensured through:
- Fixed random seeds for bootstrap sampling
- Comprehensive parameter documentation
- Automated workflow with minimal manual intervention
- Complete process documentation and code annotation

---

## 12. Limitations and Assumptions

### 12.1 Methodological Limitations
Several limitations were acknowledged in the methodology:
- Bootstrap sample size was limited to 10 iterations for computational reliability
- Simplified models were used in bootstrap analysis for efficiency
- Spatial extent limited to areas with environmental predictor coverage
- Temporal stationarity assumed for model relationships

### 12.2 Model Assumptions
Key assumptions underlying the modeling approach included:
- Spatial stationarity of SOC-environment relationships
- Independence of model errors after spatial cross-validation
- Representativeness of training data for the broader study area
- Adequacy of selected environmental predictors for SOC prediction

---

## Conclusion

The implemented methodology provided a robust framework for spatial SOC prediction with comprehensive uncertainty quantification. The combination of ensemble machine learning, spatial cross-validation, and bootstrap uncertainty analysis addressed key challenges in spatial prediction while providing practical estimates of prediction reliability. The systematic approach to error handling and quality assurance ensured reliable results suitable for management applications, while the comprehensive documentation enables reproducibility and method refinement for future applications.

---

**Methodology Version**: 1.0  
**Implementation Date**: August 2025  
**Study Area**: Motupe Region, Peru  
**Analysis Framework**: R with mlr3 spatial machine learning ecosystem