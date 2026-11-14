# Hyperparameter Tuning Guide

## Overview

This guide explains the new hyperparameter optimization modules for improving model performance in the SOC prediction project.

## Available Modules

### 1. Basic Grid Search (`03_model_tuning.R`)
**Best for**: Systematic exploration of smaller parameter spaces

**Features**:
- Grid search with spatial cross-validation
- Moderate number of evaluations (16-64 per model)
- Balanced between computation time and thoroughness
- Good for understanding parameter interactions

**Use when**:
- You want systematic coverage of parameter space
- Computational resources are moderate
- You need reproducible results

### 2. Advanced Multi-Strategy (`03_model_tuning_advanced.R`)
**Best for**: Flexible optimization with various strategies

**Features**:
- Supports Grid Search, Random Search, and Bayesian Optimization
- Larger search spaces with more parameters
- Configurable number of evaluations
- Visualization of tuning progress
- Detailed performance tracking

**Use when**:
- You want to experiment with different tuning strategies
- You have more computational resources
- You need comprehensive hyperparameter exploration

## How to Use

### Method 1: Replace the Original Module

1. **Backup the original module** (optional):
```bash
copy modules\03_model_definition.R modules\03_model_definition_original.R
```

2. **Choose your tuning approach**:

   **Option A: Basic Grid Search**
   ```bash
   copy modules\03_model_tuning.R modules\03_model_definition.R
   ```

   **Option B: Advanced Multi-Strategy**
   ```bash
   copy modules\03_model_tuning_advanced.R modules\03_model_definition.R
   ```

3. **Run the complete pipeline**:
```bash
Rscript main.R
```

### Method 2: Direct Execution

Run the tuning module directly:

```bash
# Basic grid search
Rscript modules/03_model_tuning.R

# Advanced tuning
Rscript modules/03_model_tuning_advanced.R
```

Then continue with the remaining modules:
```bash
Rscript modules/04_spatial_cv.R
Rscript modules/05_ensemble.R
# ... etc
```

## Tuning Strategies Comparison

### Grid Search
**Pros**:
- Systematic and reproducible
- Explores parameter space uniformly
- Easy to understand and visualize

**Cons**:
- Exponentially expensive with more parameters
- May waste evaluations on poor regions
- Fixed resolution can miss optimal values

**Best for**: 2-4 parameters with small-medium ranges

### Random Search
**Pros**:
- More efficient than grid search for many parameters
- Better coverage of parameter space
- Can find good solutions faster

**Cons**:
- Less systematic
- Results vary between runs
- May miss optimal combinations

**Best for**: 4+ parameters, large search spaces

### Bayesian Optimization
**Pros**:
- Most sample-efficient
- Learns from previous evaluations
- Focuses on promising regions
- Best for expensive evaluations

**Cons**:
- Requires additional package (mlr3mbo)
- More complex to configure
- Overhead for small problems

**Best for**: Expensive models, limited computation budget

## Configuration

### Adjusting the Advanced Module

Edit `03_model_tuning_advanced.R` to customize:

```r
# Line 11-12: Choose tuning strategy
TUNING_STRATEGY <- "random_search"  # Options: "grid_search", "random_search", "bayesian"

# Line 15-18: Number of evaluations per model
N_EVALS_SVM <- 30      # More evaluations = better optimization
N_EVALS_ANN <- 30
N_EVALS_RF <- 25
N_EVALS_XGB <- 40

# Line 21: Number of CV folds
N_FOLDS <- 5           # More folds = better validation, slower

# Line 24: Random seed
SEED <- 50             # For reproducibility
```

### Adjusting Search Spaces

To modify hyperparameter ranges, edit the `*_search_space` sections:

**Example - Expanding SVM search space**:
```r
svm_search_space <- paradox::ps(
  cost = paradox::p_dbl(lower = 0.01, upper = 500, logscale = TRUE),  # Wider range
  gamma = paradox::p_dbl(lower = 0.00001, upper = 5, logscale = TRUE),
  epsilon = paradox::p_dbl(lower = 0.0001, upper = 1.0)
)
```

**Parameter types**:
- `p_dbl()`: Continuous (decimal) parameters
- `p_int()`: Integer parameters
- `logscale = TRUE`: Search on log scale (good for wide ranges like 0.001 to 100)

## Hyperparameters Explained

### SVM (Support Vector Machine)
- **cost**: Regularization parameter (higher = more complex model)
- **gamma**: Kernel coefficient (higher = more local influence)
- **epsilon**: Width of epsilon-insensitive tube

### Neural Network (ANN)
- **size**: Number of hidden units (neurons in hidden layer)
- **decay**: Weight decay for regularization
- **maxit**: Maximum number of training iterations

### Random Forest
- **num.trees**: Number of trees in the forest
- **mtry**: Number of variables randomly sampled at each split
- **min.node.size**: Minimum number of observations in terminal nodes
- **sample.fraction**: Fraction of observations to sample
- **max.depth**: Maximum depth of trees

