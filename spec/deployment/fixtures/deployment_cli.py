#!/usr/bin/env python3
"""Synthetic CLI protocol for asset/deployment failure tests, never real AWS."""
import json
import os
import pathlib
import signal
import subprocess
import sys

tool = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
record = {"tool": tool, "args": args}
if tool == "docker" and args[0] == "build":
    record["source_sha"] = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    if os.getenv("FIXTURE_ADVANCE_SOURCE"):
        source = pathlib.Path(os.environ["FIXTURE_SOURCE_ROOT"])
        if (source / "VERSION").read_text() == "1.0.0\n":
            (source / "VERSION").write_text("1.0.1\n")
            subprocess.run(["git", "-C", str(source), "-c", "user.name=Deployment fixture",
                            "-c", "user.email=fixture@example.invalid", "commit", "-qam", "Branch advanced"], check=True)
    context = pathlib.Path(args[-1])
    record["context_version"] = (context / "VERSION").read_text()
    record["context_private"] = (context / "private-input").exists()
    record["context_git"] = (context / ".git").exists()
if tool == "docker" and args[0] == "cp":
    record["scratch_mode"] = pathlib.Path(args[-1]).parent.stat().st_mode & 0o777
if tool == "aws" and args[:2] == ["ecs", "register-task-definition"]:
    filename = args[args.index("--cli-input-json") + 1].removeprefix("file://")
    record["task"] = json.loads(pathlib.Path(filename).read_text())
with open(os.environ["CLI_LOG"], "a") as log:
    log.write(json.dumps(record) + "\n")

if tool == "docker":
    if args[0] == "build" and os.getenv("FIXTURE_BUILD_FAIL"):
        sys.exit(43)
    elif args[0] == "build" and os.getenv("FIXTURE_BUILD_SIGNAL"):
        os.kill(os.getppid(), signal.SIGTERM)
    elif args[0] == "login" and "--password-stdin" in args:
        # Docker consumes the password pipe; exiting early creates a fake ECR failure.
        sys.stdin.buffer.read()
    elif "inspect" in args:
        if os.getenv("FIXTURE_INSPECT_FAIL"):
            sys.exit(1)
        if any("org.opencontainers.image.revision" in arg for arg in args):
            print(os.getenv("FIXTURE_REVISION", ""))
        elif any("RepoDigests" in arg for arg in args):
            if not os.getenv("FIXTURE_NO_DIGEST"):
                digest = os.environ["FIXTURE_DIGEST"]
                if "worker" in args[-1] or args[-1] == "sha256:" + "c" * 64:
                    digest = digest.replace("/web@", "/worker@")
                if os.getenv("FIXTURE_WRONG_REPOSITORY"):
                    digest = digest.replace("/web@", "/foreign@")
                if os.getenv("FIXTURE_MALFORMED_DIGEST"):
                    digest = digest.split("@", 1)[0] + "@sha256:invalid"
                print(digest)
                if os.getenv("FIXTURE_AMBIGUOUS_DIGEST"):
                    print(digest)
        elif "@" in args[-1] and os.getenv("FIXTURE_WRONG_DIGEST_IMAGE"):
            print("sha256:" + "d" * 64)
        else:
            print("sha256:" + "c" * 64 if "worker" in args[-1] else os.environ["FIXTURE_IMAGE_ID"])
    elif args[0] == "create":
        print("fixture-stopped-container")
    elif args[0] == "cp":
        if os.getenv("FIXTURE_COPY_FAIL"):
            sys.exit(43)
        destination = pathlib.Path(args[-1])
        destination.mkdir(parents=True, exist_ok=True)
        mode = os.getenv("FIXTURE_MANIFEST", "valid")
        if mode != "missing":
            # Propshaft 1.3 emits objects; this shape was observed in the real image.
            content = {"application.css": {"digested_path": "application-fingerprint.css", "integrity": None}}
            if mode == "legacy":
                content = {"application.css": "application-fingerprint.css"}
            if mode == "missing-path":
                content = {"application.css": {"integrity": None}}
            if mode == "traversal":
                content = {"application.css": {"digested_path": "../private.css"}}
            if mode == "empty":
                content = {}
            manifest = json.dumps(content) if mode != "invalid" else "invalid JSON"
            (destination / ".manifest.json").write_text(manifest)
        if mode != "missing-file":
            (destination / "application-fingerprint.css").write_text("body {color: green}")
        if mode == "symlink":
            (destination / "unmanifested-link").symlink_to(os.environ["CLI_LOG"])
    sys.exit(0)

if args[:2] == ["sts", "get-caller-identity"]:
    print("123")
elif args[:2] == ["cloudformation", "list-exports"]:
    exports = {
        "webClusterName": "fixture-cluster", "webEcrRepositoryName": "web",
        "workerEcrRepositoryName": "worker", "RailsServiceName": "web-service",
        "WorkerServiceName": "worker-service", "RailsTaskFamily": "web-task",
        "WorkerTaskFamily": "worker-task"
    }
    if not os.getenv("FIXTURE_NO_BUCKET"):
        exports["ClientUploadBucketFixture"] = "asset-bucket"
    print(json.dumps({"Exports": [{"Name": name, "Value": value} for name, value in exports.items()]}))
elif args[:2] == ["ecr", "get-login-password"]:
    print("synthetic-password")
elif args[:2] == ["s3", "sync"] and os.getenv("FIXTURE_UPLOAD_FAIL"):
    print("synthetic upload failure", file=sys.stderr)
    sys.exit(42)
elif args[:2] == ["s3", "sync"] and os.getenv("FIXTURE_UPLOAD_SIGNAL"):
    os.kill(os.getppid(), signal.SIGTERM)
elif args[:2] == ["ecs", "describe-task-definition"]:
    print(json.dumps({"containerDefinitions": [{"essential": True, "image": "old:tag"}]}))
elif args[:2] == ["ecs", "register-task-definition"]:
    print("arn:aws:ecs:fixture:task/1")
elif args[:2] == ["ecs", "run-task"]:
    print("arn:aws:ecs:fixture:migration/1")
elif args[:2] == ["ecs", "describe-tasks"]:
    print("0")
elif args[:2] == ["configure", "export-credentials"]:
    print(json.dumps({"AccessKeyId": "synthetic", "SecretAccessKey": "synthetic", "SessionToken": "synthetic"}))
