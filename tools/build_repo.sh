#!/usr/bin/env bash
# build_repo.sh -- stage the GitHub repository: code, small data, docs, figures.
#
# The GitHub repository is the DIFFABLE artifact: pipeline, fitted objects,
# out-of-fold predictions, observations, documentation, figures. The heavy
# rasters (predictors/, outputs/*.tif) stay out and come from the Zenodo
# deposit, because a 460 MB clone is a clone nobody makes.
#
# Usage:
#   tools/build_repo.sh                    # stage dist/github/
#   tools/build_repo.sh --dry-run          # print the plan only
#   tools/build_repo.sh --allow-placeholder  # rehearsal before a DOI is reserved
#   tools/build_repo.sh --with-post          # also include the draft methods post
#
# Run from the repository root.

set -euo pipefail

DEST="dist/github"
DRY_RUN=0
ALLOW_PLACEHOLDER=0
WITH_POST=0
for arg in "$@"; do
  [[ "$arg" == "--dry-run" ]] && DRY_RUN=1
  [[ "$arg" == "--allow-placeholder" ]] && ALLOW_PLACEHOLDER=1
  [[ "$arg" == "--with-post" ]] && WITH_POST=1
done

INCLUDE_DIRS=(
  "codes"      # the pipeline entry points and the two post scripts
  "modules"    # 01_setup ... 08_evaluation_and_report
  "models"     # fitted models, metrics, ensemble weights (384 KB)
  "docs"       # methodology, uncertainty and validation write-ups
  "figures"    # the figures of the methods post
  "zenodo"     # deposit metadata and licences
  "tools"      # the deposit toolchain, so the record is reproducible
)

# data/ minus the three big derived tables
INCLUDE_DATA=(
  "soil_motupe_table.csv"
  "suelos_motupe_model.gpkg"
  "borde_motupe.gpkg"
  "soil_predictors.gpkg"
  "raw_data_Carbono.xlsx"
  "metricas.xlsx"
  "all_models_observed_vs_predicted.xlsx"
  "all_models_observed_vs_predicted.ods"
  "covsoc_for_modeling.RDS"
  "task_motupe_scaled.RDS"
  "motupe.RDS"
  "pp_total_utm.tif" "temp_average_utm.tif"
  "pp_media_motupe_geo.tif" "pp_media_motupe_geo2.tif"
  "temp_media_motupe_geo.tif" "temp_media_motupe_geo2.tif"
  "buffer_motupe.shp" "buffer_motupe.shx" "buffer_motupe.dbf" "buffer_motupe.prj" "buffer_motupe.cpg"
  "uh_motupe_utm.shp" "uh_motupe_utm.shx" "uh_motupe_utm.dbf" "uh_motupe_utm.prj" "uh_motupe_utm.cpg"
)

# outputs/ minus every .tif
INCLUDE_OUTPUT=(
  "all_models_observed_vs_predicted.csv"
  "ann_cv_predictions.csv" "rf_cv_predictions.csv"
  "svm_cv_predictions.csv" "xgb_cv_predictions.csv"
  "ann_observed_vs_predicted.csv" "rf_observed_vs_predicted.csv"
  "svm_observed_vs_predicted.csv" "xgb_observed_vs_predicted.csv"
  "ensemble_avg_observed_vs_predicted.csv"
  "ensemble_weighted_observed_vs_predicted.csv"
  "spatial_cv_report.md"
  "uncertainty_analysis_statistics.csv"
  "bootstrap_uncertainty_statistics.csv"
)