### XGBoost
- **nrounds**: Number of boosting iterations
- **eta**: Learning rate (step size shrinkage)
- **max_depth**: Maximum tree depth
- **subsample**: Subsample ratio of training instances
- **colsample_bytree**: Subsample ratio of columns when constructing each tree
- **min_child_weight**: Minimum sum of instance weight needed in a child
- **gamma**: Minimum loss reduction required to make a split
- **lambda**: L2 regularization term
- **alpha**: L1 regularization term

## Computational Considerations

### Estimated Running Times

**Basic Grid Search** (`03_model_tuning.R`):
- SVM: 27 evaluations × 5 folds = ~15-30 minutes
- ANN: 27 evaluations × 5 folds = ~20-40 minutes
- RF: 16 evaluations × 5 folds = ~30-60 minutes
- XGBoost: 64 evaluations × 5 folds = ~45-90 minutes
- **Total**: ~2-4 hours

**Advanced Random Search** (`03_model_tuning_advanced.R`):
- Depends on N_EVALS settings
- Default: ~2-5 hours total
- Can be reduced by lowering N_EVALS_* values

### Performance Optimization Tips

1. **Start small**: Begin with fewer evaluations to test the setup
```r
N_EVALS_SVM <- 10
N_EVALS_ANN <- 10
N_EVALS_RF <- 10
N_EVALS_XGB <- 15
```

2. **Use parallel processing**: The spatial CV already uses parallelization from module 01

3. **Reduce CV folds for testing**:
```r
N_FOLDS <- 3  # Faster, but less robust validation
```

4. **Prioritize models**: Focus tuning efforts on best-performing models
   - Skip tuning for underperforming models
   - Use more evaluations for top performers

## Outputs

### Saved Files

After tuning, you'll find these files in the `models/` directory:

1. **Optimized model objects**:
   - `svm_model.RDS`
   - `ann_model.RDS`
   - `rf_model.RDS`
   - `xgb_model.RDS`

2. **Tuning results**:
   - `svm_tuning_results.RDS`
   - `ann_tuning_results.RDS`
   - `rf_tuning_results.RDS`
   - `xgb_tuning_results.RDS`

3. **Summary report**:
   - `hyperparameter_tuning_summary.csv`

4. **Visualization** (advanced module only):
   - `plots/svm_tuning_history.png`
   - `plots/ann_tuning_history.png`
   - `plots/rf_tuning_history.png`
   - `plots/xgboost_tuning_history.png`

### Interpreting Results

The tuning summary CSV contains:
- **Model**: Algorithm name
- **Best_RMSE**: Lowest RMSE achieved during tuning
- **N_Evaluations**: Number of hyperparameter combinations tested
- **Strategy**: Tuning method used
- **Parameters**: Best hyperparameter values found

**Example**:
```
Model,Best_RMSE,N_Evaluations,Strategy,Parameters
SVM,2.3456,30,random_search,cost=45.2,gamma=0.08,epsilon=0.12
XGBoost,2.1234,40,random_search,nrounds=250,eta=0.05,max_depth=8,...
```

Lower RMSE indicates better model performance.

## Troubleshooting

### Common Issues

**1. "Package mlr3tuning not found"**
```r
install.packages("mlr3tuning")
install.packages("paradox")
```

**2. "Bayesian optimization requires mlr3mbo"**
```r
install.packages("mlr3mbo")
# Or change TUNING_STRATEGY to "random_search"
```

**3. Tuning takes too long**
- Reduce N_EVALS_* values
- Reduce N_FOLDS
- Start with grid search on small grid (resolution = 2)

**4. Out of memory errors**
- Reduce number of CV folds
- Reduce num.trees for Random Forest
- Process models sequentially (not in parallel)

**5. All models fall back to regr.lm**
- Check that mlr3extralearners is installed
- Verify required packages (e1071, nnet, ranger, xgboost)

## Best Practices

1. **Always use spatial CV**: Don't use random CV for spatial data - it overestimates performance

2. **Start with reasonable ranges**: Use domain knowledge or literature values as starting points

3. **Log scale for wide ranges**: Use `logscale = TRUE` for parameters spanning orders of magnitude

4. **Monitor progress**: Check intermediate outputs and tuning plots

5. **Document changes**: Keep notes on search spaces and results

6. **Validate final models**: Run full spatial CV (module 04) with optimized models

7. **Compare with baseline**: Keep the original non-tuned results for comparison

## Example Workflow

Complete example using advanced tuning:

```bash
# 1. Run setup and preprocessing
Rscript modules/01_setup_and_load.R
Rscript modules/02_preprocessing.R

# 2. Run advanced hyperparameter tuning
Rscript modules/03_model_tuning_advanced.R

# 3. Validate optimized models with spatial CV
Rscript modules/04_spatial_cv.R

# 4. Continue with ensemble and prediction
Rscript modules/05_ensemble.R
Rscript modules/06_prediction.R
Rscript modules/07_uncertainty.R
Rscript modules/08_evaluation_and_report.R
```

## References

- mlr3 book: https://mlr3book.mlr-org.com/
- mlr3tuning: https://mlr3tuning.mlr-org.com/
- Hyperparameter optimization: Bergstra & Bengio (2012) "Random Search for Hyper-Parameter Optimization"
- Spatial CV: Roberts et al. (2017) "Cross-validation strategies for data with temporal, spatial, hierarchical, or phylogenetic structure"
