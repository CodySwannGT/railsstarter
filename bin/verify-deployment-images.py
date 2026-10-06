#!/usr/bin/env python3
"""Verify real image layers and real asset extraction without contacting AWS."""
import argparse
import hashlib
import json
import os
import pathlib
import shutil
import subprocess
import tarfile
import tempfile
import uuid


def run(*arguments, **options):
    return subprocess.run(arguments, check=True, **options)


def output(*arguments):
    return subprocess.check_output(arguments, text=True).strip()


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def contains(stream, needle):
    overlap = b""
    while chunk := stream.read(1024 * 1024):
        data = overlap + chunk
        if needle in data:
            return True
        overlap = data[-len(needle):]
    return False


def private_path(name):
    parts = pathlib.PurePosixPath(name.removeprefix("./")).parts
    return any(part == "aws_credentials" or part.startswith("aws_credentials.")
               or part in {".aws", ".entire", ".lisa"} for part in parts)


def inspect_layers(image, sentinel, report_path):
    inspection = json.loads(output("docker", "image", "inspect", image))[0]
    identity = inspection["Id"]
    findings, layers = [], []
    for entry in inspection["Config"].get("Env", []):
        if entry.split("=", 1)[0].startswith("AWS_"):
            findings.append({"type": "aws-environment", "name": entry.split("=", 1)[0]})
    with tempfile.TemporaryDirectory(prefix="image-layer-verification-") as scratch:
        archive = pathlib.Path(scratch) / "image.tar"
        run("docker", "image", "save", "--output", str(archive), identity)
        with tarfile.open(archive) as saved:
            manifest = json.load(saved.extractfile("manifest.json"))
            if len(manifest) != 1 or not manifest[0]["Layers"]:
                raise RuntimeError("Expected one image with inspectable layers")
            layer_names = manifest[0]["Layers"]
            for item in saved.getmembers():
                if item.isfile() and item.name not in layer_names:
                    if contains(saved.extractfile(item), sentinel):
                        findings.append({"type": "sentinel-metadata", "path": item.name})
            for name in layer_names:
                entries, inspected_bytes = 0, 0
                if contains(saved.extractfile(name), sentinel):
                    findings.append({"type": "sentinel-layer-bytes", "layer": name})
                with tarfile.open(fileobj=saved.extractfile(name), mode="r|*") as layer:
                    for item in layer:
                        entries += 1
                        metadata = json.dumps({"name": item.name, "linkname": item.linkname,
                                               "pax_headers": item.pax_headers}, ensure_ascii=False).encode()
                        if sentinel in metadata:
                            findings.append({"type": "sentinel-entry-metadata", "layer": name, "path": item.name})
                        if private_path(item.name):
                            findings.append({"type": "private-path", "layer": name, "path": item.name})
                        if item.isfile():
                            inspected_bytes += item.size
                            if contains(layer.extractfile(item), sentinel):
                                findings.append({"type": "sentinel-content", "layer": name, "path": item.name})
                layers.append({"layer": name, "entries": entries, "file_bytes_inspected": inspected_bytes,
                               "layer_archive_bytes_inspected": saved.getmember(name).size})
    report = {"image_id": identity, "architecture": inspection["Architecture"],
              "sentinel_sha256": hashlib.sha256(sentinel).hexdigest(),
              "layers": layers, "findings": findings}
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print(f"{image}: inspected {len(layers)} layers; {len(findings)} findings", flush=True)
    if findings:
        raise RuntimeError(f"Credential/private data found; see {report_path}")
    return identity


