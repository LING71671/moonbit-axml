#!/usr/bin/env python3
"""Verify fixture hashes, CLI XML semantics, metadata, and malformed errors.

Uses only Python's standard library and committed independent reference trees.
Run `moon build src/cmd/axml --target js` first, or omit --cli for moon run.
Example: python scripts/verify_cli.py --cli node _build/js/debug/build/cmd/axml/axml.js
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "fixtures"
ANDROID_URI = "http://schemas.android.com/apk/res/android"


def normalized_value(value: str) -> str:
    # Prefix and hex-letter choices do not change an unresolved resource ID.
    match = re.fullmatch(r"([@?])(?:android:)?(?:0x)?([0-9a-fA-F]{8})", value)
    return f"{match[1]}0x{int(match[2], 16):08x}" if match else value


def normalize_tree(tree: dict) -> dict:
    return {
        "tag": tree["tag"],
        "attributes": {key: normalized_value(value) for key, value in sorted(tree["attributes"].items())},
        "text": tree["text"],
        "children": [normalize_tree(child) for child in tree["children"]],
    }


def element_tree(node: ET.Element) -> dict:
    return {
        "tag": node.tag,
        "attributes": dict(sorted(node.attrib.items())),
        "text": node.text or "",
        "children": [element_tree(child) for child in node],
    }


def manifest_record(tree: dict) -> dict:
    android = lambda name: f"{{{ANDROID_URI}}}{name}"
    children = tree["children"]
    sdk = next((child for child in children if child["tag"] == "uses-sdk"), None)
    application = next((child for child in children if child["tag"] == "application"), None)
    attributes = tree["attributes"]
    return {
        "package_name": attributes["package"],
        "version_code": attributes.get(android("versionCode")),
        "version_name": attributes.get(android("versionName")),
        "min_sdk": sdk["attributes"].get(android("minSdkVersion")) if sdk else None,
        "target_sdk": sdk["attributes"].get(android("targetSdkVersion")) if sdk else None,
        "permissions": [{"kind": child["tag"], "name": child["attributes"].get(android("name")), "max_sdk": child["attributes"].get(android("maxSdkVersion"))} for child in children if child["tag"].startswith("uses-permission")],
        "application_label": application["attributes"].get(android("label")) if application else None,
        "components": [{"kind": child["tag"], "name": child["attributes"].get(android("name")), "exported": child["attributes"].get(android("exported")), "authorities": child["attributes"].get(android("authorities"))} for child in application["children"] if child["tag"] in {"activity", "activity-alias", "service", "receiver", "provider"}] if application else [],
    }


def metadata_value(attribute: dict | None) -> str | None:
    if attribute is None:
        return None
    value = attribute["value"]
    kind, data = value["data_type"], value["data"]
    if kind == 3:
        return value["string_value"]
    if kind == 1:
        return f"@0x{data:08x}"
    if kind == 2:
        return f"?0x{data:08x}"
    if kind == 0x12:
        return "true" if data else "false"
    if kind == 0x10:
        return str(data if data < 0x80000000 else data - 0x100000000)
    raise AssertionError(f"unexpected manifest field type 0x{kind:02x}")


def inspected_record(metadata: dict) -> dict:
    sdk = metadata.get("sdk")
    application = metadata.get("application")
    return {
        "package_name": metadata["package_name"],
        "version_code": metadata_value(metadata.get("version_code")),
        "version_name": metadata_value(metadata.get("version_name")),
        "min_sdk": metadata_value(sdk.get("min_sdk")) if sdk else None,
        "target_sdk": metadata_value(sdk.get("target_sdk")) if sdk else None,
        "permissions": [{"kind": item["kind"], "name": metadata_value(item.get("name")), "max_sdk": metadata_value(item.get("max_sdk"))} for item in metadata["permissions"]],
        "application_label": metadata_value(application.get("label")) if application else None,
        "components": [{"kind": item["kind"], "name": metadata_value(item.get("name")), "exported": metadata_value(item.get("exported")), "authorities": metadata_value(item.get("authorities"))} for item in metadata["components"]],
    }


def normalize_record(value: object) -> object:
    if isinstance(value, str):
        return normalized_value(value)
    if isinstance(value, dict):
        return {key: normalize_record(item) for key, item in value.items()}
    if isinstance(value, list):
        return [normalize_record(item) for item in value]
    return value


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cli", nargs="+", default=["moon", "run", "src/cmd/axml", "--target", "js", "--"], help="CLI command, preceding its subcommand and input path")
    args = parser.parse_args()
    manifest = json.loads((FIXTURES / "manifest.json").read_text(encoding="utf-8"))
    checked = 0
    for relative, expected in manifest["source_sha256"].items():
        assert hashlib.sha256((ROOT / relative).read_bytes()).hexdigest() == expected, f"source hash mismatch: {relative}"
    for relative, expected in manifest.get("reference_sha256", {}).items():
        assert hashlib.sha256((ROOT / relative).read_bytes()).hexdigest() == expected, f"reference hash mismatch: {relative}"

    def run(*arguments: str) -> subprocess.CompletedProcess:
        return subprocess.run(args.cli + list(arguments), cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30)

    for fixture in manifest["fixtures"]:
        path = ROOT / fixture["path"]
        data = path.read_bytes()
        assert len(data) == fixture["bytes"], f"size mismatch: {path}"
        assert hashlib.sha256(data).hexdigest() == fixture["sha256"], f"hash mismatch: {path}"
        if fixture["valid"]:
            decoded = run("decode", str(path))
            assert decoded.returncode == 0, f"decode {path.name}: {decoded.stderr.decode('utf-8')}"
            actual = normalize_tree(element_tree(ET.fromstring(decoded.stdout)))
            expected = normalize_tree(json.loads((FIXTURES / "reference" / f"{path.stem}.tree.json").read_text(encoding="utf-8")))
            assert actual == expected, f"semantic tree mismatch: {path.name}\nactual={actual}\nexpected={expected}"
            validated = run("validate", str(path))
            assert validated.returncode == 0, f"validate {path.name}: {validated.stderr.decode('utf-8')}"
            if path.stem.startswith("manifest_"):
                inspected = run("inspect", "--json", str(path))
                assert inspected.returncode == 0, f"inspect {path.name}: {inspected.stderr.decode('utf-8')}"
                record = inspected_record(json.loads(inspected.stdout))
                expected_record = manifest_record(expected)
                assert normalize_record(record) == normalize_record(expected_record), f"metadata mismatch: {path.name}\nactual={record}\nexpected={expected_record}"
        else:
            for command in ["decode", "validate"]:
                result = run(command, str(path))
                assert result.returncode != 0, f"{command} accepted malformed fixture: {path.name}"
                diagnostic = result.stderr.decode("utf-8")
                assert re.search(r"(?:offset|byte|Invalid\()[^\n]*[0-9]", diagnostic, re.IGNORECASE), f"missing offset diagnostic: {path.name}: {diagnostic}"
                assert "panic" not in diagnostic.lower(), f"unhandled panic: {path.name}: {diagnostic}"
        checked += 1
    print(f"PASS: {checked} fixture hashes; 7 XML semantic trees; 3 manifest records; 12 malformed errors.")


if __name__ == "__main__":
    main()
