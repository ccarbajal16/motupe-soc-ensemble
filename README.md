# Motupe SOC ensemble — analysis code

Reproducible R code for the soil organic carbon (SOC) mapping of the **Motupe River
watershed** (Lambayeque, Peru) and for the methods audit published alongside it.

[![License: MIT](https://img.shields.io/badge/code-MIT-blue.svg)](LICENSE)
[![License: CC BY 4.0](https://img.shields.io/badge/data-CC%20BY%204.0-lightgrey.svg)](LICENSE-data)

Accompanies:

> Salazar-Coronel, W., Carbajal-Llosa, C., & Chuchón-Remón, R. (2026). Soil organic carbon
> content mapping along the coast of northern Peru: an ensemble machine learning approach.
> *Frontiers in Soil Science*, 6, 1745154. https://doi.org/10.3389/fsoil.2026.1745154 — open access, CC BY 4.0.

## What this repository is, and what it is not

This repository holds **everything that is text and small enough to diff**: the pipeline, the
fitted model objects, the out-of-fold predictions, the observations, the documentation and the
figures. That is enough to reproduce every table, every metric and every figure of the methods
post, because all of them are computed from `outputs/*_cv_predictions.csv`.

It does **not** hold the covariate rasters (224 MB) or the prediction surfaces (240 MB): Git is
the wrong place for binary grids, and a 460 MB clone is a clone nobody makes. Those live in a
Zenodo deposit with its own DOI — see **[Data you need](#data-you-need)** below.

So, honestly stated:

| Task | Needs | Works from a plain clone? |
|---|---|---|
| Recompute every metric, every table, both combiner menus, all seven figures | `outputs/*_cv_predictions.csv`, `models/*.RDS` | **yes** |
| Refit the four learners, the ensembles and the uncertainty layer | the covariate stack (`predictors/`), from Zenodo | no — download first |
| Produce the published 30 m prediction maps | the prediction rasters, from Zenodo | no — download first |

## Quick start

```r
# 1. the scripts behind the methods post: no download needed
source("codes/ensemble_blog_figures.R")   # every number in the post, figures 1-6
source("codes/ensemble_blog_extras.R")    # the fourteen-combiner menu, figure 7

# 2. the full pipeline, after fetching the rasters from Zenodo (see below)
source("modules/02_preprocessing.R")      # builds data/predictors.tif from predictors/
source("codes/main.R")                    # or codes/main_with_tuning.R for the grid search
```

Requires R ≥ 4.5 with `terra`, `sf`, `mlr3`, `mlr3spatial`, `mlr3spatiotempcv`, `ranger`,
`e1071`, `xgboost`, `nnet`, `gstat`, `automap`, `ggplot2`, `patchwork`, `scales`, `MASS`,
`quadprog`, `quantreg`.

## Data you need

Two directories are downloaded, not cloned:

| Directory | Contents | Size | Where |
|---|---|---|---|
| `predictors/` | the 13 covariate layers at 30 m — aspect, BD, Clay, EC, EVI, GNDVI, hillshade, pH, Silt, temp, TPI, TRI, TWI | 224 MB | Zenodo deposit |
| `outputs/*.tif` | the four base-learner surfaces, the two ensembles, and the bootstrap uncertainty products (mean, SD, quantiles, interval width, relative interval, PIR) | 240 MB | Zenodo deposit |

```bash
# the deposit DOI is in the badge at the top of this README
curl -L -o motupe-data.zip "https://zenodo.org/records/<RECORD_ID>/files/motupe-soc-ensemble-v1.0.0.zip"
unzip motupe-data.zip
cp -R motupe-soc-ensemble-v1.0.0/predictors .
cp motupe-soc-ensemble-v1.0.0/outputs/*.tif outputs/
shasum -a 256 -c motupe-soc-ensemble-v1.0.0/SHA256SUMS.txt
```

Three large intermediates are **deliberately absent** and rebuilt by the pipeline, so do not go
looking for them: `data/predictors.tif`, `data/covariates_with_xy.RDS`,
`data/all_covariates_scaled_imputed.RDS` and `outputs/bootstrap_uncertainty_stack_spatial_cv.tif`.
The covariate stack, for instance, is three lines in `modules/02_preprocessing.R`.

## Layout

```
codes/          the pipeline entry points, plus the two scripts behind the methods post
modules/        01_setup ... 08_evaluation_and_report -- the pipeline, step by step
models/         fitted models, resampling objects, metric lists, published ensemble weights
outputs/        out-of-fold predictions, per-sample predictions, metrics report
data/           the 109 observations, boundary, masks, climate surfaces, modelling tables
docs/           methodology, uncertainty and validation write-ups produced during the analysis
figures/        the figures of the methods post
zenodo/         deposit metadata and licences (the deposit is built from this repository)
tools/          build_deposit.sh, zenodo_deposit.py -- how the Zenodo record is made
```

## The finding, in one line

The published ensemble did not beat XGBoost, and the reason is not sophistication: the four
learners' out-of-fold errors correlate between **0.85 and 0.94**, so only **9.1%** of the mean
member error was available to any combiner. Every one of fourteen combination schemes — including
Bates–Granger, convex NNLS, hill-climbing, ridge, LAD and a neural meta-learner — scores worse
than predicting the basin mean (RMSE 0.1050). The diagnostic takes ten lines and is in
`codes/ensemble_blog_figures.R`, section 2.

## Licences

- **Code** (`codes/`, `modules/`, `tools/`): MIT — see [`LICENSE`](LICENSE).
- **Data, rasters and derived products**: CC BY 4.0 — see [`LICENSE-data`](LICENSE-data).
- **Figures and the methods post**: CC BY 4.0.
- **The article** is CC BY 4.0 and lives at its DOI, not here.

## Citation

Cite the article for the map and the SOC estimates; add the Zenodo DOI for the data and code.
Machine-readable metadata is in [`CITATION.cff`](CITATION.cff).

```bibtex
@article{SalazarCoronel2026SOC,
  author  = {Salazar-Coronel, Wilian and Carbajal-Llosa, Carlos and Chuch{\'o}n-Rem{\'o}n, Rodolfo},
  title   = {Soil organic carbon content mapping along the coast of northern Peru:
             an ensemble machine learning approach},
  journal = {Frontiers in Soil Science},
  volume  = {6},
  pages   = {1745154},
  year    = {2026},
  doi     = {10.3389/fsoil.2026.1745154}
}
```
