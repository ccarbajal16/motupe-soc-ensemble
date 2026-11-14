# Spatial Cross-Validation Ensemble Model Report

## Model Performance Metrics

```
                Model       RMSE        MAE        R2
1                 SVM 0.14402617 0.12609695 0.9372263
2                 ANN 0.11720465 0.09691812 0.1377864
3       Random Forest 0.11016752 0.09141347 0.8194090
4             XGBoost 0.12101126 0.09881312 0.3787096
5  Ensemble (Average) 0.05778317 0.04733112 0.6974295
6 Ensemble (Weighted) 0.04185644 0.03389138 0.8412374
```

## Uncertainty Analysis Statistics

```
            Metric    Mean  Median StdDev     Min       Max     Q25     Q75
25%           mean  0.6465  0.6414 0.0294  0.2006    2.1833  0.6255  0.6657
25%1         stdev  0.0308  0.0297 0.0097  0.0053    4.2203  0.0246  0.0359
25%2            cv  4.7755  4.5804 1.5135  0.8329  626.0872  3.7916  5.5578
25%3    pi90_width  0.0864  0.0832 0.0273  0.0149   11.9188  0.0689  0.1008
25%4 pi90_relative 13.4063 12.8497 4.2725  2.3923 1765.6202 10.6167 15.6245
25%5           q05  0.6044  0.6029 0.0322 -4.5453    0.7427  0.5840  0.6240
25%6           q95  0.6909  0.6866 0.0316  0.5905    7.3735  0.6669  0.7128
1          SUMMARY  0.6465      NA 0.0308      NA        NA      NA      NA
        IQR CV_percent N_pixels
25%  0.0402       4.55  4089160
25%1 0.0113      31.40  4089160
25%2 1.7662      31.69  4089160
25%3 0.0319      31.53  4089160
25%4 5.0078      31.87  4089160
25%5 0.0400       5.33  4089160
25%6 0.0459       4.58  4089160
1        NA       4.76  4089160
```

### Key Uncertainty Metrics

- **Average Prediction**: 0.6465 (SOC units)
- **Average Standard Deviation**: 0.0308 (SOC units)
- **Average Coefficient of Variation**: 4.7755%

