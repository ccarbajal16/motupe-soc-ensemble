#!/usr/bin/env bash
# build_deposit.sh -- stage the Motupe SOC data + code package for Zenodo.
#
# Produces, inside dist/:
#   <NAME>/                  a clean tree that mirrors the repository
#   <NAME>/SHA256SUMS.txt    checksum of every staged file
#   <NAME>.zip               the same tree, zipped (for a local handoff/backup)
#
# Zenodo also serves its own zip of the whole record, so the local zip is a
# convenience, not the transport.
#
# Usage:
#   tools/build_deposit.sh                       # stage + checksums + zip
#   tools/build_deposit.sh --dry-run             # print the include/exclude plan only
#   tools/build_deposit.sh --allow-placeholder   # rehearsal before a DOI is reserved
#
# Run from the repository root.

set -euo pipefail

NAME="motupe-soc-ensemble-v1.0.0"
DEST="dist/$NAME"
DRY_RUN=0
ALLOW_PLACEHOLDER=0
for arg in "$@"; do
  [[ "$arg" == "--dry-run" ]] && DRY_RUN=1
  [[ "$arg" == "--allow-placeholder" ]] && ALLOW_PLACEHOLDER=1
done

# --- what goes in ------------------------------------------------------------
# Whole directories, staged as they are (minus junk):
INCLUDE_DIRS=(
  "codes"
  "modules"
  "models"
  "plots"
  "docs"
  "figures"
  "predictors"          # the 13 covariate layers: the actual source of the stack
)

