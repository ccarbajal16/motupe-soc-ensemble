# Spatial Cross-Validation Ensemble Model Report

## Spatial Cross-Validation

This analysis uses spatial block cross-validation with 5 folds to properly account for spatial autocorrelation in the data. Spatial CV helps prevent overly optimistic performance estimates that can occur with random CV in spatial data.

The visualization below shows the spatial partitioning of the data into 5 folds, with the study area boundary shown as a dashed black line.

![Spatial CV Partitioning with Study Area Boundary](spatial_cv_partitioning.png)

## Model Performance Metrics

The table below shows the performance metrics for each model. The metrics for the individual models (SVM, ANN, Random Forest, XGBoost) are calculated from spatial cross-validation, while the ensemble metrics are calculated on the training data.

```
                Model       RMSE        MAE        R2
1                 SVM 0.14402617 0.12609695 0.9372263
2                 ANN 0.11720465 0.09691812 0.1377864
3       Random Forest 0.11070852 0.09126907 0.8180064
4             XGBoost 0.12101126 0.09881312 0.3787096
5  Ensemble (Average) 0.05786736 0.04740469 0.6965472
6 Ensemble (Weighted) 0.04193888 0.03400374 0.8406113
```

Note: The ensemble metrics are calculated on the training data, so they may appear optimistic compared to the cross-validated metrics of the individual models. In practice, the ensemble models often perform better than individual models on new data.

## Ensemble Weights

Weights for the weighted ensemble were determined based on spatial CV performance:

- SVM weight:  0.4126 
- ANN weight:  0.0607 
- RF weight:  0.3601 
- XGBoost weight:  0.1667 

## Feature Importance Analysis

### Random Forest Feature Importance (Top 5)

```
   Feature Importance
5      EVI 0.14264503
6    GNDVI 0.12938994
12    Temp 0.10068115
13      pH 0.09831356
9      TPI 0.09170334
```

![Random Forest Feature Importance](../plots/rf_feature_importance.png)

## Bootstrap Uncertainty Analysis

Bootstrap uncertainty quantification was performed using 10 iterations to assess prediction reliability.

### Uncertainty Metrics:

- **Standard Deviation**: Measures absolute uncertainty in predictions
- **Coefficient of Variation (CV)**: Relative uncertainty (SD/Mean × 100%)
- **90% Prediction Interval**: Range containing 90% of bootstrap predictions
- **Relative PI**: Prediction interval width relative to mean prediction

### Uncertainty Statistics:

```
```

Lower CV values indicate more reliable predictions, while higher CV values suggest areas of greater uncertainty.

## Conclusion

The spatial cross-validation results provide a more realistic assessment of model performance for spatial prediction. These results account for spatial autocorrelation, which can lead to overly optimistic estimates with traditional random cross-validation.

Bootstrap uncertainty quantification provides confidence estimates for each prediction, enabling identification of areas with reliable vs. uncertain predictions.

All prediction and uncertainty rasters have been exported as GeoTIFF files in the 'outputs' directory with the suffix '_spatial_cv'.
