#!/usr/bin/env python3
"""zenodo_deposit.py -- create, fill and (only when told) publish a Zenodo record.

Uses Zenodo's documented legacy deposit API, which returns a reserved DOI as
soon as the draft is created. Standard library only: no pip install.

Environment:
    ZENODO_TOKEN   personal access token (deposit:write and deposit:actions)
    ZENODO_BASE    base URL; defaults to https://zenodo.org
                   use https://sandbox.zenodo.org for a rehearsal

Typical run, in this order:

    export ZENODO_TOKEN=...            # do not paste the token into a shell history file
    tools/zenodo_deposit.py check                    # does the token work?
    tools/zenodo_deposit.py create                   # draft + reserved DOI
    tools/zenodo_deposit.py upload                   # every file in the staged tree
    tools/zenodo_deposit.py metadata                 # title, authors, licences, relations
    tools/zenodo_deposit.py status                   # DOI, file count, readiness

and only after reviewing the record in the browser:

    tools/zenodo_deposit.py publish --confirm-publish

Publishing is irreversible: it mints the DOI, makes the record public, and can
only be undone by Zenodo support. `publish` without `--confirm-publish` refuses.

State (deposition id, bucket, reserved DOI) is kept in zenodo/.deposit-state.json
so each command can run in a separate invocation.
"""

from __future__ import annotations

import argparse
import json
import mimetypes
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STATE_FILE = ROOT / "zenodo" / ".deposit-state.json"
METADATA_FILE = ROOT / "zenodo" / "metadata.json"
TREE = ROOT / "dist" / "motupe-soc-ensemble-v1.0.0"


# --------------------------------------------------------------------------- #
# plumbing
# --------------------------------------------------------------------------- #

def base_url() -> str:
    return os.environ.get("ZENODO_BASE", "https://zenodo.org").rstrip("/")


def token() -> str:
    t = os.environ.get("ZENODO_TOKEN", "").strip()
    if not t:
        die("ZENODO_TOKEN is not set. Create a token at "
            f"{base_url()}/account/settings/applications/ with deposit:write and "
            "deposit:actions, then: export ZENODO_TOKEN=...")
    return t


def die(msg: str) -> None:
    print(f"error: {msg}", file=sys.stderr)
    raise SystemExit(1)


def api(method: str, path: str, payload: dict | None = None,
        raw: bytes | None = None, content_type: str | None = None) -> dict:
    url = path if path.startswith("http") else f"{base_url()}/api{path}"
    data = raw if raw is not None else (
        json.dumps(payload).encode() if payload is not None else None)
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {token()}")
    req.add_header("Accept", "application/json")
    if data is not None:
        req.add_header("Content-Type", content_type or "application/json")
    try:
        with urllib.request.urlopen(req, timeout=600) as resp:
            body = resp.read()
            return json.loads(body) if body else {}
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode(errors="replace")[:2000]
        die(f"{method} {url} -> HTTP {exc.code}\n{detail}")
    except urllib.error.URLError as exc:
        die(f"{method} {url} -> {exc.reason}")
    return {}


def load_state() -> dict:
    if not STATE_FILE.exists():
        die("no deposition yet: run `tools/zenodo_deposit.py create` first")
    return json.loads(STATE_FILE.read_text())


def save_state(state: dict) -> None:
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, indent=2) + "\n")
    os.chmod(STATE_FILE, 0o600)


def metadata_payload() -> dict:
    if not METADATA_FILE.exists():
        die(f"missing {METADATA_FILE.relative_to(ROOT)}")
    meta = json.loads(METADATA_FILE.read_text())

    # fail closed on unedited placeholders: an ORCID of "TODO-ORCID-1" or a
    # "TODO-OWNER" repository URL would be published verbatim.
    blob = json.dumps(meta)
    stuck = sorted({tok for tok in ("TODO-ORCID", "TODO-OWNER", "TODO-REPO")
                    if tok in blob})
    if stuck:
        die("zenodo/metadata.json still contains placeholders: "
            + ", ".join(stuck)
            + "\nfill in the ORCIDs and the repository URL before uploading metadata")
    return meta


def human(nbytes: int) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if nbytes < 1024 or unit == "GB":
            return f"{nbytes:.0f} {unit}" if unit == "B" else f"{nbytes:.1f} {unit}"
        nbytes /= 1024
    return f"{nbytes:.1f} GB"


# --------------------------------------------------------------------------- #
# commands
# --------------------------------------------------------------------------- #

def cmd_check(_args) -> None:
    who = api("GET", "/deposit/depositions?size=1")
    print(f"base URL : {base_url()}")
    print(f"token    : accepted ({len(who)} existing deposit(s) visible on this page)")
    print(f"staged   : {TREE.relative_to(ROOT)}"
          f"{'' if TREE.exists() else '  <-- MISSING: run tools/build_deposit.sh'}")


