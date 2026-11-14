# Soil organic carbon mapping in the Motupe River watershed, northern Peru

Data and code for the ensemble machine-learning analysis of soil organic carbon (SOC)
in the Motupe River watershed (Lambayeque, Peru), together with the R scripts that reproduce
the methods audit on ensemble combination. The audit itself is written up separately; this
record is the data and the code behind it.

This deposit accompanies the peer-reviewed article:

> Salazar-Coronel, W., Carbajal-Llosa, C., & Chuchón-Remón, R. (2026). Soil organic carbon
> content mapping along the coast of northern Peru: an ensemble machine learning approach.
> *Frontiers in Soil Science*, 6, 1745154. https://doi.org/10.3389/fsoil.2026.1745154

The article is open access under CC BY 4.0. **This deposit is what the article's data
availability statement promised**: the observations, the covariates, the fitted models and
the prediction surfaces, rather than an email address.

## Study area

| | |
|---|---|
| Basin | Motupe River watershed, Lambayeque region, northern Peru |
| Centre point | 6.314302° S, 79.59176° W |
| Area | 3,673.66 km² |
| Elevation | sea level to 3,500 m a.s.l. |
| Land cover | dry forest (*algarrobo Neltuma pallida*, *sapote Capparis scabrida*) below ~250 m; Andean grassland and pine/eucalyptus stands above ~1,500 m |
| Climate | below ~1,000 m: 13–35 °C, 69.02 mm year⁻¹; 1,500–3,500 m: 11–25 °C, 406.93 mm year⁻¹ (SENAMHI HSR PISCO) |
| Sampling | 109 composite samples (4 subsamples each), September–December 2023, locations randomised with the AcATaMa plugin in QGIS 3.38 |
| Laboratory | LABSAF-INIA, Vista Florida Experimental Station; SOC by ISO 10694:1996 |
| Target | SOC 0.42–0.87 %, mean 0.649 %, SD 0.1055 % |
| Mapping grid | 30 m, 4,089,160 valid pixels inside the basin mask |

Two derived figures frame every result in the deposit: **one soil sample per 33.7 km²**, and
**37,515 map pixels per sample**.

## What is in here

| Path | Contents |
|---|---|
| `data/soil_motupe_table.csv` | the 109 observations with UTM 17S coordinates and SOC (%) |
| `data/suelos_motupe_model.gpkg` | the same observations as an sf layer (`datos_carbono`) |
| `data/raw_data_Carbono.xlsx`, `data/metricas.xlsx` | field and laboratory workbook, and the metric workbooks |
| `data/borde_motupe.gpkg`, `data/buffer_motupe.*`, `data/uh_motupe_utm.*` | basin boundary, buffer and analysis unit |
| `data/predictors.tif` | **not shipped** — built from `predictors/` by `modules/02_preprocessing.R` |
| `predictors/*.tif` | the 13 covariate layers at 30 m: aspect, BD, Clay, EC, EVI, GNDVI, hillshade, pH, Silt, temp, TPI, TRI, TWI |
| `data/pp_*.tif`, `data/temp_*.tif` | the precipitation and temperature surfaces used to build the climate covariates |
| `data/covsoc_for_modeling.RDS`, `data/task_motupe_scaled.RDS`, `data/motupe.RDS` | modelling tables and the scaled `mlr3` task |
| `models/*.RDS` | fitted models, resampling objects, metric lists and the published `ensemble_weights.RDS` |
| `outputs/*_cv_predictions.csv` | **the out-of-fold matrix** — one row per sample, with fold, observed and predicted |
| `outputs/*_observed_vs_predicted.csv` | in-sample training predictions (the source of the metric mix-up the audit documents) |
| `outputs/*_prediction_spatial_cv.tif` | the four base-learner and two ensemble prediction surfaces at 30 m |
| `outputs/bootstrap_*.tif` | bootstrap uncertainty products: mean, SD, 5/50/95 quantiles, 90 % interval width, relative interval and PIR |
| `outputs/spatial_cv_report.md` | the auto-generated metrics table whose two columns disagree |
| `codes/`, `modules/` | the analysis pipeline (R, `mlr3` + `terra` + `gstat`) |
| `codes/ensemble_blog_figures.R` | reproduces every number and figure of the combiner audit |
| `codes/ensemble_blog_extras.R` | the fourteen-combiner comparison, apparent versus cross-fitted |
| `figures/`, `plots/` | figures as published in the post, and the pipeline's own diagnostic plots |
| `docs/` | methodology, uncertainty and validation documentation written during the analysis |
| `REPRODUCIBILITY.md` | the audit: what reproduces exactly, what reproduces approximately, and what does not reproduce at all |
| `fsoil-6-1745154.pdf` | the published article, as accepted and typeset (CC BY 4.0) |

## Reproducing the analysis -- read this before citing

The full audit, with causes and fixes, is in **`REPRODUCIBILITY.md`**. The short version:

| Task | Status |
|---|---|
| Reproduce the combiner audit (7 figures, 14 schemes, the 9.1 % diversity ceiling, the metric traps) | **yes** — `codes/ensemble_blog_figures.R` and `codes/ensemble_blog_extras.R`, no download beyond this archive |
| Recompute honest per-model metrics | **yes** — from `outputs/*_cv_predictions.csv`: RMSE 0.1434 SVR · 0.1253 ANN · 0.1129 RF · 0.1274 XGBoost |
| Rebuild the covariates and refit everything | **approximately** — no `renv.lock` was archived, so a refit is not bit-for-bit. The article ran on R 4.5.x; this archive was last exercised on R 4.6.0 with mlr3 1.8.0 |
| Regenerate the 30 m maps without refitting | **no** — `models/*_model.RDS` and `data/task_motupe_scaled.RDS` were written by an older mlr3 and fail under mlr3 ≥ 1.8 (`unused argument (data_format)`, `x is not a data.table`). The maps are shipped as GeoTIFF instead |
| Rebuild **the article's Table 4** | **no** — see `REPRODUCIBILITY.md`, section 3. The printed values appear in no artifact of this archive |

