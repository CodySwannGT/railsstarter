#!/usr/bin/env python3
"""Observe the real Docker CLI; every Docker operation still executes."""
import json
import os
import subprocess
import sys

args = sys.argv[1:]
docker = os.environ["VERIFY_REAL_DOCKER"]
record = {"tool": "real-docker", "args": args}
if args and args[0] == "cp":
    name = args[1].split(":", 1)[0]
    record["container_state"] = subprocess.check_output(
        [docker, "inspect", "--format", "{{.State.Status}}", name], text=True).strip()
with open(os.environ["CLI_LOG"], "a") as log:
    log.write(json.dumps(record) + "\n")
sys.exit(subprocess.run([docker, *args]).returncode)
