#!/usr/bin/env python3
"""Verify fixture hashes, CLI semantics, metadata, statistics, usages, and errors.

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
import struct
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


def assert_pretty_semantics(compact: ET.Element, pretty: ET.Element) -> None:
    """Allow indentation only in positions absent from element-only input.

    Existing whitespace text and all mixed content remain exact, including tails
    that the independent JSON tree representation does not record.
    """
    assert compact.tag == pretty.tag, "pretty element name differs"
    assert normalize_record(compact.attrib) == normalize_record(pretty.attrib), "pretty attributes differ"
    assert len(compact) == len(pretty), "pretty child count differs"
    layout = bool(len(compact)) and not compact.text and not any(child.tail for child in compact)

    def same_text(expected: str | None, actual: str | None, allow_layout: bool) -> None:
        expected, actual = expected or "", actual or ""
        assert actual == expected or (allow_layout and not expected and not actual.strip()), "pretty text or tail differs"

    same_text(compact.text, pretty.text, layout)
    for compact_child, pretty_child in zip(compact, pretty):
        assert_pretty_semantics(compact_child, pretty_child)
        same_text(compact_child.tail, pretty_child.tail, layout)


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


def menu_reference_records(data: bytes) -> list[dict]:
    """Scan typed attributes of the pinned owned menu fixture independently.

    Name indices and IDs come from the committed aapt2/reference menu, not CLI
    output. Locations come from its binary node and attribute headers. This is
    deliberately a fixture oracle, not another general-purpose AXML decoder.
    """
    names = {0: "icon", 2: "id", 5: "title"}
    kinds = {1: "Resource", 2: "ThemeAttribute", 7: "DynamicResource", 8: "DynamicThemeAttribute"}
    records = []
    offset = 8
    while offset < len(data):
        kind, header_size, chunk_size = struct.unpack_from("<HHI", data, offset)
        assert chunk_size >= header_size >= 8, "invalid oracle chunk header"
        if kind == 0x0102:
            extension = offset + header_size
            attribute_start, attribute_size, count = struct.unpack_from("<HHH", data, extension + 8)
            line = struct.unpack_from("<I", data, offset + 8)[0]
            for index in range(count):
                attribute = extension + attribute_start + index * attribute_size
                namespace, name = struct.unpack_from("<II", data, attribute)
                value_size, reserved, value_type, value = struct.unpack_from("<HBBI", data, attribute + 12)
                assert value_size == 8 and reserved == 0, "invalid oracle typed value"
                if value_type in kinds:
                    assert namespace == 8 and name in names, "unexpected menu reference origin"
                    records.append({"offset": offset, "line_number": line,
                                    "origin": ["Attribute", [ANDROID_URI], names[name]],
                                    "reference": [kinds[value_type], value]})
        offset += chunk_size
    assert offset == len(data), "oracle chunk does not end at document boundary"
    assert [record["reference"] for record in records] == [
        ["Resource", 0x01080033], ["Resource", 0x7f010000],
        ["Resource", 0x7f010001], ["Resource", 0x7f030000],
    ], "menu reference IDs differ from independent aapt2 expectations"
    return records


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

    version = re.search(r'^version\s*=\s*"([^"]+)"', (ROOT / "moon.mod").read_text(encoding="utf-8"), re.MULTILINE)
    assert version, "missing module version"
    version_output = run("--version")
    assert version_output.returncode == 0 and version_output.stdout.decode("utf-8").strip() == f"axml {version[1]}", "CLI and package versions differ"
    for arguments in [("--help",), ("decode", "--help"), ("inspect", "-h"), ("stats", "--help"), ("stats", "-h"), ("refs", "--help"), ("refs", "-h"), ("validate", "--help")]:
        help_output = run(*arguments)
        assert help_output.returncode == 0 and b"Usage: axml" in help_output.stdout, f"help failed: {arguments}"
    literal_path = run("validate", "--", str(FIXTURES / "valid" / "menu.axml"))
    assert literal_path.returncode == 0 and literal_path.stdout.strip() == b"valid", "literal filename terminator failed"
    pretty_literal = run("decode", "--pretty", "--", str(FIXTURES / "valid" / "menu.axml"))
    assert pretty_literal.returncode == 0 and b"\n  <item" in pretty_literal.stdout, "pretty literal filename terminator failed"
    for arguments in [
        ("decode", "--pretty"), ("decode", "--pretty", "--"),
        ("decode", "--pretty", "--help"), ("decode", "--unknown", "input.axml"),
        ("decode", "input.axml", "--pretty"), ("decode", "--pretty", "input.axml", "extra.axml"),
    ]:
        invalid = run(*arguments)
        assert invalid.returncode == 2 and not invalid.stdout, f"pretty usage did not fail cleanly: {arguments}"

    for fixture in manifest["fixtures"]:
        path = ROOT / fixture["path"]
        data = path.read_bytes()
        assert len(data) == fixture["bytes"], f"size mismatch: {path}"
        assert hashlib.sha256(data).hexdigest() == fixture["sha256"], f"hash mismatch: {path}"
        if fixture["valid"]:
            decoded = run("decode", str(path))
            assert decoded.returncode == 0, f"decode {path.name}: {decoded.stderr.decode('utf-8')}"
            compact_tree = ET.fromstring(decoded.stdout)
            actual = normalize_tree(element_tree(compact_tree))
            expected = normalize_tree(json.loads((FIXTURES / "reference" / f"{path.stem}.tree.json").read_text(encoding="utf-8")))
            assert actual == expected, f"semantic tree mismatch: {path.name}\nactual={actual}\nexpected={expected}"
            pretty = run("decode", "--pretty", str(path))
            assert pretty.returncode == 0, f"pretty decode {path.name}: {pretty.stderr.decode('utf-8')}"
            try:
                assert_pretty_semantics(compact_tree, ET.fromstring(pretty.stdout))
            except AssertionError as error:
                raise AssertionError(f"pretty semantic tree mismatch: {path.name}: {error}") from error
            if path.stem == "menu":
                assert b"\n  <item" in pretty.stdout and b"\n</menu>" in pretty.stdout, "pretty output contains no child indentation"
            validated = run("validate", str(path))
            assert validated.returncode == 0, f"validate {path.name}: {validated.stderr.decode('utf-8')}"
            if path.stem == "menu":
                # Independently counted owned aapt2 fixture: one menu, two items,
                # four attributes each, one Android namespace, eleven pool strings.
                expected_stats = {
                    "strings": 11, "string_utf16_units": "108", "resource_ids": 6,
                    "events": 8, "start_elements": 3, "attributes": "8",
                    "text_events": 0, "namespace_declarations": 1, "max_depth": 2,
                }
                for arguments in [("stats", str(path)), ("stats", "--json", "--", str(path))]:
                    statistics = run(*arguments)
                    assert statistics.returncode == 0, f"stats {path.name}: {statistics.stderr.decode('utf-8')}"
                    assert json.loads(statistics.stdout) == expected_stats, f"statistics mismatch: {path.name}"
                expected_references = menu_reference_records(data)
                for arguments in [("refs", str(path)), ("refs", "--json", "--", str(path))]:
                    references = run(*arguments)
                    assert references.returncode == 0, f"refs {path.name}: {references.stderr.decode('utf-8')}"
                    assert json.loads(references.stdout) == expected_references, f"reference usage mismatch: {path.name}"
            if path.stem == "synthetic_utf8":
                references = run("refs", "--json", str(path))
                assert references.returncode == 0 and json.loads(references.stdout) == [], "ordinary strings must not create typed usages"
            if path.stem.startswith("manifest_"):
                inspected = run("inspect", "--json", str(path))
                assert inspected.returncode == 0, f"inspect {path.name}: {inspected.stderr.decode('utf-8')}"
                record = inspected_record(json.loads(inspected.stdout))
                expected_record = manifest_record(expected)
                assert normalize_record(record) == normalize_record(expected_record), f"metadata mismatch: {path.name}\nactual={record}\nexpected={expected_record}"
        else:
            for command in [("decode",), ("decode", "--pretty"), ("validate",), ("stats",), ("refs",)]:
                result = run(*command, str(path))
                assert result.returncode == 1, f"{command} did not report a data error for malformed fixture: {path.name}"
                assert not result.stdout, f"{command} wrote partial output for malformed fixture: {path.name}"
                diagnostic = result.stderr.decode("utf-8")
                assert re.search(r"(?:offset|byte|Invalid\()[^\n]*[0-9]", diagnostic, re.IGNORECASE), f"missing offset diagnostic: {path.name}: {diagnostic}"
                assert "panic" not in diagnostic.lower(), f"unhandled panic: {path.name}: {diagnostic}"
        checked += 1
    print(f"PASS: {checked} fixture hashes; 7 compact and pretty XML semantic trees; 3 manifest records; menu statistics; typed resource usages; 12 malformed fixtures; CLI help/version/pretty-usage/terminator checks.")


if __name__ == "__main__":
    main()