Two further gaps: `modules/07_uncertainty.R` line 12 sorts its ten bootstrap seeds from an unseeded
RNG state, so the uncertainty layer is not reproducible run to run; and no complete end-to-end
`codes/main.R` run was performed while preparing this audit.

Requires R ≥ 4.5.

```r
# 1. rebuild the covariate stack from the individual layers
source("modules/02_preprocessing.R")     # writes data/predictors.tif

# 2. the pipeline, in order
source("codes/main.R")                   # or codes/main_with_tuning.R for the grid search
                                         # hours: the grid search refits everything

# 3. the two scripts behind the combiner audit (minutes, no download needed)
source("codes/ensemble_blog_figures.R")  # figures 1-6
source("codes/ensemble_blog_extras.R")   # the fourteen-combiner menu, figure 7
```

Package dependencies: `terra`, `sf`, `mlr3`, `mlr3spatial`, `mlr3spatiotempcv`, `ranger`,
`e1071`, `xgboost`, `nnet`, `gstat`, `automap`, `ggplot2`, `patchwork`, `scales`, `MASS`,
`quadprog`, `quantreg`.

### Intermediate files that are not shipped

Three large intermediates are deliberately excluded because the pipeline rebuilds them, and
shipping 753 MB of derived blobs would make the deposit harder to use, not easier:

| Missing file | Rebuild with | Size when built |
|---|---|---|
| `data/predictors.tif` | `modules/02_preprocessing.R:11` (stacks `predictors/*.tif`) | 232 MB |
| `data/covariates_with_xy.RDS` | `modules/02_preprocessing.R:83` (extraction + coordinates) | 201 MB |
| `data/all_covariates_scaled_imputed.RDS` | `modules/06_prediction.R:104` (scaling + imputation) | 386 MB |
| `outputs/bootstrap_uncertainty_stack_spatial_cv.tif` | `modules/07_uncertainty.R:313` (10 bootstrap iterations) | 166 MB |

Every product of those steps that a reader is likely to want — the prediction surfaces, the
bootstrap moments and quantiles, the PIR layer, the out-of-fold predictions — **is** shipped.

### Upstream data

The covariates are derived from third-party products, cited rather than re-hosted:

- **Climate** — SENAMHI HSR PISCO precipitation and temperature (Peru).
- **Terrain** — a 30 m digital elevation model, from which aspect, hillshade, TPI, TRI and TWI were computed with `terra`.
- **Soil properties** — pH, EC, bulk density, sand, silt and clay interpolated by ordinary kriging with `gstat` and `automap`, fitted to observations from the same survey.
- **Vegetation indices** — NDVI, SAVI, GNDVI and EVI from Sentinel-2 Level-2A (COPERNICUS/S2_SR_HARMONIZED), collected 1 August–31 December 2023, scenes with < 10 % cloud, processed in Google Earth Engine.

The `pp_*.tif` and `temp_*.tif` rasters in `data/` are the climate products actually used, so
the covariate stack can be rebuilt without a SENAMHI download. The Sentinel-2 composites are
the one input that needs Earth Engine credentials to regenerate; the derived indices are what
`predictors/EVI.tif`, `GNDVI.tif` and the other vegetation layers already contain.

## Licences

- **Code** (`codes/`, `modules/`, `tools/`): MIT — see `LICENSE`.
- **Data, covariates, rasters and derived products**: CC BY 4.0 — see `LICENSE-data`, the same
  licence as the article, so a single attribution covers both.
- **The article PDF** (`fsoil-6-1745154.pdf`): CC BY 4.0, © 2026 Salazar-Coronel,
  Carbajal-Llosa and Chuchón-Remón, as published in *Frontiers in Soil Science*.
- **The combiner audit**, when published, will be CC BY 4.0 like the article. It is not part
  of this record: what is here is the code that produces its numbers.

## A note on this file

The copy of `README.md` **inside** `motupe-soc-ensemble-v1.0.0.zip` was written before two
corrections: it attributed `all_covariates_scaled_imputed.RDS` to `modules/02_preprocessing.R`
(it is `modules/06_prediction.R`), and its reproduction section read more optimistically than the
evidence supports. This record-level file and `REPRODUCIBILITY.md` are the current versions.

## Integrity

`SHA256SUMS.txt` lists the SHA-256 of every file in this record. To verify a downloaded copy:

```bash
shasum -a 256 -c SHA256SUMS.txt
```

## Citation

If you use the map, the SOC estimates or the uncertainty layer, cite the article. If you use
the code, the out-of-fold comparison or the combiner audit, cite this deposit as well.

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

The citation for this deposit, with its own DOI, is in `CITATION.cff`. Deposit DOI: TODO-DEPOSIT-DOI

## Contact

Corresponding author of the article: Carlos Carbajal-Llosa. Issues with the code or the data in
this deposit are best raised on the repository —
https://github.com/ccarbajal16/motupe-soc-ensemble — so that the answer stays visible to the
next reader.
