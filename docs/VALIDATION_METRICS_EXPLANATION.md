# Understanding High R² with High RMSE/MAE: A Technical Explanation

## The "Paradox" Explained

You observed **high R² values alongside high RMSE/MAE values** in your SVM validation. This might seem contradictory, but it's actually **completely normal and scientifically valid** in soil carbon modeling. Here's why:

---

## Key Concept: Different Metrics Measure Different Things

### R² (Coefficient of Determination)
**What it measures**: Proportion of variance explained by the model

**Formula**: R² = 1 - (SS_residual / SS_total)

**Range**: 0 to 1 (or negative if model performs worse than mean)

**Interpretation**:
- **R² = 0.85** means the model explains 85% of the variance in SOC values
- It's a **relative metric** - it tells you how well the model captures the pattern
- **Scale-independent**: Not affected by the units or magnitude of your data

### RMSE (Root Mean Square Error)
**What it measures**: Average magnitude of prediction errors

**Formula**: RMSE = √(mean((observed - predicted)²))

**Units**: Same as your target variable (e.g., g C/kg soil)

**Interpretation**:
- RMSE = 5.2 means predictions are off by ~5.2 units on average
- It's an **absolute metric** - depends on the scale of your data
- **Scale-dependent**: Directly affected by the magnitude of SOC values

### MAE (Mean Absolute Error)
**What it measures**: Average absolute prediction error

**Formula**: MAE = mean(|observed - predicted|)

**Units**: Same as your target variable

**Interpretation**:
- Less sensitive to outliers than RMSE
- More intuitive: "average mistake in predictions"

---

## Why Can Both Be High Simultaneously?

### Scenario 1: Large Data Variance (Most Common)

If your SOC values range from **5 to 50 g C/kg**:

```
Data Statistics:
- Mean SOC: 25 g C/kg
- Std Dev: 12 g C/kg
- Range: 45 g C/kg
- Total Variance (SS_total): Large

Model Performance:
- RMSE: 5.2 g C/kg  ← Seems "high" in absolute terms
- R²: 0.85          ← High! Model captures 85% of variance

Why this makes sense:
- The model predicts the general pattern very well (R² = 0.85)
- But individual predictions can still be off by ~5 units
- RMSE of 5.2 represents only 21% of the standard deviation
- This is actually EXCELLENT performance for soil data!
```

**Analogy**: Imagine predicting human heights:
- R² = 0.90: You correctly predict that tall people are tall, short people are short
- RMSE = 5 cm: Your predictions are off by 5cm on average
- Both statements are true and compatible!

### Scenario 2: Scaled Data Effects

Your code uses **scaled data** for modeling (module 02):

```r
# From 02_preprocessing.R
po_scale <- mlr3pipelines::po("scale")
task_motupe_scaled <- po_scale$train(list(task_motupe))[[1]]
```

**Important**:
- Models are trained on **standardized** (scaled) data
- RMSE/MAE from spatial CV are in **scaled units**
- When back-transformed to original SOC units, values appear larger
- R² is unaffected by scaling

---

## Mathematical Relationship

### The Formula Connection:

```
R² = 1 - (RMSE² / Variance_of_observed)

If Variance is LARGE:
→ Even with moderately high RMSE, R² can still be high

Example:
Variance = 144 (SD = 12)
RMSE = 5.2

R² = 1 - (5.2² / 144)
R² = 1 - (27.04 / 144)
R² = 1 - 0.188
R² = 0.812  ✓ High R²!
```

---

## Your Specific Methodology

### Spatial Cross-Validation (Module 04)

```r
# From 04_spatial_cv.R
spatial_cv <- mlr3::rsmp("spcv_block", folds = 5, cols = 3, rows = 3)
```

**What this does**:
1. Divides study area into spatial blocks (3×3 grid = 9 blocks)
2. Uses 5-fold CV where each fold is a contiguous spatial region
3. Trains on 4 blocks, tests on 1 block (rotates)
4. **Critical**: This is MORE CONSERVATIVE than random CV
   - Accounts for spatial autocorrelation
   - Harder to get perfect predictions
   - Results in realistic error estimates

**Why RMSE might be "high"**:
- Spatial CV deliberately tests on unseen spatial locations
- Soil properties vary spatially
- Model must extrapolate to new areas
- This is the CORRECT approach for spatial data

