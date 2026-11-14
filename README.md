# Motupe SOC ensemble — analysis code

Reproducible R code for the soil organic carbon (SOC) mapping of the **Motupe River
watershed** (Lambayeque, Peru) and for the methods audit published alongside it.

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.24212914.svg)](https://doi.org/10.5281/zenodo.24212914)
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
post, because all of them are computed from `outputs/*_cv_predictions.csv`. It is **not** enough to
reproduce the article's Table 4 — see [Reproducibility, honestly](#reproducibility-honestly).

It does **not** hold the covariate rasters (224 MB) or the prediction surfaces (240 MB): Git is
the wrong place for binary grids, and a 460 MB clone is a clone nobody makes. Those live in a
Zenodo deposit with its own DOI — see **[Data you need](#data-you-need)** below.

## Reproducibility, honestly

Every claim in this section was checked against the files here and in the deposit. Where something
does not reproduce, it says so and gives the number. The full audit, with causes and fixes, is in
**[`REPRODUCIBILITY.md`](REPRODUCIBILITY.md)**.

| Task | Needs | Status |
|---|---|---|
| Reproduce the combiner audit: 7 figures, 14 schemes, the 9.1 % diversity ceiling, the four metric traps | this repository alone | **yes — verified**; `codes/ensemble_blog_figures.R` and `codes/ensemble_blog_extras.R` run and reproduce the published numbers |
| Recompute honest per-model metrics | `outputs/*_cv_predictions.csv` | **yes — verified**: RMSE 0.1434 SVR · 0.1253 ANN · 0.1129 RF · 0.1274 XGBoost |
| Rebuild the covariate stack and refit everything | `predictors/*.tif` from the deposit, plus the soil table | **yes, approximately** — no `renv.lock` was archived, so a refit is not bit-for-bit |
| Regenerate the published 30 m maps without refitting | `models/*_model.RDS` | **no** — the serialized task and models were written by an older mlr3 and fail under mlr3 ≥ 1.8 (`unused argument (data_format)`, `x is not a data.table`). The maps are shipped in the deposit instead |
| Rebuild **Table 4 of the article** | — | **no** |

The last row deserves the space. Recomputing the article's accuracy table every legal way:

| Source | SVR | ANN | RF | XGBoost |
|---|---|---|---|---|
| `outputs/*_cv_predictions.csv` — RMSE | 0.1434 | 0.1253 | 0.1129 | 0.1274 |
| `models/*_cv.RDS$results` — RMSE | 0.1440 | 0.1172 | 0.1102 | 0.1210 |
| `models/*_cv.RDS$results` — R² | −1.11 | −0.36 | −0.18 | −0.44 |
| **Table 4 as printed** — RMSE / R² | 0.105 / 0.004 | 0.113 / 0.136 | 0.108 / 0.626 | 0.111 / 0.833 |

Those printed values are not in the CSVs, not in the `.RDS` objects, and not in the metric
workbooks. What this repository reproduces is the **honest version** of the table, and the code
that explains the printed one: the cross-validated R² clamp in `modules/05_ensemble.R` and the
training-scored ensemble metrics in `modules/08_evaluation_and_report.R`.

So: this repository reproduces the analysis, the audit and the honest metrics. **It does not
reproduce the numbers printed in the article's Table 4, and it should not be cited as doing so.**

Two further gaps, both fixable and both documented in `REPRODUCIBILITY.md`:
`modules/07_uncertainty.R` sorts its ten bootstrap seeds from an unseeded RNG state (line 12), so
the uncertainty layer varies between runs even on identical package versions; and a full
`codes/main.R` end-to-end run was not performed while preparing this audit — the wiring, the
inputs and the per-module regeneration were verified instead, and the grid search takes hours.

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

Two DOIs, on purpose:

- **`10.5281/zenodo.24212914`** — the *concept* DOI. Always resolves to the latest version. Use it
  when you mean "the dataset".
- **`10.5281/zenodo.24214911`** — the *version* DOI, v1.1.0. Use it when you need exactly the files
  you worked with. Version 1.0.0 (`10.5281/zenodo.24212915`) shipped the same archive with
  record-level documentation that predates the reproducibility audit.

```bash
# 24214911 is the numeric id of the version you want; it is the DOI suffix
curl -L -o motupe-data.zip "https://zenodo.org/records/24214911/files/motupe-soc-ensemble-v1.0.0.zip"
unzip motupe-data.zip
cp -R motupe-soc-ensemble-v1.0.0/predictors .
cp motupe-soc-ensemble-v1.0.0/outputs/*.tif outputs/
shasum -a 256 -c motupe-soc-ensemble-v1.0.0/SHA256SUMS.txt
```

Four large intermediates are **deliberately absent** and rebuilt by the pipeline, so do not go
looking for them. Which module writes each one:

| Missing file | Written by | Size when built |
|---|---|---|
| `data/predictors.tif` | `modules/02_preprocessing.R:11` (stacks `predictors/*.tif`) | 232 MB |
| `data/covariates_with_xy.RDS` | `modules/02_preprocessing.R:83` | 201 MB |
| `data/all_covariates_scaled_imputed.RDS` | `modules/06_prediction.R:104` | 386 MB |
| `outputs/bootstrap_uncertainty_stack_spatial_cv.tif` | `modules/07_uncertainty.R:313` | 166 MB |

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
REPRODUCIBILITY.md   what reproduces, what does not, and why -- read this before citing
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
