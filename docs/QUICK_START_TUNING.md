# Quick Start: Hyperparameter Tuning

## What's New

Your SOC prediction project now includes **automated hyperparameter optimization** to improve model performance. This can significantly increase prediction accuracy by finding optimal model configurations.

## Files Added

### Main Tuning Modules
1. **`modules/03_model_tuning.R`** - Basic grid search (recommended for beginners)
2. **`modules/03_model_tuning_advanced.R`** - Advanced multi-strategy tuning (for power users)
3. **`modules/compare_tuning_results.R`** - Compare tuning performance

### New Scripts
4. **`main_with_tuning.R`** - Complete pipeline with tuning enabled
5. **`HYPERPARAMETER_TUNING_GUIDE.md`** - Comprehensive documentation
6. **`QUICK_START_TUNING.md`** - This file

## How to Use (3 Methods)

### Method 1: Run Complete Pipeline with Tuning (EASIEST)

```bash
Rscript main_with_tuning.R
```

This runs everything automatically with hyperparameter tuning enabled.

**Configuration**: Edit line 15 in `main_with_tuning.R`:
```r
USE_TUNING <- "advanced"  # Options: "basic", "advanced", or "none"
```

### Method 2: Replace Original Module

1. **Backup original** (optional):
   ```bash
   copy modules\03_model_definition.R modules\03_model_definition_backup.R
   ```

2. **Replace with tuning version**:
   ```bash
   # For basic grid search:
   copy modules\03_model_tuning.R modules\03_model_definition.R

   # OR for advanced tuning:
   copy modules\03_model_tuning_advanced.R modules\03_model_definition.R
   ```

3. **Run original pipeline**:
   ```bash
   Rscript main.R
   ```

### Method 3: Run Modules Individually

```bash
# Setup and preprocessing
Rscript modules/01_setup_and_load.R
Rscript modules/02_preprocessing.R

# Hyperparameter tuning (choose one)
Rscript modules/03_model_tuning.R              # Basic
Rscript modules/03_model_tuning_advanced.R      # Advanced

# Continue with rest of pipeline
Rscript modules/04_spatial_cv.R
Rscript modules/05_ensemble.R
Rscript modules/06_prediction.R
Rscript modules/07_uncertainty.R
Rscript modules/08_evaluation_and_report.R

# Compare results
Rscript modules/compare_tuning_results.R
```

## Which Tuning Module Should I Use?

### Basic Grid Search (`03_model_tuning.R`)
**Use this if**:
- You're new to hyperparameter tuning
- You want faster results (~2-4 hours)
- You prefer systematic, reproducible searches
- You have moderate computational resources

**What it does**: Tests 16-64 combinations per model in a systematic grid

### Advanced Multi-Strategy (`03_model_tuning_advanced.R`)
**Use this if**:
- You want maximum flexibility
- You can wait longer for better results (~2-6 hours)
- You want to experiment with different strategies
- You have more computational resources

**What it does**: Supports grid search, random search, and Bayesian optimization with customizable parameters

## Quick Configuration

### Basic Module
Edit `modules/03_model_tuning.R` (lines 29, 61, 98, 133):
- Change `resolution` to adjust grid size (higher = more combinations)
- Default: 3 for SVM/ANN (27 combos), 2 for RF/XGBoost (16-64 combos)

### Advanced Module
Edit `modules/03_model_tuning_advanced.R` (lines 11-24):
```r
TUNING_STRATEGY <- "random_search"  # "grid_search", "random_search", or "bayesian"
N_EVALS_SVM <- 30      # Number of combinations to test
N_EVALS_ANN <- 30
N_EVALS_RF <- 25
N_EVALS_XGB <- 40
N_FOLDS <- 5           # Number of CV folds
```

## Expected Results

### Performance Improvements
Typical improvements from hyperparameter tuning:
- **SVM**: 5-15% RMSE reduction
- **Neural Networks**: 10-20% RMSE reduction
- **Random Forest**: 3-10% RMSE reduction
- **XGBoost**: 5-15% RMSE reduction

### Outputs Created

After running tuning, you'll find:

**In `models/`**:
- `hyperparameter_tuning_summary.csv` - Summary of best parameters
- `*_tuning_results.RDS` - Detailed tuning history for each model
- `*_model.RDS` - Optimized model objects
- `tuning_comparison_results.csv` - Performance comparison

**In `plots/`**:
- `*_tuning_history.png` - Optimization progress over iterations
- `tuning_comparison_rmse.png` - Model performance comparison
- `tuning_comparison_r2.png` - R² comparison
- `tuning_comparison_multimetric.png` - Multi-metric comparison

## Time Requirements

