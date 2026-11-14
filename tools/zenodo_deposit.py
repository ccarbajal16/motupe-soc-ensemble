#!/usr/bin/env python3
"""zenodo_deposit.py -- create, fill and (only when told) publish a Zenodo record.

Zenodo now runs InvenioRDM v14 behind a compatibility layer. The legacy
`prereserve_doi` flag is rejected on creation ("Unknown field"), so this script
creates the draft through /api/deposit/depositions and then reserves the DOI on
the modern endpoint, with a documented manual fallback in the browser. Standard
library only: no pip install.

Environment:
    ZENODO_TOKEN   personal access token (deposit:write and deposit:actions)
    ZENODO_BASE    base URL; defaults to https://zenodo.org
                   use https://sandbox.zenodo.org for a rehearsal

Typical run, in this order:

    export ZENODO_TOKEN=...            # do not paste the token into a shell history file
    tools/zenodo_deposit.py check                    # does the token work?
    tools/zenodo_deposit.py create                   # draft, then reserve the DOI
    tools/zenodo_deposit.py adopt --doi 10.5281/...   # only if the reservation
                                                     # had to be done in the browser
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


def api_soft(method: str, path: str, payload: dict | None = None,
             raw: bytes | None = None, content_type: str | None = None,
             ) -> tuple[bool, object]:
    """Same as api(), but returns (ok, data_or_error) instead of exiting."""
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
            return True, (json.loads(body) if body else {})
    except urllib.error.HTTPError as exc:
        return False, f"HTTP {exc.code}: {exc.read().decode(errors='replace')[:600]}"
    except urllib.error.URLError as exc:
        return False, f"network: {exc.reason}"


def api(method: str, path: str, payload: dict | None = None,
        raw: bytes | None = None, content_type: str | None = None) -> dict:
    ok, out = api_soft(method, path, payload, raw, content_type)
    if not ok:
        url = path if path.startswith("http") else f"{base_url()}/api{path}"
        die(f"{method} {url} -> {out}")
    return out  # type: ignore[return-value]


def doi_in(obj: object, depth: int = 0) -> str:
    """Find a reserved DOI in whatever shape the API returned."""
    if depth > 5 or obj is None:
        return ""
    if isinstance(obj, dict):
        for key in ("prereserve_doi", "pids"):
            got = doi_in(obj.get(key), depth + 1)
            if got:
                return got
        for key in ("doi", "identifier"):
            val = obj.get(key)
            if isinstance(val, str) and val.startswith("10."):
                return val
        for val in obj.values():
            got = doi_in(val, depth + 1)
            if got:
                return got
    elif isinstance(obj, list):
        for val in obj:
            got = doi_in(val, depth + 1)
            if got:
                return got
    return ""


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


def try_reserve_doi(dep_id: int) -> tuple[str, list[str]]:
    """Reserve a DOI for an existing draft. Returns (doi, attempts_log).

    Zenodo runs InvenioRDM v14 behind a compatibility layer, and the legacy
    `prereserve_doi` flag is rejected as an unknown field on creation, so the
    reservation is attempted on the modern endpoints in order of preference.
    """
    attempts = [
        ("POST", f"/records/{dep_id}/draft/pids/doi", {"provider": "datacite"}),
        ("POST", f"/records/{dep_id}/draft/pids/doi", None),
        ("POST", f"/records/{dep_id}/draft/pids", {"scheme": "doi"}),
        ("PUT", f"/deposit/depositions/{dep_id}", {"prereserve_doi": True}),
    ]
    log = []
    for method, path, payload in attempts:
        ok, out = api_soft(method, path, payload)
        label = f"{method} {path}" + ("" if payload is None else " +body")
        if ok:
            doi = doi_in(out)
            log.append(f"  ok    {label}" + (f" -> {doi}" if doi else " (no doi in reply)"))
            if doi:
                return doi, log
        else:
            log.append(f"  fail  {label} -> {out}")
    return "", log


def cmd_create(args) -> None:
    if STATE_FILE.exists() and not args.force:
        state = load_state()
        print(f"deposition already exists: id {state['id']}")
        if state.get("doi"):
            print(f"reserved DOI             : {state['doi']}")
        else:
            print("reserved DOI             : none yet "
                  "(see `adopt --doi`, or the browser)")
        print("use --force to create another one")
        return

    # metadata is applied later, from zenodo/metadata.json; here we only need a
    # draft that is open and a bucket to upload into
    payload = {"metadata": {"title": "Motupe SOC data and code (draft)",
                            "upload_type": "dataset",
                            "access_right": "open"}}
    dep = api("POST", "/deposit/depositions", payload)
    state = {
        "base": base_url(),
        "id": dep["id"],
        "doi": doi_in(dep.get("metadata")),
        "bucket": dep.get("links", {}).get("bucket", ""),
        "record_url": dep.get("links", {}).get("html", ""),
        "uploaded": {},
    }
    print(f"created deposition {state['id']} on {base_url()}")

    if not state["doi"]:
        print("reserving the DOI ...")
        state["doi"], log = try_reserve_doi(state["id"])
        for line in log:
            print(line)

    save_state(state)

    if state["doi"]:
        print(f"reserved DOI    : {state['doi']}")
        print(f"edit in browser : {state['record_url']}")
        print("\nThe reserved DOI already exists: you may cite it now, and it becomes "
              "permanent when the record is published.")
        print("\nnext: tools/build_deposit.sh   (stamps that DOI into the package)")
    else:
        print(f"edit in browser : {state['record_url']}")
        die("could not reserve a DOI through the API.\n"
            "Nothing is lost: the draft exists. Do it in the browser instead:\n"
            "  1. open the record URL above\n"
            "  2. click \"Get a DOI now!\" (or the DOI button) and copy the DOI\n"
            "  3. run: tools/zenodo_deposit.py adopt --doi <that DOI>\n"
            "  4. then: tools/build_deposit.sh && tools/zenodo_deposit.py upload")


def cmd_adopt(args) -> None:
    """Attach to an existing draft -- typically one created in the browser."""
    if args.id:
        dep = api("GET", f"/deposit/depositions/{args.id}")
    else:
        listing = api("GET", "/deposit/depositions?size=20&sort=mostrecent")
        drafts = [d for d in listing if not d.get("submitted")]
        if not drafts:
            die("no draft deposition visible for this token: create one in the "
                f"browser at {base_url()}/deposit/new, then re-run adopt")
        if len(drafts) > 1 and not args.doi:
            print("warning: several drafts found, taking the most recent; "
                  "pass --id to choose another")
        dep = drafts[0]

    doi = args.doi or doi_in(dep.get("metadata")) or doi_in(dep)
    state = {
        "base": base_url(),
        "id": dep["id"],
        "doi": doi,
        "bucket": dep.get("links", {}).get("bucket", ""),
        "record_url": dep.get("links", {}).get("html", ""),
        "uploaded": {},
    }
    save_state(state)
    print(f"adopted deposition {state['id']} on {base_url()}")
    print(f"reserved DOI       : {doi or '(none -- pass --doi)'}")
    print(f"upload bucket      : {state['bucket'] or '(none -- will use the files API)'}")
    print(f"browser            : {state['record_url']}")
    if not doi:
        die("a DOI is required before packaging: pass --doi 10.5281/zenodo.NNNNNNN")


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
    ok, out = api_soft("PUT", f"/deposit/depositions/{state['id']}", meta)
    if not ok:
        die(f"the API refused the metadata: {out}\n"
            "Nothing is lost: the draft and the files are already there.\n"
            f"Open {state.get('record_url', base_url())} and paste the fields from\n"
            "zenodo/metadata.json by hand (title, description, creators with ORCIDs,\n"
            "keywords, licence, related identifiers), then publish from the browser.")
    _ = out
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

    p = sub.add_parser("adopt", help="attach to an existing draft (e.g. one made in the browser)")
    p.add_argument("--id", type=int, help="deposition id")
    p.add_argument("--doi", help="the DOI reserved for that draft")
    p.set_defaults(func=cmd_adopt)

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
