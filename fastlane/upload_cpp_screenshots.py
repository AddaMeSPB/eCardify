#!/usr/bin/env python3
"""
upload_cpp_screenshots.py — Upload screenshots to ASC Custom Product Pages

Usage:
    python3 fastlane/upload_cpp_screenshots.py \
        --key-id V32DT2Q432 \
        --issuer-id fb43cfba-4610-4273-ba22-5d1667d608c7 \
        --private-key-file ~/.appstoreconnect/AuthKey_V32DT2Q432.p8 \
        --config fastlane/cpp_pages.json \
        --screenshots-dir fastlane/screenshots

The script maps screenshot filenames to display types by pixel size:
    1290x2796 or 1284x2778  →  APP_IPHONE_67
    1179x2556 or 1170x2532  →  APP_IPHONE_65 (6.5")
    2064x2752 or 2048x2732  →  APP_IPAD_PRO_3GEN_129
"""

import argparse
import hashlib
import json
import os
import sys
import time
import urllib.request
import urllib.error
from pathlib import Path

try:
    import jwt
except ImportError:
    print("ERROR: PyJWT not installed. Run: pip3 install PyJWT cryptography")
    sys.exit(1)

# ── ASC display type detection ──────────────────────────────────────────────

SIZE_TO_TYPE = {
    (1320, 2868): "APP_IPHONE_67",  # iPhone 16 Pro Max
    (1290, 2796): "APP_IPHONE_67",  # iPhone 15 Pro Max
    (1284, 2778): "APP_IPHONE_67",  # iPhone 14 Plus / 13 Pro Max
    (1179, 2556): "APP_IPHONE_67",  # iPhone 14 Pro
    (1242, 2688): "APP_IPHONE_65",  # iPhone 11 Pro Max
    (1170, 2532): "APP_IPHONE_65",  # iPhone 12 / 13
    (2064, 2752): "APP_IPAD_PRO_3GEN_129",  # iPad Pro 12.9" gen 3+
    (2048, 2732): "APP_IPAD_PRO_3GEN_129",  # iPad Pro 12.9" gen 1-2
    (2048, 2732): "APP_IPAD_PRO_3GEN_129",
}

def image_size(path: Path):
    """Return (width, height) by reading PNG header bytes."""
    with open(path, "rb") as f:
        header = f.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n":
        return None, None
    import struct
    w, h = struct.unpack(">II", header[16:24])
    return w, h

def display_type_for(path: Path):
    w, h = image_size(path)
    t = SIZE_TO_TYPE.get((w, h)) or SIZE_TO_TYPE.get((h, w))
    return t

# ── JWT ─────────────────────────────────────────────────────────────────────

