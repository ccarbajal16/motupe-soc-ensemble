# Spatial Uncertainty Analysis Technical Report

## Overview

This report presents the technical implementation and results of spatial uncertainty quantification for soil organic carbon (SOC) prediction in the Motupe region using bootstrap ensemble modeling with spatial cross-validation.

## Methodology

### Bootstrap Ensemble Approach
- **Bootstrap iterations**: 10 independent samples with replacement
- **Base models**: Linear Model (LM), Random Forest (RF), Decision Tree (RPART)
- **Ensemble method**: Equal-weight averaging of valid predictions
- **Spatial constraints**: Applied study area masking and spatial alignment

### Uncertainty Metrics

#### Standard Uncertainty Measures
1. **Bootstrap Standard Deviation**: Measure of prediction variability across bootstrap samples
2. **Coefficient of Variation (CV)**: Relative uncertainty as percentage of mean prediction
3. **90% Prediction Interval Width**: Range between 5th and 95th percentiles
4. **90% Prediction Interval Relative**: PI width as percentage of mean prediction

#### Prediction Interval Ratio (PIR) - New Implementation

The **Prediction Interval Ratio (PIR)** is a novel uncertainty metric implemented to provide a more robust assessment of prediction uncertainty:

**Definition**: PIR = (90% Prediction Interval Width) / (Median Prediction)

**Formula**: PIR₉₀ = (Q₉₅ - Q₀₅) / Q₅₀

Where:
- Q₉₅: 95th percentile of bootstrap predictions
- Q₀₅: 5th percentile of bootstrap predictions
- Q₅₀: 50th percentile (median) of bootstrap predictions

## Results

### PIR Analysis Results

**PIR₉₀ Statistics**:
- **Minimum**: 0.024 (2.4% relative uncertainty)
- **Mean**: 0.134 (13.4% relative uncertainty)
- **Median**: 0.129 (12.9% relative uncertainty)
- **Maximum**: 16.57 (1,657% relative uncertainty)
- **Standard Deviation**: 0.043

### Comprehensive Uncertainty Statistics

| Metric | Mean | Median | StdDev | Min | Max | CV (%) |
|--------|------|--------|--------|-----|-----|---------|
| **Bootstrap Mean** | 0.647 | 0.641 | 0.029 | 0.201 | 2.183 | 4.55 |
| **Bootstrap StdDev** | 0.031 | 0.030 | 0.010 | 0.005 | 4.220 | 31.4 |
| **CV (%)** | 4.78 | 4.58 | 1.51 | 0.83 | 626.1 | 31.69 |
| **90% PI Width** | 0.086 | 0.083 | 0.027 | 0.015 | 11.92 | 31.53 |
| **90% PI Relative (%)** | 13.41 | 12.85 | 4.27 | 2.39 | 1765.6 | 31.87 |
| **PIR₉₀** | 0.134 | 0.129 | 0.043 | 0.024 | 16.57 | 31.9* |

*CV calculated from raw statistics

### Uncertainty Distribution

#### Spatial Patterns
- **Low uncertainty zones** (PIR < 0.1): Areas with consistent predictions across bootstrap samples
- **Moderate uncertainty zones** (PIR 0.1-0.2): Typical prediction variability
- **High uncertainty zones** (PIR > 0.2): Areas requiring additional sampling or model refinement

#### PIR Interpretation Guide
- **PIR < 0.1**: High confidence predictions (< 10% relative uncertainty)
- **PIR 0.1-0.2**: Moderate confidence predictions (10-20% relative uncertainty)
- **PIR 0.2-0.5**: Low confidence predictions (20-50% relative uncertainty)
- **PIR > 0.5**: Very low confidence predictions (> 50% relative uncertainty)

## Technical Implementation

### PIR Calculation Code
```r
# Prediction Interval Ratio (PIR): 90% PI width / median (50th percentile)
bootstrap_pir <- bootstrap_pi90 / abs(bootstrap_q50)
bootstrap_pir[bootstrap_q50 <= 0] <- NA
names(bootstrap_pir) <- "Bootstrap_PIR_90"
```

### Advantages of PIR over Traditional Metrics

1. **Robustness**: Uses median instead of mean, reducing sensitivity to outliers
2. **Scale Independence**: Normalized by central tendency, comparable across different prediction ranges
3. **Intuitive Interpretation**: Direct measure of relative prediction interval width
4. **Stability**: Less affected by extreme values compared to CV based on mean

## Output Files Generated

### Raster Outputs
- `bootstrap_pir_90_spatial_cv.tif`: PIR₉₀ uncertainty map
- `bootstrap_uncertainty_stack_spatial_cv.tif`: Complete uncertainty metrics stack
- `bootstrap_mean_spatial_cv.tif`: Bootstrap ensemble mean predictions
- `bootstrap_q50_median_spatial_cv.tif`: Bootstrap median predictions
- `bootstrap_pi90_width_spatial_cv.tif`: 90% prediction interval width

### Statistical Summaries
- `uncertainty_analysis_statistics.csv`: Comprehensive uncertainty statistics
- `bootstrap_uncertainty_statistics.csv`: Bootstrap-specific summaries

## Conclusions

The PIR₉₀ metric provides a robust measure of prediction uncertainty with a mean value of 13.4%, indicating generally reliable SOC predictions across the Motupe study area. The implementation successfully:

1. **Quantifies spatial uncertainty** using bootstrap ensemble modeling
2. **Provides interpretable metrics** through the PIR framework
3. **Identifies high-uncertainty areas** requiring additional validation
4. **Supports decision-making** for soil sampling and mapping strategies

The PIR metric complements traditional uncertainty measures and offers improved robustness for spatial prediction applications in soil science and environmental modeling.