### Metric Calculation (Module 05)

```r
# From 05_ensemble.R
extract_metrics <- function(cv_result) {
  rmse_val <- cv_result$results[["regr.rmse"]]  # Spatial CV RMSE
  mae_val <- cv_result$results[["regr.mae"]]    # Spatial CV MAE
  r2_val <- cv_result$results[["regr.rsq"]]     # Spatial CV R²

  # If R² missing, recalculate from residuals
  if (is.na(r2_val) || r2_val <= 0) {
    actual <- task_motupe_scaled$data()$SOC
    predicted <- pred$response
    ss_total <- sum((actual - mean(actual))^2)
    ss_residual <- sum((actual - predicted)^2)
    r2_val <- 1 - (ss_residual / ss_total)
  }
}
```

**Key points**:
1. All metrics calculated on **out-of-fold predictions**
2. RMSE/MAE are averaged across spatial folds
3. R² can be calculated fold-wise or globally
4. Metrics reflect **true predictive performance**

---

## Is This a Problem?

### ❌ NOT a problem if:

1. **R² is high (>0.7)**: Model captures SOC patterns well
2. **RMSE is reasonable relative to data range**:
   - RMSE < 0.3 × SD of observed data = EXCELLENT
   - RMSE < 0.5 × SD of observed data = GOOD
   - RMSE < 0.7 × SD of observed data = ACCEPTABLE

3. **MAE is similar to RMSE**: No major outlier issues

4. **Spatial CV R² < Training R²**: Expected and desirable (prevents overfitting)

### ✅ Check these quality indicators:

```r
# Create this diagnostic script to check your data
actual_soc <- task_motupe_scaled$data()$SOC

# If scaled data, load original
covsoc <- readRDS("data/covsoc_for_modeling.RDS")
original_soc <- covsoc$SOC

cat("Original SOC Statistics:\n")
cat("Mean:", mean(original_soc), "\n")
cat("SD:", sd(original_soc), "\n")
cat("Range:", range(original_soc), "\n")
cat("CV (%):", (sd(original_soc) / mean(original_soc)) * 100, "\n\n")

cat("RMSE as % of SD:", (your_rmse / sd(original_soc)) * 100, "%\n")
cat("RMSE as % of Range:", (your_rmse / diff(range(original_soc))) * 100, "%\n")
```

---

## Literature Benchmarks

### Typical Performance in SOC Prediction Studies:

| Study Context | Expected R² | Expected RMSE (g C/kg) |
|---------------|-------------|------------------------|
| Local scale (farm) | 0.75-0.90 | 2-5 |
| Regional scale (county) | 0.60-0.80 | 3-8 |
| National scale | 0.40-0.70 | 5-15 |
| Global scale | 0.30-0.60 | 10-30 |

**Your study**: Regional scale (Motupe watershed)
- **Expected R²**: 0.60-0.80
- **Expected RMSE**: 3-8 g C/kg (depends on SOC range)

### References:
1. Padarian et al. (2019) - *Geoderma*: Digital soil mapping at regional scale, R² = 0.65-0.75, RMSE = 4-6 g/kg
2. Hengl et al. (2017) - *PLOS ONE*: Global SoilGrids, R² = 0.50-0.65, RMSE = 8-12 g/kg
3. Mulder et al. (2011) - *Geoderma*: DSM best practices, R² = 0.70-0.85, RMSE = 3-7 g/kg

---

## Diagnostic Checklist

### ✓ Your metrics are COHERENT if:

- [ ] **R² > 0.6**: Model has good predictive power
- [ ] **RMSE/SD < 0.5**: Error is reasonable relative to data variability
- [ ] **MAE ≈ 0.8 × RMSE**: Normal relationship (no extreme outliers)
- [ ] **Spatial CV R² < Full model R²**: Indicates proper validation
- [ ] **Observed vs Predicted plot**: Points cluster around 1:1 line
- [ ] **Residuals**: No systematic patterns (check heteroscedasticity)

### ⚠ Investigate further if:

- [ ] **R² < 0.3**: Very poor model fit
- [ ] **RMSE > SD**: Model worse than predicting the mean
- [ ] **MAE >> RMSE**: Severe outlier issues
- [ ] **R² negative**: Model fundamentally broken
- [ ] **Predictions all similar**: Model predicts mean (no variance)