def make_token(key_id: str, issuer_id: str, private_key: str) -> str:
    now = int(time.time())
    payload = {"iss": issuer_id, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"}
    return jwt.encode(payload, private_key, algorithm="ES256",
                      headers={"kid": key_id, "typ": "JWT"})

# ── ASC API helpers ──────────────────────────────────────────────────────────

BASE = "https://api.appstoreconnect.apple.com/v1"

def asc(method: str, path: str, token: str, body=None, raw=False):
    url = BASE + path if path.startswith("/") else path
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as r:
            if raw:
                return r.status, b""
            return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e:
        body_text = e.read().decode(errors="replace")
        return e.code, {"error": body_text}

def upload_chunk(url: str, headers: list, data: bytes):
    req = urllib.request.Request(url, data=data, method="PUT")
    for h in headers:
        req.add_header(h["name"], h["value"])
    try:
        with urllib.request.urlopen(req) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code

# ── Core logic ───────────────────────────────────────────────────────────────

def get_or_create_localization(token: str, version_id: str, locale: str) -> str:
    # Correct endpoint: appCustomProductPageLocalizations (not appCustomProductPageVersionLocalizations)
    status, data = asc("GET", f"/appCustomProductPageVersions/{version_id}/appCustomProductPageLocalizations", token)
    if status == 200:
        for loc in data.get("data", []):
            if loc["attributes"]["locale"] == locale:
                print(f"    Found existing localization {locale}: {loc['id']}")
                return loc["id"]

    print(f"    Creating localization {locale}...")
    status, data = asc("POST", "/appCustomProductPageLocalizations", token, {
        "data": {
            "type": "appCustomProductPageLocalizations",
            "attributes": {"locale": locale},
            "relationships": {
                "appCustomProductPageVersion": {
                    "data": {"type": "appCustomProductPageVersions", "id": version_id}
                }
            }
        }
    })
    if status not in (200, 201):
        raise RuntimeError(f"Failed to create localization: {data}")
    loc_id = data["data"]["id"]
    print(f"    Created localization {locale}: {loc_id}")
    return loc_id

def get_or_create_screenshot_set(token: str, loc_id: str, display_type: str) -> str:
    status, data = asc("GET", f"/appCustomProductPageLocalizations/{loc_id}/appScreenshotSets", token)
    if status == 200:
        for ss in data.get("data", []):
            if ss["attributes"]["screenshotDisplayType"] == display_type:
                print(f"      Found existing set {display_type}: {ss['id']}")
                return ss["id"]

    print(f"      Creating screenshot set {display_type}...")
    status, data = asc("POST", "/appScreenshotSets", token, {
        "data": {
            "type": "appScreenshotSets",
            "attributes": {"screenshotDisplayType": display_type},
            "relationships": {
                "appCustomProductPageLocalization": {
                    "data": {"type": "appCustomProductPageLocalizations", "id": loc_id}
                }
            }
        }
    })
    if status not in (200, 201):
        raise RuntimeError(f"Failed to create screenshot set: {data}")
    set_id = data["data"]["id"]
    print(f"      Created screenshot set {display_type}: {set_id}")
    return set_id

def upload_screenshot(token: str, set_id: str, filepath: Path, order: int) -> bool:
    file_bytes = filepath.read_bytes()
    file_size = len(file_bytes)
    md5 = hashlib.md5(file_bytes).hexdigest()

    # Reserve slot
    status, data = asc("POST", "/appScreenshots", token, {
        "data": {
            "type": "appScreenshots",
            "attributes": {"fileName": filepath.name, "fileSize": file_size},
            "relationships": {
                "appScreenshotSet": {
                    "data": {"type": "appScreenshotSets", "id": set_id}
                }
            }
        }
    })
    if status not in (200, 201):
        print(f"        SKIP {filepath.name}: reserve failed {status} — {data}")
        return False

    screenshot_id = data["data"]["id"]
    ops = data["data"]["attributes"].get("uploadOperations", [])

    # Upload chunks
    for op in ops:
        offset = op.get("offset", 0)
        length = op.get("length", file_size)
        chunk = file_bytes[offset: offset + length]
        upload_status = upload_chunk(op["url"], op.get("requestHeaders", []), chunk)
        if upload_status not in (200, 201, 204):
            print(f"        SKIP {filepath.name}: upload chunk failed {upload_status}")
            return False

    # Commit
    status, data = asc("PATCH", f"/appScreenshots/{screenshot_id}", token, {
        "data": {
            "type": "appScreenshots",
            "id": screenshot_id,
            "attributes": {"uploaded": True, "sourceFileChecksum": md5}
        }
    })
    if status not in (200, 201):
        print(f"        SKIP {filepath.name}: commit failed {status} — {data}")
        return False

    print(f"        ✓ {filepath.name}")
    return True

def upload_for_cpp(token: str, cpp_id: str, cpp_name: str, screenshots_dir: Path, locale: str):
    print(f"\n  CPP: {cpp_name} ({cpp_id})")

    # Get CPP version
    status, data = asc("GET", f"/appCustomProductPages/{cpp_id}/appCustomProductPageVersions", token)
    if status != 200 or not data.get("data"):
        print(f"    ERROR: could not get CPP version — {status} {data}")
        return
    version_id = data["data"][0]["id"]
    print(f"    Version: {version_id}")

    # Collect screenshots, grouped by display type
    locale_dir = screenshots_dir / locale
    if not locale_dir.exists():
        locale_dir = screenshots_dir  # fallback: flat dir

    png_files = sorted(f for f in locale_dir.glob("*.png") if not f.name.startswith("."))
    if not png_files:
        print(f"    No PNG files found in {locale_dir}")
        return

    by_type: dict[str, list[Path]] = {}
    skipped = []
    for f in png_files:
        dt = display_type_for(f)
        if dt:
            by_type.setdefault(dt, []).append(f)
        else:
            skipped.append(f.name)

    if skipped:
        print(f"    Skipped (unknown size): {', '.join(skipped)}")

    # Get/create localization
    loc_id = get_or_create_localization(token, version_id, locale)

    # Upload per display type
    for display_type, files in by_type.items():
        print(f"    Type {display_type} — {len(files)} screenshots")
        set_id = get_or_create_screenshot_set(token, loc_id, display_type)
        for i, f in enumerate(files):
            upload_screenshot(token, set_id, f, i)

# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Upload screenshots to ASC Custom Product Pages")
    parser.add_argument("--key-id", required=True)
    parser.add_argument("--issuer-id", required=True)
    parser.add_argument("--private-key-file", help="Path to .p8 file")
    parser.add_argument("--private-key", help="Key contents (inline)")
    parser.add_argument("--config", required=True, help="Path to cpp_pages.json")
    parser.add_argument("--screenshots-dir", required=True, help="Base screenshots directory")
    parser.add_argument("--locale", default="en-US")
    parser.add_argument("--cpp-id", help="Upload to single CPP ID only")
    args = parser.parse_args()

    # Load private key
    if args.private_key_file:
        private_key = Path(args.private_key_file).read_text()
    elif args.private_key:
        private_key = args.private_key
    else:
        print("ERROR: provide --private-key-file or --private-key")
        sys.exit(1)

    token = make_token(args.key_id, args.issuer_id, private_key)
    config = json.loads(Path(args.config).read_text())
    screenshots_dir = Path(args.screenshots_dir)

    pages = config.get("pages", [])
    if args.cpp_id:
        pages = [p for p in pages if p["id"] == args.cpp_id]
        if not pages:
            print(f"ERROR: CPP ID {args.cpp_id} not found in config")
            sys.exit(1)

    print(f"Uploading screenshots to {len(pages)} CPP(s) — locale: {args.locale}")
    for page in pages:
        upload_for_cpp(token, page["id"], page["name"], screenshots_dir, args.locale)

    print("\nDone.")

if __name__ == "__main__":
    main()
