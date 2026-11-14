# Module Dependencies and Execution Guide

## Complete Dependency Chain

```
┌─────────────────────────────────────────────────────────────────┐
│  01_setup_and_load.R                                            │
│  ├─ Loads packages                                              │
│  ├─ Sets up parallel processing                                 │
│  └─ Produces: Nothing saved (environment setup only)            │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  02_preprocessing.R                                             │
│  ├─ Reads: Raw data from predictors/ and data/                  │
│  └─ Produces:                                                   │
│     ├─ data/task_motupe_scaled.RDS                              │
│     ├─ models/po_scale.RDS                                      │
│     ├─ data/covariates_with_xy.RDS                              │
│     ├─ data/motupe.RDS                                          │
│     └─ data/covsoc_for_modeling.RDS                             │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  03_model_definition.R  OR  03_model_tuning*.R                  │
│  ├─ Reads: data/task_motupe_scaled.RDS                          │
│  └─ Produces:                                                   │
│     ├─ models/svm_model.RDS                                     │
│     ├─ models/ann_model.RDS                                     │
│     ├─ models/rf_model.RDS                                      │
│     ├─ models/xgb_model.RDS                                     │
│     └─ models/*_tuning_results.RDS (only if using tuning)       │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  04_spatial_cv.R                                                │
│  ├─ Reads:                                                      │
│  │   ├─ data/task_motupe_scaled.RDS                             │
│  │   ├─ models/svm_model.RDS                                    │
│  │   ├─ models/ann_model.RDS                                    │
│  │   ├─ models/rf_model.RDS                                     │
│  │   ├─ models/xgb_model.RDS                                    │
│  │   └─ data/covsoc_for_modeling.RDS                            │
│  └─ Produces:                                                   │
│     ├─ models/svm_cv.RDS                                        │
│     ├─ models/ann_cv.RDS                                        │
│     ├─ models/rf_cv.RDS                                         │
│     ├─ models/xgb_cv.RDS                                        │
│     └─ plots/spatial_cv_partitioning_map.png                    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  05_ensemble.R                                                  │
│  ├─ Reads:                                                      │
│  │   ├─ models/svm_cv.RDS                                       │
│  │   ├─ models/ann_cv.RDS                                       │
│  │   ├─ models/rf_cv.RDS                                        │
│  │   ├─ models/xgb_cv.RDS                                       │
│  │   └─ data/task_motupe_scaled.RDS                             │
│  └─ Produces:                                                   │
│     ├─ models/ensemble_weights.RDS                              │
│     ├─ models/svm_metrics.RDS                                   │
│     ├─ models/ann_metrics.RDS                                   │
│     ├─ models/rf_metrics.RDS                                    │
│     └─ models/xgb_metrics.RDS                                   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  06_prediction.R                                                │
│  ├─ Reads:                                                      │
│  │   ├─ models/po_scale.RDS                                     │
│  │   ├─ data/covariates_with_xy.RDS                             │
│  │   ├─ models/svm_cv.RDS                                       │
│  │   ├─ models/ann_cv.RDS                                       │
│  │   ├─ models/rf_cv.RDS                                        │
│  │   ├─ models/xgb_cv.RDS                                       │
│  │   ├─ models/ensemble_weights.RDS                             │
│  │   ├─ data/motupe.RDS                                         │
│  │   └─ data/task_motupe_scaled.RDS                             │
│  └─ Produces:                                                   │
│     ├─ outputs/*_prediction.tif (4 models + ensemble)           │
│     └─ data/all_covariates_scaled_imputed.RDS                   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  07_uncertainty.R                                               │
│  ├─ Reads:                                                      │
│  │   ├─ data/task_motupe_scaled.RDS                             │
│  │   ├─ data/all_covariates_scaled_imputed.RDS                  │
│  │   └─ data/motupe.RDS                                         │
│  └─ Produces:                                                   │
│     └─ outputs/prediction_uncertainty.tif                       │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  08_evaluation_and_report.R                                     │
│  ├─ Reads:                                                      │
│  │   ├─ models/svm_cv.RDS                                       │
│  │   ├─ models/ann_cv.RDS                                       │
│  │   ├─ models/rf_cv.RDS                                        │
│  │   ├─ models/xgb_cv.RDS                                       │
│  │   ├─ models/ensemble_weights.RDS                             │
│  │   ├─ data/task_motupe_scaled.RDS                             │
│  │   ├─ data/covsoc_for_modeling.RDS                            │
│  │   └─ models/*_metrics.RDS                                    │
│  └─ Produces: Final report and visualizations                   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  compare_tuning_results.R (OPTIONAL - only if tuning used)      │
│  ├─ Reads:                                                      │
│  │   ├─ models/hyperparameter_tuning_summary.csv               │
│  │   └─ models/*_cv.RDS                                         │
│  └─ Produces:                                                   │
│     ├─ models/tuning_comparison_results.csv                     │
│     └─ plots/tuning_comparison_*.png                            │
└─────────────────────────────────────────────────────────────────┘
```