def verify_publication(root, image_id, reports):
    with tempfile.TemporaryDirectory(prefix="image-assets-verification-") as scratch:
        directory = pathlib.Path(scratch)
        reference = directory / "reference"
        reference.mkdir()
        container = "asset-reference-" + uuid.uuid4().hex
        try:
            run("docker", "create", "--name", container, image_id, stdout=subprocess.DEVNULL)
            state = output("docker", "inspect", "--format", "{{.State.Status}}", container)
            if state != "created":
                raise RuntimeError("Reference extraction container was started")
            run("docker", "cp", container + ":/rails/public/assets/.", str(reference))
            if any(path.is_symlink() for path in reference.rglob("*")):
                raise RuntimeError("Built asset directory contains symlinks")
            manifest = json.loads((reference / ".manifest.json").read_text())
            if not isinstance(manifest, dict) or not manifest:
                raise RuntimeError("Built image has no asset manifest")
            paths = [value["digested_path"] if isinstance(value, dict) else value
                     for value in manifest.values()]
            for name in paths:
                if not isinstance(name, str) or any(part in {"", ".", ".."} for part in name.split("/")):
                    raise RuntimeError("Unsafe asset path in built manifest")
                if not (reference / name).is_file() or (reference / name).stat().st_size == 0:
                    raise RuntimeError("Built manifest references a missing or empty asset")
            expected = {name: sha256(reference / name) for name in paths}
        finally:
            run("docker", "rm", "-f", container, stdout=subprocess.DEVNULL)

        expected_file = directory / "expected.json"
        expected_file.write_text(json.dumps(expected))
        aws = directory / "aws"
        shutil.copy2(root / "spec/deployment/fixtures/image_aws.py", aws)
        aws.chmod(0o700)
        real_docker = shutil.which("docker")
        docker = directory / "docker"
        shutil.copy2(root / "spec/deployment/fixtures/image_docker.py", docker)
        docker.chmod(0o700)
        environment = {key: value for key, value in os.environ.items() if not key.startswith("AWS_")}
        environment.update({"PATH": str(directory) + os.pathsep + os.environ["PATH"],
                            "TMPDIR": str(directory), "EXPECTED_ASSETS": str(expected_file),
                            "VERIFY_REAL_DOCKER": real_docker})
        cases = []
        for fail in (False, True):
            call_log = directory / "aws-calls.jsonl"
            call_log.write_text("")
            environment.update({"CLI_LOG": str(call_log), "FAIL_UPLOAD": "1" if fail else "0"})
            before = output("docker", "ps", "-a", "--filter", "name=rails-assets-", "--format", "{{.Names}}")
            result = subprocess.run(["bash", str(root / "bin/publish-assets"), "--image", image_id,
                                     "--bucket", "asset-fixture-bucket"],
                                    env=environment, capture_output=True, text=True)
            case = {"case": "upload-failure" if fail else "success", "exit_code": result.returncode,
                    "stdout": result.stdout, "stderr": result.stderr,
                    "calls": [json.loads(line) for line in call_log.read_text().splitlines()]}
            cases.append(case)
            (reports / "publication.json").write_text(json.dumps({"image_id": image_id,
                "helper_sha256": sha256(root / "bin/publish-assets"), "asset_sha256": expected,
                "cases": cases}, indent=2) + "\n")
            uploads = [call for call in case["calls"] if call["tool"] == "aws-fixture"]
            docker_calls = [call for call in case["calls"] if call["tool"] == "real-docker"]
            creates = [call for call in docker_calls if call["args"][0] == "create"]
            copy_states = [call["container_state"] for call in docker_calls if "container_state" in call]
            if result.returncode != (42 if fail else 0) or len(uploads) != 1:
                raise RuntimeError(f"Real image publication failed: {case}")
            if len(creates) != 1 or creates[0]["args"][-1] != image_id or copy_states != ["created"]:
                raise RuntimeError("Helper did not extract from a stopped container of the exact image")
            if any(call["args"][0] in {"start", "run"} for call in docker_calls):
                raise RuntimeError("Helper started the application during extraction")
            after = output("docker", "ps", "-a", "--filter", "name=rails-assets-", "--format", "{{.Names}}")
            if before != after or list(directory.glob("rails-assets.*")):
                raise RuntimeError("Publication leaked a container or scratch directory")
        print(f"Real publication: {len(expected)} matching assets; success=0, upload-failure=42; cleanup passed")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--web-image", required=True)
    parser.add_argument("--worker-image", required=True)
    parser.add_argument("--sentinel-file", type=pathlib.Path, required=True)
    parser.add_argument("--report-directory", type=pathlib.Path, required=True)
    args = parser.parse_args()
    sentinel = args.sentinel_file.read_bytes().strip()
    if len(sentinel) < 20:
        parser.error("Use a unique synthetic sentinel of at least 20 bytes")
    args.report_directory.mkdir(parents=True, exist_ok=True)
    web_id = inspect_layers(args.web_image, sentinel, args.report_directory / "web-layers.json")
    inspect_layers(args.worker_image, sentinel, args.report_directory / "worker-layers.json")
    verify_publication(pathlib.Path(__file__).resolve().parent.parent, web_id, args.report_directory)


if __name__ == "__main__":
    main()