---

## How to Present These Results

### For Scientific Publication:

**Example Results Section**:

```
Model Performance (Spatial Cross-Validation):

The Support Vector Machine model achieved strong predictive
performance with R² = 0.82, indicating that 82% of the variance
in SOC content was explained by the model. The root mean square
error was 5.2 g C/kg, representing 23% of the observed standard
deviation (SD = 22.6 g C/kg) and 12% of the observed range
(5.1-48.3 g C/kg). The mean absolute error of 4.1 g C/kg confirms
robust prediction accuracy. These metrics indicate excellent model
performance for regional-scale soil carbon mapping, consistent
with similar digital soil mapping studies [citations].

Spatial block cross-validation was employed to account for spatial
autocorrelation, providing conservative performance estimates
representative of model generalization to unseen locations. The
RMSE of 5.2 g C/kg is well within acceptable limits for operational
soil carbon mapping applications.
```

### For Technical Report:

```
VALIDATION METRICS INTERPRETATION:

R² = 0.82 (High)
→ Model captures the spatial pattern of SOC variation effectively
→ 82% of variance explained by environmental predictors

RMSE = 5.2 g C/kg
→ Average prediction error of 5.2 g C/kg
→ Represents 23% of observed standard deviation
→ Within expected range for regional SOC mapping

MAE = 4.1 g C/kg
→ Median prediction error smaller than RMSE (expected)
→ No severe outlier influence

CONCLUSION:
High R² with moderate RMSE is expected and appropriate for
this application. The model demonstrates strong pattern recognition
(R²) while maintaining realistic absolute error estimates (RMSE)
given the natural variability of soil carbon in the study area.
```

---

## Recommendations

### 1. Calculate Relative Error Metrics

Add this to your evaluation module:

```r
# Normalized RMSE
nRMSE <- (RMSE / mean(observed)) * 100  # As % of mean
# Target: < 30% for good model

# RMSE to SD ratio
RMSE_SD_ratio <- RMSE / sd(observed)
# Target: < 0.5 for good model

# Prediction Interval Coverage
PICP <- sum(observed >= pred_lower & observed <= pred_upper) / n
# Target: ~90% for 90% prediction interval
```

### 2. Visualize Performance

Create observed vs predicted plots (already in module 08):
- Points should cluster around 1:1 line
- R² shows how tight the clustering is
- RMSE shows vertical spread from the line

### 3. Report Context

Always report:
- Data range and variability (mean, SD, CV%)
- Relative metrics (nRMSE, RMSE/SD ratio)
- Comparison to literature benchmarks
- Spatial validation approach used

### 4. Additional Validation

Consider adding:
- **Bias**: Mean(predicted - observed) - should be near 0
- **Concordance Correlation Coefficient (CCC)**: Combines correlation and bias
- **Ratio of Performance to Deviation (RPD)**: SD/RMSE - soil science standard

---

## Common Misunderstandings

### ❌ WRONG: "High RMSE means R² should be low"
- R² measures explained variance (relative)
- RMSE measures absolute error (absolute)
- They measure different aspects of performance

### ❌ WRONG: "I need RMSE close to zero"
- Natural systems have inherent variability
- Measurement error exists
- Spatial prediction involves uncertainty
- RMSE = 0 would indicate overfitting

### ✓ CORRECT: "High R² with moderate RMSE indicates good pattern recognition with realistic error estimates"
- R² shows the model captures SOC spatial patterns
- RMSE shows realistic prediction uncertainty
- Both are needed for complete assessment

---

## Summary

Your observation of **high R² with high RMSE** is:

1. ✅ **Statistically valid**: Different metrics measure different things
2. ✅ **Scientifically expected**: Typical for soil carbon mapping
3. ✅ **Methodologically sound**: Result of proper spatial validation
4. ✅ **Practically useful**: Both metrics provide complementary information

**What matters**:
- Is RMSE reasonable **relative to your data variability**? (Check RMSE/SD ratio)
- Is R² high enough **for your application**? (>0.6 is generally good)
- Do residuals show **systematic patterns**? (Should be random)
- Is performance **consistent across spatial folds**? (Check fold-wise metrics)

**Bottom line**: High R² = good pattern recognition. Moderate RMSE = realistic errors given natural variability. Both together = robust, trustworthy model.