# Individual directories that need a file filter:
INCLUDE_OUTPUT_CSV=(
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

# Every prediction and bootstrap map, i.e. every .tif in outputs/ except the
# 166 MB intermediate bootstrap stack.
INCLUDE_OUTPUT_TIF_PATTERN="^(ann|rf|svm|xgb|ensemble_avg|ensemble_weighted|bootstrap)_[a-z0-9_]*[.]tif$"
EXCLUDE_OUTPUT_TIF=("bootstrap_uncertainty_stack_spatial_cv.tif")

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

INCLUDE_ROOT=(
  "2026-08-29-should-you-combine-your-models.md"
  "fsoil-6-1745154.pdf"
)

# --- what stays behind, and why ---------------------------------------------
cat <<'EOF'
=== EXCLUDED, and the reason ===
data/predictors.tif                        232 MB  built by modules/02_preprocessing.R from predictors/
data/all_covariates_scaled_imputed.RDS     386 MB  derived: re-extracted from predictors/ + soil table
data/covariates_with_xy.RDS                201 MB  derived: same pipeline step
outputs/bootstrap_uncertainty_stack*.tif   166 MB  intermediate stack; the products (pir, q05..q95) are shipped
data/bootstrap_pir_90_spatial_cv.tif        18 MB  duplicate of outputs/bootstrap_pir_90_spatial_cv.tif
Figuras_JPG/                                18 MB  the paper's figures; the PDF is shipped instead
.atl/, .DS_Store, *.qix                             tooling caches and OS noise
EOF

if [[ $DRY_RUN -eq 1 ]]; then
  echo
  echo "=== would stage into $DEST ==="
  printf '  %s/\n' "${INCLUDE_DIRS[@]}"
  printf '  outputs/%s\n' "${INCLUDE_OUTPUT_CSV[@]}"
  printf '  outputs/<prediction and bootstrap .tif files>\n'
  printf '  data/%s\n' "${INCLUDE_DATA[@]}"
  printf '  %s\n' "${INCLUDE_ROOT[@]}"
  exit 0
fi

# --- stage ------------------------------------------------------------------
rm -rf "$DEST"
mkdir -p "$DEST"/{codes,modules,models,plots,docs,figures,predictors,data,outputs}

stage_tree() {
  local src="$1" dst="$2"
  rsync -a \
    --exclude '.DS_Store' --exclude '*.qix' --exclude '*.qmd' \
    --exclude '*.zip' --exclude '*.aux' --exclude '*.log' \
    "$src"/ "$dst"/
}

for d in "${INCLUDE_DIRS[@]}"; do
  [[ -d "$d" ]] && stage_tree "$d" "$DEST/$d"
done

for f in "${INCLUDE_OUTPUT_CSV[@]}"; do
  [[ -f "outputs/$f" ]] && cp "outputs/$f" "$DEST/outputs/$f"
done

while IFS= read -r tif; do
  base="$(basename "$tif")"
  skip=0
  for x in "${EXCLUDE_OUTPUT_TIF[@]}"; do [[ "$base" == "$x" ]] && skip=1; done
  [[ $skip -eq 0 ]] && cp "$tif" "$DEST/outputs/$base"
done < <(find outputs -maxdepth 1 -type f -name '*.tif' | sort)

for f in "${INCLUDE_DATA[@]}"; do
  [[ -f "data/$f" ]] && cp "data/$f" "$DEST/data/$f"
done

for f in "${INCLUDE_ROOT[@]}"; do
  [[ -f "$f" ]] && cp "$f" "$DEST/$f"
done

# --- documentation that must ship with the data -----------------------------
cp zenodo/README.md      "$DEST/README.md"
cp zenodo/LICENSE        "$DEST/LICENSE"
cp zenodo/LICENSE-data   "$DEST/LICENSE-data"
cp zenodo/CITATION.cff   "$DEST/CITATION.cff"

# --- stamp the reserved DOI into the copies, never into the templates -------
# A CITATION.cff pointing at a DOI that does not exist is worse than no
# CITATION.cff, so the build fails closed unless the placeholder is allowed.
DEPOSIT_DOI=""
if [[ -f zenodo/.deposit-state.json ]]; then
  DEPOSIT_DOI="$(python3 -c 'import json;print(json.load(open("zenodo/.deposit-state.json")).get("doi",""))' 2>/dev/null || true)"
fi

if [[ -n "$DEPOSIT_DOI" ]]; then
  for f in "$DEST/README.md" "$DEST/CITATION.cff"; do
    perl -pi -e "s{TODO-DEPOSIT-DOI}{$DEPOSIT_DOI}g" "$f"
  done
  perl -pi -e "s{^# DOI-LINE\$}{doi: \"$DEPOSIT_DOI\"\nurl: \"https://doi.org/$DEPOSIT_DOI\"}" "$DEST/CITATION.cff"
  echo "DOI stamped into README.md and CITATION.cff: $DEPOSIT_DOI"
elif [[ $ALLOW_PLACEHOLDER -eq 1 ]]; then
  echo "WARNING: no reserved DOI yet -- README.md and CITATION.cff keep TODO-DEPOSIT-DOI" >&2
  echo "         (allowed by --allow-placeholder; do NOT upload this tree)" >&2
else
  echo "refusing to build: no reserved DOI in zenodo/.deposit-state.json" >&2
  echo "  run tools/zenodo_deposit.py create first, or pass --allow-placeholder" >&2
  exit 1
fi

# --- checksums --------------------------------------------------------------
( cd "$DEST" && find . -type f ! -name SHA256SUMS.txt -print0 \
    | sort -z | xargs -0 shasum -a 256 > SHA256SUMS.txt )

# --- zip --------------------------------------------------------------------
ZIP="dist/$NAME.zip"
rm -f "$ZIP"
( cd dist && zip -qr "$NAME.zip" "$NAME" -x '*.DS_Store' )

# --- report -----------------------------------------------------------------
echo
echo "=== STAGED ==="
du -sh "$DEST"/* | sort -hr
echo
echo "files:  $(find "$DEST" -type f | wc -l | tr -d ' ')  (SHA256SUMS.txt included)"
echo "tree:   $DEST"
echo "zip:    $ZIP  ($(du -h "$ZIP" | cut -f1))"