## Do You Need to Run Everything?

**SHORT ANSWER**:
- **First time**: YES - Run all modules sequentially
- **After first run**: NO - You can skip modules depending on what you want to improve

## Common Scenarios and Recommendations

### Scenario 1: First Time Running the Project
**Goal**: Get complete results

**What to run**:
```bash
Rscript main_with_tuning.R
```

**Why**: You need to build the complete pipeline from scratch
**Time**: ~3-6 hours (with tuning)

---

### Scenario 2: Only Want to Improve Hyperparameters
**Goal**: Re-tune models with better settings, keeping same data

**Already have**: Results from previous complete run

**What to run**:
```bash
# ONLY run these modules:
Rscript modules/03_model_tuning_advanced.R  # Re-tune models
Rscript modules/04_spatial_cv.R             # Re-validate
Rscript modules/05_ensemble.R               # Recalculate weights
Rscript modules/06_prediction.R             # New predictions
Rscript modules/07_uncertainty.R            # New uncertainty
Rscript modules/08_evaluation_and_report.R  # New report
Rscript modules/compare_tuning_results.R    # Compare
```

**Why**: Modules 01-02 don't need to re-run (data preprocessing is the same)
**Time**: ~2-5 hours

---

### Scenario 3: Only Want to Adjust Tuning Strategy
**Goal**: Try different tuning approach (grid vs random vs Bayesian)

**What to run**:
```bash
# Edit the tuning configuration in modules/03_model_tuning_advanced.R
# Change TUNING_STRATEGY = "random_search" to "bayesian" or "grid_search"

# Then run from module 03 onwards:
Rscript modules/03_model_tuning_advanced.R
Rscript modules/04_spatial_cv.R
Rscript modules/05_ensemble.R
Rscript modules/06_prediction.R
Rscript modules/compare_tuning_results.R
```

**Time**: ~2-5 hours

---

### Scenario 4: New Data Arrived
**Goal**: Re-run everything with new soil samples or predictors

**What to run**:
```bash
# Update your data files in data/ and predictors/ folders
# Then run complete pipeline:
Rscript main_with_tuning.R
```

**Why**: Must re-run preprocessing (module 02) when data changes
**Time**: ~3-6 hours

---

### Scenario 5: Only Want to Regenerate Maps/Plots
**Goal**: Improve visualizations without retraining

**What to run**:
```bash
# Only run reporting modules:
Rscript modules/08_evaluation_and_report.R
Rscript modules/compare_tuning_results.R
```

**Why**: All model results are already saved
**Time**: ~2-5 minutes

---

### Scenario 6: Only Want to Test One Model
**Goal**: Optimize only XGBoost (for example)

**What to do**: Edit the tuning module and comment out other models

**Example** (in `modules/03_model_tuning_advanced.R`):
```r
# Comment out SVM, ANN, and RF sections
# Keep only XGBoost section

# Then run:
Rscript modules/03_model_tuning_advanced.R
Rscript modules/04_spatial_cv.R
# ... continue as needed
```

**Time**: ~30-60 minutes

---

### Scenario 7: Want to Compare Tuned vs Non-Tuned
**Goal**: See if tuning actually helps

