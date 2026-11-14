#!/usr/bin/env bash
# deposit_prepare.sh -- everything up to (but never including) publishing.
#
#   create (reserve DOI) -> rebuild the package with that DOI stamped
#   -> upload every file -> apply the metadata -> report status
#
# It is resumable: if the deposition already exists it continues from there,
# and `upload` skips files whose size already matches the remote ones.
#
# Usage, in the shell where the token is exported:
#   export ZENODO_TOKEN=...
#   tools/deposit_prepare.sh
#
# Then review the record in the browser and publish only when you mean it:
#   tools/zenodo_deposit.py publish --confirm-publish
#
# Sandbox rehearsal: same command, with
#   export ZENODO_BASE=https://sandbox.zenodo.org

set -euo pipefail
cd "$(dirname "$0")/.."

: "${ZENODO_TOKEN:?ZENODO_TOKEN is not set in this shell. Run: export ZENODO_TOKEN=...}"

echo "== 1/5 token and staging =="
if [[ -f zenodo/.deposit-state.json ]]; then
  echo "a deposition already exists; resuming instead of creating a second one"
else
  tools/zenodo_deposit.py check
  tools/zenodo_deposit.py create
fi

echo
echo "== 2/5 building the package with the reserved DOI stamped =="
tools/build_deposit.sh

echo
echo "== 3/5 uploading =="
tools/zenodo_deposit.py upload

echo
echo "== 4/5 metadata =="
tools/zenodo_deposit.py metadata

echo
echo "== 5/5 status =="
tools/zenodo_deposit.py status

cat <<'EOF'

--------------------------------------------------------------------------
The record is a DRAFT: nothing is public and the DOI is only reserved.

What to do now, in this order:

  1. open the record in the browser (status printed the URL above)
  2. check the file list: 144 files, ~482 MB
  3. check the authors, the ORCIDs and the licence
  4. preview the README, which Zenodo renders as the record description page

and only then:

  tools/zenodo_deposit.py publish --confirm-publish

Publishing mints the DOI permanently, makes the record public, and cannot be
undone from the API. If something looks wrong, fix it and re-run this script.
--------------------------------------------------------------------------
EOF