cat <<'EOF'
=== NOT in the GitHub repository, and why ===
predictors/*.tif (224 MB)              binary covariate layers -> Zenodo deposit
outputs/*.tif (240 MB)                 30 m prediction surfaces -> Zenodo deposit
data/predictors.tif (232 MB)           rebuilt by modules/02_preprocessing.R
data/covariates_with_xy.RDS (201 MB)   rebuilt by modules/02_preprocessing.R
data/all_covariates_scaled_imputed.RDS rebuilt by modules/02_preprocessing.R
outputs/bootstrap_uncertainty_stack*.tif  intermediate; the products are in the deposit
plots/ (2.3 MB)                        pipeline diagnostics, redundant with figures/
Figuras_JPG/, fsoil-*.pdf              the published article, reachable at its DOI
2026-08-29-should-you-combine-your-models.md   included only on request (see --with-post)
.PHONY: junk                           .DS_Store, *.qix, .atl/
EOF

[[ $DRY_RUN -eq 1 ]] && { echo; echo "=== would stage into $DEST ==="; printf '  %s/\n' "${INCLUDE_DIRS[@]}"; exit 0; }

# the staged tree is a real git repository once it has been pushed, so its
# .git must survive a rebuild
GIT_BACKUP=""
if [[ -d "$DEST/.git" ]]; then
  GIT_BACKUP="dist/.github-git"
  rm -rf "$GIT_BACKUP"
  mv "$DEST/.git" "$GIT_BACKUP"
fi

rm -rf "$DEST"
mkdir -p "$DEST"/{data,outputs}

for d in "${INCLUDE_DIRS[@]}"; do
  [[ -d "$d" ]] || continue
  mkdir -p "$DEST/$d"
  rsync -a --exclude '.DS_Store' --exclude '*.qix' --exclude '*.qmd' --exclude '.deposit-state.json' \
        --exclude 'REPRODUCIBILITY.md' \
        "$d"/ "$DEST/$d"/
done

for f in "${INCLUDE_DATA[@]}";   do [[ -f "data/$f" ]]    && cp "data/$f"    "$DEST/data/$f";    done
for f in "${INCLUDE_OUTPUT[@]}"; do [[ -f "outputs/$f" ]] && cp "outputs/$f" "$DEST/outputs/$f"; done

# --- root files -------------------------------------------------------------
cp repo/README.md      "$DEST/README.md"
cp zenodo/LICENSE      "$DEST/LICENSE"
cp zenodo/LICENSE-data "$DEST/LICENSE-data"
cp zenodo/CITATION.cff "$DEST/CITATION.cff"
cp .gitignore          "$DEST/.gitignore"
cp zenodo/REPRODUCIBILITY.md "$DEST/REPRODUCIBILITY.md"   # at the root: the README links to it

# data/README.md: say out loud what is missing from data/ and where to get it
cat > "$DEST/data/README.md" <<'ELS'
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
ELS

# --- optional: the methods post --------------------------------------------
if [[ $WITH_POST -eq 1 ]]; then
  cp 2026-08-29-should-you-combine-your-models.md "$DEST/"
fi

# --- the ambiguity guard ----------------------------------------------------
# --- guard: refuse to package ambiguous or duplicate filenames -------------
# A Finder "duplicate" arrives as "name 3.ext" next to "name.ext": two files,
# same content, different names, and both would end up in the deposit.
SPACED="$(cd "$DEST" && find . -type f -name '* *' -not -path './.git/*' | head -10)"
if [[ -n "$SPACED" ]]; then
  echo "refusing to package: filenames containing spaces (Finder-style duplicates?)" >&2
  echo "$SPACED" >&2
  echo "remove them from the source tree and re-run." >&2
  exit 1
fi

# --- stamp the reserved DOI, as build_deposit.sh does ----------------------
DEPOSIT_DOI=""
CONCEPT_DOI=""
if [[ -f zenodo/.deposit-state.json ]]; then
  DEPOSIT_DOI="$(python3 -c 'import json;print(json.load(open("zenodo/.deposit-state.json")).get("doi",""))' 2>/dev/null || true)"
  CONCEPT_DOI="$(python3 -c 'import json;print(json.load(open("zenodo/.deposit-state.json")).get("concept_doi",""))' 2>/dev/null || true)"
fi
[[ -z "$CONCEPT_DOI" ]] && CONCEPT_DOI="$DEPOSIT_DOI"
if [[ -n "$DEPOSIT_DOI" ]]; then
  RECORD_ID="${DEPOSIT_DOI##*.}"        # 10.5281/zenodo.1234 -> 1234
  for f in "$DEST/README.md" "$DEST/CITATION.cff"; do
    perl -pi -e "s{TODO-DEPOSIT-DOI}{$DEPOSIT_DOI}g; s{<RECORD_ID>}{$RECORD_ID}g" "$f"
  done
  BADGE="[![DOI](https://zenodo.org/badge/DOI/$CONCEPT_DOI.svg)](https://doi.org/$CONCEPT_DOI)"
  perl -pi -e "s{<!-- DOI-BADGE -->}{$BADGE}" "$DEST/README.md"
  perl -pi -e "s{^# DOI-LINE\$}{doi: \"$DEPOSIT_DOI\"\nurl: \"https://doi.org/$DEPOSIT_DOI\"}" "$DEST/CITATION.cff"
  echo "DOI stamped: $DEPOSIT_DOI (record $RECORD_ID)"
elif [[ $ALLOW_PLACEHOLDER -eq 1 ]]; then
  # a badge pointing at a DOI that does not exist renders as a broken image,
  # so the marker is dropped rather than left in place
  perl -ni -e 'print unless m{<!-- DOI-BADGE -->}' "$DEST/README.md"
  perl -ni -e 'print unless m{^# DOI-LINE$}' "$DEST/CITATION.cff"
  echo "WARNING: no reserved DOI yet -- badge omitted, README/CITATION keep the placeholder" >&2
else
  echo "refusing to build: no reserved DOI in zenodo/.deposit-state.json" >&2
  echo "  run tools/zenodo_deposit.py create first, or pass --allow-placeholder" >&2
  exit 1
fi

[[ -n "$GIT_BACKUP" ]] && mv "$GIT_BACKUP" "$DEST/.git"

echo
echo "=== STAGED FOR GITHUB ==="
du -sh "$DEST"/* | sort -hr
echo
# count the staged content, not the .git directory that survives rebuilds
count=$(find "$DEST" -type f -not -path '*/.git/*' | wc -l | tr -d ' ')
bytes=$(find "$DEST" -type f -not -path '*/.git/*' -print0 \
        | xargs -0 stat -f%z | awk '{s+=$1} END {printf "%.1f", s/1048576}')
echo "files: $count"
echo "size:  ${bytes} MB"
echo "tree:  $DEST"