**What to run**:
```bash
# First run WITHOUT tuning
Rscript modules/01_setup_and_load.R
Rscript modules/02_preprocessing.R
Rscript modules/03_model_definition.R        # Original, no tuning
Rscript modules/04_spatial_cv.R
Rscript modules/05_ensemble.R

# Save baseline performance
copy models\hyperparameter_tuning_summary.csv models\baseline_performance.csv

# Then run WITH tuning
Rscript modules/03_model_tuning_advanced.R   # With tuning
Rscript modules/04_spatial_cv.R
Rscript modules/05_ensemble.R
Rscript modules/compare_tuning_results.R     # This will compare
```

**Time**: ~4-8 hours total

---

## Critical Rules

### ✅ You CAN Skip Modules If:

1. **Data hasn't changed** → Skip modules 01-02
2. **Only tuning changed** → Skip modules 01-02, start from 03
3. **Only want new plots** → Skip 01-07, run only 08 and compare
4. **Testing one model** → Comment out other models in scripts

### ❌ You CANNOT Skip If:

1. **Module produces files needed by next module** (see dependency chain above)
2. **Data changed** → Must run from module 02
3. **First time running** → Must run all modules

## Recommended Workflow for Your Case

Based on your question "what do you recommend if I need an improvement", here's what I suggest:

### Option A: Quick Improvement (2-3 hours)
**If you already ran the pipeline once**:

```bash
# 1. Edit tuning settings for faster testing
# In modules/03_model_tuning_advanced.R, change to:
TUNING_STRATEGY <- "random_search"
N_EVALS_SVM <- 15
N_EVALS_ANN <- 15
N_EVALS_RF <- 12
N_EVALS_XGB <- 20

# 2. Run from module 03 onwards
Rscript modules/03_model_tuning_advanced.R
Rscript modules/04_spatial_cv.R
Rscript modules/05_ensemble.R
Rscript modules/06_prediction.R
Rscript modules/compare_tuning_results.R
```

### Option B: Best Improvement (4-6 hours)
**For maximum performance gain**:

```bash
# 1. Use advanced tuning with default settings
# Keep modules/03_model_tuning_advanced.R as is

# 2. Run complete pipeline to ensure everything works
Rscript main_with_tuning.R
```

### Option C: Iterative Improvement
**Test quickly, then refine**:

```bash
# PHASE 1: Quick test (1 hour)
# Set low N_EVALS (10-15 each)
Rscript modules/03_model_tuning_advanced.R
Rscript modules/04_spatial_cv.R
Rscript modules/compare_tuning_results.R

# Check results, see which models benefit most from tuning

# PHASE 2: Deep dive (2-3 hours)
# Increase N_EVALS for best-performing models only
# Comment out underperforming models
Rscript modules/03_model_tuning_advanced.R
Rscript modules/04_spatial_cv.R
Rscript modules/05_ensemble.R
Rscript modules/06_prediction.R
```

## Summary Decision Tree

```
Do you have results from a previous complete run?
├─ NO  → Run main_with_tuning.R (full pipeline)
└─ YES → What changed?
    ├─ New data              → Run main_with_tuning.R
    ├─ Want better models    → Run modules 03-08 + compare
    ├─ Different tuning      → Run modules 03-05 + compare
    ├─ Just new plots        → Run module 08 + compare
    └─ Test one model        → Edit module 03, run 03-05
```

## My Specific Recommendation for You

Since you're asking about improvements, I recommend **Option A** (Quick Improvement):

1. **First, check if you have existing results**:
   - Do you have files in `models/` folder?
   - Do you have `data/task_motupe_scaled.RDS`?

2. **If YES** (you have previous results):
   ```bash
   # Start from module 03 with tuning
   Rscript modules/03_model_tuning_advanced.R
   Rscript modules/04_spatial_cv.R
   Rscript modules/05_ensemble.R
   Rscript modules/06_prediction.R
   Rscript modules/compare_tuning_results.R
   ```
   **Time**: 2-3 hours

3. **If NO** (first time):
   ```bash
   Rscript main_with_tuning.R
   ```
   **Time**: 3-6 hours

This gives you the best balance of time vs. improvement!
