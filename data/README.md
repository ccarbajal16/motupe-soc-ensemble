# data/

Everything small that the analysis reads: the 109 SOC observations
(`soil_motupe_table.csv`, `suelos_motupe_model.gpkg`), the basin boundary and analysis unit,
the climate surfaces the covariates were built from, and the modelling tables.

## What is not here

| Missing file | Size | Why | How to get it |
|---|---|---|---|
| `predictors.tif` | 232 MB | derived: the stack of the 13 layers in `../predictors/` | `source("modules/02_preprocessing.R")` |
| `covariates_with_xy.RDS` | 201 MB | derived: covariate extraction at the 109 points | `source("modules/02_preprocessing.R")` |
| `all_covariates_scaled_imputed.RDS` | 386 MB | derived: scaled and imputed modelling table | `source("modules/02_preprocessing.R")` |
| `predictors/*.tif` (in the parent directory) | 224 MB | binary grids, not versioned | Zenodo deposit, see the root README |

The 109 observations are the only irreplaceable input and they are 6.7 KB of CSV, so they are
here, fully.
