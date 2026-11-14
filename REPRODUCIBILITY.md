# Reproducibility, honestly

This document is an **audit**, not a promise. Every claim below was checked against the files in
the repository and in the Zenodo deposit. Where something does not reproduce, it says so, gives
the number, and names the cause.

Record: [doi:10.5281/zenodo.24212914](https://doi.org/10.5281/zenodo.24212914) (concept DOI,
always the latest version; the current one is v1.1.0, doi:10.5281/zenodo.24214911) ·
Code: [github.com/ccarbajal16/motupe-soc-ensemble](https://github.com/ccarbajal16/motupe-soc-ensemble)
Article: [doi:10.3389/fsoil.2026.1745154](https://doi.org/10.3389/fsoil.2026.1745154)

## The short version

| Question | Answer |
|---|---|
| Can I reproduce the analysis of ensemble combination (7 figures, 14 schemes, the diversity ceiling, the metric audit)? | **Yes.** Two scripts, no download beyond the repository. |
| Can I recompute the honest per-model metrics? | **Yes**, from `outputs/*_cv_predictions.csv`. |
| Can I rebuild the covariate stack and refit everything? | **Yes**, from `predictors/*.tif` plus the soil table — but not bit-for-bit (see below). |
| Can I rebuild the accuracy table printed in the article (Table 4)? | **No.** Not from this archive, not from the repository, not from any combination of the two. |
| Can I regenerate the published 30 m maps without refitting? | **No.** The maps are shipped as GeoTIFF; the serialized models do not load under current package versions. |

## 1. What reproduces exactly

| What | How | Evidence |
|---|---|---|
| Every figure and table of the combiner audit: 7 figures, the 14-scheme menu, the 9.1 % diversity ceiling, the four metric traps | `source("codes/ensemble_blog_figures.R")` and `source("codes/ensemble_blog_extras.R")` | Both scripts were run from the repository alone and reproduce the published numbers |
| Honest per-model metrics from the out-of-fold matrix | `outputs/*_cv_predictions.csv` | RMSE **0.1434** SVR · **0.1253** ANN · **0.1129** RF · **0.1274** XGBoost |
| The covariate stack | `predictors/*.tif` | 13 layers, 2598 × 3389 cells, EPSG 32717, band names match what the models expect |
| The 109 observations | `data/soil_motupe_table.csv` | Present, complete. Predictors are **not** in that CSV; they are extracted from the rasters, as `modules/02_preprocessing.R` does |
| The pipeline's own wiring | `modules/02` rebuilds the task and the modelling tables, `modules/03` the four learners, `modules/06` the scaled raster stack | Verified by reading the code: `codes/main.R` overwrites every stale artifact instead of depending on it |
| The published 30 m surfaces and the bootstrap uncertainty products | Shipped as GeoTIFF in this archive | Available for reuse and for inspection; not recomputed here |

**Not verified:** a complete end-to-end `codes/main.R` run. The grid search takes hours, and no
full run was performed while preparing this audit. What was verified is the wiring, the inputs,
and that each module regenerates its own derived files.

## 2. What reproduces only approximately

| Gap | Consequence |
|---|---|
| **No lockfile.** No `renv.lock` and no `sessionInfo()` were archived. The article ran on R 4.5.x; this archive was last exercised on R 4.6.0 with mlr3 1.8.0, terra 1.9.46, ranger 0.18.0 and xgboost 3.2.1.1 | A refit can differ in the third decimal, and can differ more if a learner's defaults changed across a major version |
| **The serialized objects are stale.** `data/task_motupe_scaled.RDS` was written by an older mlr3: under mlr3 1.8.0, `task$data()` fails with `unused argument (data_format)`, and `models/*_model.RDS` fail with `x is not a data.table` | The stored task and models cannot be used to regenerate maps without a refit. `codes/main.R` sidesteps this by recreating them, so the pipeline still runs — what is unusable is the **artifacts**, not the code |
| **The bootstrap draw is not seeded.** `modules/07_uncertainty.R` line 12 sorts the ten bootstrap seeds with `sample()` from whatever RNG state the session carries. Only the iterations themselves are seeded (`set.seed(seed_val)` inside the loop) | The uncertainty layer is not reproducible run to run, even on identical package versions. The fix is one line: `set.seed()` before that draw |

The modelling steps themselves **are** seeded: `set.seed(50)` in `modules/03_model_tuning.R` and
`modules/04_spatial_cv.R`, and a per-iteration seed in `modules/07_uncertainty.R`. Seeding without
pinned package versions is necessary but not sufficient.

## 3. What does not reproduce: Table 4 of the article

The accuracy table printed in the article cannot be rebuilt from any artifact in this archive or
in the repository. Recomputing it every legal way:

| Source | SVR | ANN | RF | XGBoost |
|---|---|---|---|---|
| `outputs/*_cv_predictions.csv` — RMSE | 0.1434 | 0.1253 | 0.1129 | 0.1274 |
| `models/*_cv.RDS$results` — RMSE (mlr3 aggregate, mean of folds) | 0.1440 | 0.1172 | 0.1102 | 0.1210 |
| `models/*_cv.RDS$results` — R² | −1.11 | −0.36 | −0.18 | −0.44 |
| **Table 4 as printed** — RMSE | 0.105 | 0.113 | 0.108 | 0.111 |
| **Table 4 as printed** — R² | 0.004 | 0.136 | 0.626 | 0.833 |

The printed values are not in the out-of-fold CSVs, not in the `.RDS` objects, and not in
`data/metricas.xlsx` or `data/all_models_observed_vs_predicted.xlsx` (searched as strings). They
cannot be reconstructed from what was published.

What this archive *does* reproduce is the honest version of that table, and the code that
explains the printed one:

- `modules/05_ensemble.R` replaces any non-positive cross-validated R² with a value recomputed on
  the model's **training** rows and clamped into `[0, 1]` — the clamp that produced the R² column.
- `modules/08_evaluation_and_report.R` computes the ensemble metrics on training data while the
  base learners were scored out-of-fold — two measurement bases in one table.
- `codes/ensemble_blog_figures.R` reproduces both effects, and `codes/ensemble_blog_extras.R`
  shows the same conclusion from fourteen combination schemes.

**Therefore:** this archive supports the analysis, the audit, and the honest metrics. It does not
support a claim that the numbers printed in Table 4 of the article can be regenerated, and it
should not be cited as if it did.

## 4. Known defects of this archive, and where the fix lives

| Defect | Status |
|---|---|
| `data/all_covariates_scaled_imputed.RDS` was attributed to `modules/02_preprocessing.R`; it is actually written by `modules/06_prediction.R:104` | Corrected in this document and in the record-level `README.md`; the copy inside `motupe-soc-ensemble-v1.0.0.zip` (v1.0.0) still carries the old wording |
| The uncertainty layer is not reproducible (unseeded bootstrap draw) | Documented above; the one-line fix belongs in a future code release, not in this archive |
| Serialized task and models are incompatible with mlr3 ≥ 1.8 | Documented above; regenerate them with `codes/main.R`, or install the versions the article used |

## 5. What would make this fully reproducible

Ordered by how much each item buys:

1. **`renv.lock` + `sessionInfo()`** committed with the code. Without it, "reproducible" means
   "reproducible in the author's session".
2. **`set.seed()` before the bootstrap seed draw** in `modules/07_uncertainty.R`.
3. **Regenerate the serialized artifacts** with the pinned versions, or delete them and let the
   pipeline create them — a stale `.RDS` is worse than an absent one.
4. **One script that prints the honest table next to the published one**, so the comparison is a
   command and not an argument.
5. **Record the fold assignment explicitly** in the archive, so a reader can reuse the exact
   five spatial folds that produced the published numbers instead of generating new ones.

## A note on what this document is not

It is not a retraction: every measurement in the article stands as what it measured. It is a map
of which claims a reader can check, which they cannot, and why — written by the people whose work
it is, before a reviewer has to ask.