### Basic Grid Search
- **SVM**: ~15-30 minutes
- **ANN**: ~20-40 minutes
- **Random Forest**: ~30-60 minutes
- **XGBoost**: ~45-90 minutes
- **Total**: ~2-4 hours

### Advanced (with default settings)
- **Similar to basic**, but configurable
- Can be faster with random search
- Can be more thorough with more evaluations

### Reducing Time
If you need faster results, edit the advanced module:
```r
N_EVALS_SVM <- 10      # Reduce from 30
N_EVALS_ANN <- 10      # Reduce from 30
N_EVALS_RF <- 10       # Reduce from 25
N_EVALS_XGB <- 15      # Reduce from 40
N_FOLDS <- 3           # Reduce from 5
```

## Required Packages

If you get errors, install these packages:

```r
install.packages(c(
  "mlr3tuning",     # Hyperparameter optimization
  "paradox",        # Parameter spaces
  "mlr3mbo"         # Bayesian optimization (optional)
))
```

## Checking Results

### View Summary in R
```r
# Load tuning summary
summary <- read.csv("models/hyperparameter_tuning_summary.csv")
print(summary)

# Load detailed results
svm_tuning <- readRDS("models/svm_tuning_results.RDS")
print(svm_tuning$result)  # Best parameters
print(svm_tuning$result_y) # Best RMSE
```

### View Comparison
```r
# Load comparison
comparison <- read.csv("models/tuning_comparison_results.csv")
print(comparison)
```

## Troubleshooting

### "Package mlr3tuning not found"
```r
install.packages("mlr3tuning")
install.packages("paradox")
```

### "Takes too long"
1. Use basic module instead of advanced
2. Reduce number of evaluations (see "Reducing Time" above)
3. Reduce CV folds from 5 to 3

### "Out of memory"
1. Reduce number of CV folds
2. Reduce num.trees for Random Forest
3. Run models one at a time (comment out others in the script)

### "All models fall back to regr.lm"
Install required packages:
```r
install.packages(c("e1071", "nnet", "ranger", "xgboost"))
install.packages("mlr3extralearners")
```

## Examples

### Example 1: Quick Test Run
Use advanced module with reduced evaluations:
```r
# Edit modules/03_model_tuning_advanced.R
N_EVALS_SVM <- 10
N_EVALS_ANN <- 10
N_EVALS_RF <- 10
N_EVALS_XGB <- 15
N_FOLDS <- 3
```
Run time: ~1 hour

### Example 2: Production Run
Use advanced module with default settings:
```r
# modules/03_model_tuning_advanced.R (default)
TUNING_STRATEGY <- "random_search"
N_EVALS_SVM <- 30
N_EVALS_ANN <- 30
N_EVALS_RF <- 25
N_EVALS_XGB <- 40
N_FOLDS <- 5
```
Run time: ~2-4 hours

### Example 3: Comprehensive Search
Use advanced module with increased evaluations:
```r
# Edit modules/03_model_tuning_advanced.R
TUNING_STRATEGY <- "random_search"
N_EVALS_SVM <- 50
N_EVALS_ANN <- 50
N_EVALS_RF <- 40
N_EVALS_XGB <- 80
N_FOLDS <- 5
```
Run time: ~4-8 hours

## Next Steps After Tuning

1. **Review results**: Check `models/hyperparameter_tuning_summary.csv`
2. **Compare performance**: Run `Rscript modules/compare_tuning_results.R`
3. **Examine plots**: Open files in `plots/tuning_*.png`
4. **Continue pipeline**: The optimized models will be used automatically in subsequent steps
5. **Use in production**: The tuned models are saved and ready for predictions

## Getting Help

- **Detailed documentation**: See `HYPERPARAMETER_TUNING_GUIDE.md`
- **Project overview**: See `CLAUDE.md`
- **mlr3 documentation**: https://mlr3book.mlr-org.com/
- **Tuning documentation**: https://mlr3tuning.mlr-org.com/

## Tips for Best Results

1. **Always use spatial CV**: Don't modify the spatial cross-validation setup
2. **Start small**: Test with reduced evaluations first
3. **Monitor progress**: Check console output during tuning
4. **Save baselines**: Keep original results for comparison
5. **Document changes**: Note which settings work best for your data
6. **Be patient**: Good tuning takes time, but improves results significantly

## Summary

You now have three ways to run your SOC prediction pipeline:

1. **`main.R`** - Original pipeline with fixed hyperparameters
2. **`main_with_tuning.R`** - New pipeline with automatic tuning
3. **Individual modules** - Maximum control over each step

For best results, use **`main_with_tuning.R`** with the advanced module and random search strategy.

Good luck with your hyperparameter optimization!