def cmd_create(args) -> None:
    if STATE_FILE.exists() and not args.force:
        state = load_state()
        print(f"deposition already exists: id {state['id']}")
        print(f"reserved DOI             : {state['doi']}")
        print("use --force to create another one")
        return

    payload = {"metadata": {"title": "Motupe SOC data and code (draft)",
                            "upload_type": "dataset",
                            "access_right": "open"},
               "prereserve_doi": True}
    dep = api("POST", "/deposit/depositions", payload)
    state = {
        "base": base_url(),
        "id": dep["id"],
        "doi": dep["metadata"]["prereserve_doi"]["doi"],
        "bucket": dep["links"]["bucket"],
        "record_url": dep["links"].get("html", ""),
        "uploaded": {},
    }
    save_state(state)
    print(f"created deposition {state['id']} on {base_url()}")
    print(f"reserved DOI       : {state['doi']}")
    print(f"edit in browser    : {state['record_url']}")
    print("\nThe reserved DOI already exists: you may cite it now, and it becomes "
          "permanent when the record is published.")


def cmd_upload(args) -> None:
    state = load_state()
    if not TREE.exists():
        die(f"missing {TREE.relative_to(ROOT)}: run tools/build_deposit.sh")
    files = sorted(p for p in TREE.rglob("*") if p.is_file())
    total = sum(p.stat().st_size for p in files)
    print(f"{len(files)} files, {human(total)}, into deposition {state['id']}\n")

    uploaded = state.get("uploaded", {})
    for i, path in enumerate(files, 1):
        rel = path.relative_to(TREE).as_posix()
        size = path.stat().st_size
        if uploaded.get(rel) == size:
            print(f"[{i:>3}/{len(files)}] skip  {rel}  (already there, {human(size)})")
            continue
        if args.dry_run:
            print(f"[{i:>3}/{len(files)}] would upload {rel}  ({human(size)})")
            continue
        ctype = mimetypes.guess_type(rel)[0] or "application/octet-stream"
        api("PUT", f"{state['bucket']}/{rel}", raw=path.read_bytes(),
            content_type=ctype)
        uploaded[rel] = size
        state["uploaded"] = uploaded
        save_state(state)
        print(f"[{i:>3}/{len(files)}] sent  {rel}  ({human(size)})")

    print(f"\n{'would send' if args.dry_run else 'sent'} {len(files)} files")
    if args.dry_run:
        print("(dry run: nothing was uploaded)")


def cmd_metadata(_args) -> None:
    state = load_state()
    meta = metadata_payload()
    api("PUT", f"/deposit/depositions/{state['id']}", meta)
    doi = meta["metadata"].get("doi") or state["doi"]
    print(f"metadata set on deposition {state['id']}")
    print(f"DOI: {doi}")
    print("\nNow open the record in the browser, check the file list and the "
          "preview, and only then publish:\n"
          f"  tools/zenodo_deposit.py publish --confirm-publish")


def cmd_status(_args) -> None:
    state = load_state()
    dep = api("GET", f"/deposit/depositions/{state['id']}")
    files = dep.get("files", [])
    size = sum(f.get("filesize", 0) for f in files)
    print(f"deposition : {dep['id']}  ({dep.get('state', '?')})")
    print(f"title      : {dep['metadata'].get('title', '(none)')}")
    print(f"DOI        : {dep['metadata'].get('doi') or state['doi']}")
    print(f"files      : {len(files)}, {human(size)}")
    print(f"submitted  : {dep.get('submitted', False)}")
    print(f"browser    : {dep['links'].get('html', '')}")
    missing = [p.relative_to(TREE).as_posix() for p in TREE.rglob('*')
               if p.is_file()] if TREE.exists() else []
    sent = {f.get("filename") for f in files}
    pending = [m for m in missing if m not in sent and f"motupe-soc-ensemble-v1.0.0/{m}" not in sent]
    if pending:
        print(f"\nnot uploaded yet: {len(pending)} file(s), e.g. {pending[0]}")


def cmd_publish(args) -> None:
    state = load_state()
    if not args.confirm_publish:
        die("refusing to publish: publishing mints the DOI and is irreversible.\n"
            "Review the record in the browser, then re-run with "
            "`publish --confirm-publish`.")
    dep = api("GET", f"/deposit/depositions/{state['id']}")
    print(f"about to publish deposition {dep['id']}")
    print(f"  title : {dep['metadata'].get('title')}")
    print(f"  files : {len(dep.get('files', []))}")
    print(f"  DOI   : {dep['metadata'].get('doi') or state['doi']}")
    out = api("POST", f"/deposit/depositions/{state['id']}/actions/publish", {})
    print(f"\npublished. DOI: {out.get('doi') or state['doi']}")
    print(f"record: {out.get('links', {}).get('html', '')}")


# --------------------------------------------------------------------------- #

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)

    sub.add_parser("check", help="verify the token and the staged tree").set_defaults(func=cmd_check)

    p = sub.add_parser("create", help="create the draft and reserve a DOI")
    p.add_argument("--force", action="store_true", help="create a second deposition")
    p.set_defaults(func=cmd_create)

    p = sub.add_parser("upload", help="upload every staged file")
    p.add_argument("--dry-run", action="store_true", help="list, do not send")
    p.set_defaults(func=cmd_upload)

    sub.add_parser("metadata", help="apply zenodo/metadata.json").set_defaults(func=cmd_metadata)
    sub.add_parser("status", help="show the current state of the record").set_defaults(func=cmd_status)

    p = sub.add_parser("publish", help="publish the record (irreversible)")
    p.add_argument("--confirm-publish", action="store_true")
    p.set_defaults(func=cmd_publish)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
