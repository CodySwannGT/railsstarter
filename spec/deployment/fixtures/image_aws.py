#!/usr/bin/env python3
"""Authored upload fixture: validates actual image bytes, performs no AWS calls."""
import hashlib
import json
import os
import pathlib
import sys

args = sys.argv[1:]
if args[:2] != ["s3", "sync"]:
    sys.exit("Unexpected AWS operation")
source = pathlib.Path(args[2])
manifest = json.loads((source / ".manifest.json").read_text())
paths = [value["digested_path"] if isinstance(value, dict) else value for value in manifest.values()]
actual = {name: hashlib.sha256((source / name).read_bytes()).hexdigest() for name in paths}
expected = json.loads(pathlib.Path(os.environ["EXPECTED_ASSETS"]).read_text())
if actual != expected:
    sys.exit("Upload bytes differ from the independently extracted image")
if "--delete" in args or "--no-follow-symlinks" not in args:
    sys.exit("Unsafe upload flags")
if source.parent.stat().st_mode & 0o777 != 0o700:
    sys.exit("Upload scratch is not private")
with open(os.environ["CLI_LOG"], "a") as log:
    log.write(json.dumps({"tool": "aws-fixture", "args": args, "asset_count": len(actual)}) + "\n")
if os.environ.get("FAIL_UPLOAD") == "1":
    print("Deliberate upload failure", file=sys.stderr)
    sys.exit(42)
