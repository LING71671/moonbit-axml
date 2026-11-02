#!/usr/bin/env python3
"""Rebuild owned Android binary XML fixtures and independent reference output.

Requires Android SDK Build Tools 36.0.0, platform android-36, and
androguard==4.1.3. Build intermediates remain under ignored _build/fixtures.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "fixtures"
BUILD = ROOT / "_build" / "fixtures"
ANDROID_URI = "http://schemas.android.com/apk/res/android"
NO_INDEX = 0xFFFFFFFF


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")


def run(*args: object) -> str:
    completed = subprocess.run([str(arg) for arg in args], check=True, capture_output=True)
    return (completed.stdout or completed.stderr).decode("utf-8").replace("\r\n", "\n").replace("\r", "\n")


def canonical_tree(node: object) -> dict:
    # Both lxml and stdlib ElementTree expose this subset. Clark names preserve
    # expanded XML names, while namespace prefix choice and indentation do not.
    return {
        "tag": node.tag,
        "attributes": dict(sorted(node.attrib.items())),
        "text": node.text or "",
        "children": [canonical_tree(child) for child in node],
    }


def encode_length(length: int, utf8: bool) -> bytes:
    if utf8:
        if length > 0x7FFF:
            raise ValueError("UTF-8 fixture string exceeds two-byte length capacity")
        return bytes([length]) if length < 0x80 else bytes([0x80 | (length >> 8), length & 255])
    return struct.pack("<H", length) if length < 0x8000 else struct.pack("<HH", 0x8000 | (length >> 16), length & 0xFFFF)


def string_pool(strings: list[str], utf8: bool) -> bytes:
    entries = bytearray()
    offsets = []
    for value in strings:
        offsets.append(len(entries))
        units = len(value.encode("utf-16le")) // 2
        if utf8:
            encoded = value.encode("utf-8")
            entries += encode_length(units, True) + encode_length(len(encoded), True) + encoded + b"\0"
        else:
            entries += encode_length(units, False) + value.encode("utf-16le") + b"\0\0"
    entries += b"\0" * (-len(entries) % 4)
    start = 28 + 4 * len(strings)
    return struct.pack("<HHIIIIII", 1, 28, start + len(entries), len(strings), 0, 0x100 if utf8 else 0, start, 0) + struct.pack(f"<{len(offsets)}I", *offsets) + entries


def node(chunk_type: int, payload: bytes, line: int = 1) -> bytes:
    return struct.pack("<HHIII", chunk_type, 16, 16 + len(payload), line, NO_INDEX) + payload


def synthetic_document(utf8: bool, long_string: bool = False) -> bytes:
    # Independent AOSP-layout construction: no MoonBit parser or renderer is used.
    strings = ["p", "urn:fixture", "root", "label", "月亮 𠀀 & <xml> \"quote\"", "text & < > 𠀀", "child"]
    if long_string:
        strings[4] = "长" * 33000
    pool = string_pool(strings, utf8)
    namespace_start = node(0x100, struct.pack("<II", 0, 1))
    attribute = struct.pack("<IIIHBBI", 1, 3, 4, 8, 0, 3, 4)
    start = node(0x102, struct.pack("<IIHHHHHH", 1, 2, 20, 20, 1, 0, 0, 0) + attribute)
    child_start = node(0x102, struct.pack("<IIHHHHHH", NO_INDEX, 6, 20, 20, 0, 0, 0, 0))
    text = node(0x104, struct.pack("<IHBBI", 5, 8, 0, 3, 5))
    child_end = node(0x103, struct.pack("<II", NO_INDEX, 6))
    end = node(0x103, struct.pack("<II", 1, 2))
    namespace_end = node(0x101, struct.pack("<II", 0, 1))
    chunks = pool + namespace_start + start + child_start + text + child_end + end + namespace_end
    return struct.pack("<HHI", 3, 8, 8 + len(chunks)) + chunks


def chunks(data: bytes) -> list[tuple[int, int]]:
    offset = 8
    result = []
    while offset < len(data):
        kind, _, size = struct.unpack_from("<HHI", data, offset)
        result.append((kind, offset))
        offset += size
    return result


def mutate(data: bytes, offset: int, fmt: str, value: int) -> bytes:
    result = bytearray(data)
    struct.pack_into(fmt, result, offset, value)
    return bytes(result)


def malformed_cases(base: bytes) -> list[tuple[str, bytes, str]]:
    positions = chunks(base)
    start = next(offset for kind, offset in positions if kind == 0x102)
    end = next(offset for kind, offset in positions if kind == 0x103)
    pool = 8
    string_start = pool + struct.unpack_from("<I", base, pool + 20)[0]
    first_string = string_start + struct.unpack_from("<I", base, pool + 28)[0]
    return [
        ("empty", b"", "truncated document header"),
        ("truncated_header", base[:7], "truncated document header"),
        ("truncated_body", base[:-1], "declared size exceeds available bytes"),
        ("zero_chunk_size", mutate(base, pool + 4, "<I", 0), "zero-length string-pool chunk"),
        ("chunk_outside_document", mutate(base, pool + 4, "<I", len(base) + 4), "chunk exceeds document boundary"),
        ("invalid_name_index", mutate(base, start + 20, "<I", 0x7FFFFFFF), "element name index outside string pool"),
        ("invalid_raw_index", mutate(base, start + 44, "<I", 0x7FFFFFFF), "attribute raw-value index outside string pool"),
        ("invalid_typed_index", mutate(base, start + 52, "<I", 0x7FFFFFFF), "typed string index outside string pool"),
        ("mismatched_end", mutate(base, end + 20, "<I", 2), "child end tag mismatches active element"),
        ("invalid_utf8", mutate(base, first_string + 2, "<B", 0xFF), "malformed UTF-8 string"),
        ("missing_terminator", mutate(base, first_string + 3, "<B", 0x7F), "missing UTF-8 string terminator"),
        ("bad_attribute_stride", mutate(base, start + 26, "<H", 4), "attribute record size is smaller than ResXMLTree_attribute"),
    ]


def embed_moonbit(valid: list[tuple[str, bytes]], invalid: list[tuple[str, bytes, str]]) -> None:
    def literal(data: bytes) -> str:
        return 'b"' + "".join(f"\\x{byte:02x}" for byte in data) + '"'

    lines = ["// Generated by scripts/generate_fixtures.py; edit the sources or generator.", ""]
    for name, data in valid:
        if "long" in name:
            continue
        event_count = sum(kind not in (1, 0x180) for kind, _ in chunks(data))
        lines += [f'test "fixture {name}: independently decoded event stream" {{', f"  let document = @axml.decode({literal(data)})", f"  assert_eq(document.events.length(), {event_count})", "  let xml = @axml.to_xml(document)", "  assert_true(xml.length() > 0)"]
        if name.startswith("manifest_"):
            suffix = name.removeprefix("manifest_")
            lines += ["  let manifest = @axml.inspect_manifest(document)", f'  assert_eq(manifest.package_name, "org.example.axml.{suffix}")', f"  assert_eq(manifest.permissions.length(), {2 if suffix == 'basic' else 1})", f"  assert_eq(manifest.components.length(), {4 if suffix == 'basic' else 1})"]
        lines += ["}", ""]
    for name, data, _ in invalid:
        lines += [f'test "malformed fixture {name}: checked error" {{', f"  let rejected = try {{", f"    let _ = @axml.decode({literal(data)})", "    false", "  } catch {", "    @axml.DecodeError::Invalid(offset, _) => offset >= 0", "  }", "  assert_true(rejected)", "}", ""]
    (ROOT / "src" / "fixtures_test.mbt").write_text("\n".join(lines), encoding="utf-8", newline="\n")
    run("moonfmt", "-w", ROOT / "src" / "fixtures_test.mbt")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdk", type=Path, default=os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT"))
    args = parser.parse_args()
    if args.sdk is None:
        parser.error("set ANDROID_HOME or pass --sdk")
    aapt2 = args.sdk / "build-tools" / "36.0.0" / ("aapt2.exe" if os.name == "nt" else "aapt2")
    android_jar = args.sdk / "platforms" / "android-36" / "android.jar"
    version = run(aapt2, "version").strip()
    if version != "Android Asset Packaging Tool (aapt) 2.20-13193326":
        raise RuntimeError(f"unreviewed aapt2 version: {version}")
    if importlib.metadata.version("androguard") != "4.1.3":
        raise RuntimeError("reference generation requires androguard==4.1.3")
    from androguard.core.axml import AXMLPrinter
    from loguru import logger

    logger.remove()
    BUILD.mkdir(parents=True, exist_ok=True)
    for directory in ["valid", "invalid", "reference"]:
        (FIXTURES / directory).mkdir(parents=True, exist_ok=True)
    records = []
    valid = []

    def add(name: str, data: bytes, origin: str, source: list[str], apk: Path | None = None, member: str = "AndroidManifest.xml") -> None:
        path = FIXTURES / "valid" / f"{name}.axml"
        path.write_bytes(data)
        axml = AXMLPrinter(data)
        if not axml.is_valid():
            raise RuntimeError(f"androguard rejects generated fixture {name}")
        xml = axml.get_xml()
        (FIXTURES / "reference" / f"{name}.xml").write_bytes(xml)
        write_json(FIXTURES / "reference" / f"{name}.tree.json", canonical_tree(axml.get_xml_obj()))
        if apk is not None:
            dump = run(aapt2, "dump", "xmltree", apk, "--file", member)
            (FIXTURES / "reference" / f"{name}.aapt2.txt").write_text(dump, encoding="utf-8", newline="\n")
            if member == "AndroidManifest.xml":
                (FIXTURES / "reference" / f"{name}.badging.txt").write_text(run(aapt2, "dump", "badging", apk), encoding="utf-8", newline="\n")
        records.append({"path": path.relative_to(ROOT).as_posix(), "sha256": sha256(data), "bytes": len(data), "origin": origin, "sources": source, "license": "Apache-2.0", "valid": True, "oracle": "androguard 4.1.3 AXMLPrinter" + ("; aapt2 xmltree and badging" if apk else "")})
        valid.append((name, data))

    for name in ["basic", "unicode", "references"]:
        source = FIXTURES / "sources" / name
        apk = BUILD / f"{name}.apk"
        command = [aapt2, "link", "-o", apk, "-I", android_jar, "--manifest", source / "AndroidManifest.xml"]
        resources = source / "res"
        if resources.exists():
            compiled = BUILD / f"{name}-resources.zip"
            run(aapt2, "compile", "--dir", resources, "-o", compiled)
            command.append(compiled)
        run(*command)
        with zipfile.ZipFile(apk) as archive:
            source_paths = [path.relative_to(ROOT).as_posix() for path in sorted(source.rglob("*.xml"))]
            add(f"manifest_{name}", archive.read("AndroidManifest.xml"), "aapt2 linked owned source", source_paths, apk)
            if name == "references":
                add("menu", archive.read("res/menu/main.xml"), "aapt2 compiled and linked owned source", source_paths, apk, "res/menu/main.xml")
    for utf8 in [True, False]:
        name = "synthetic_utf8" if utf8 else "synthetic_utf16"
        add(name, synthetic_document(utf8), "synthetic AOSP ResXMLTree layout", ["scripts/generate_fixtures.py"])
    add("synthetic_utf16_long", synthetic_document(False, True), "synthetic AOSP layout; two-word UTF-16 length", ["scripts/generate_fixtures.py"])
    invalid = malformed_cases(synthetic_document(True))
    for name, data, reason in invalid:
        path = FIXTURES / "invalid" / f"{name}.axml"
        path.write_bytes(data)
        records.append({"path": path.relative_to(ROOT).as_posix(), "sha256": sha256(data), "bytes": len(data), "origin": "single-field mutation of synthetic_utf8 (or truncation)", "sources": ["scripts/generate_fixtures.py"], "license": "Apache-2.0", "valid": False, "reason": reason})
    source_hashes = {path.relative_to(ROOT).as_posix(): sha256(path.read_bytes()) for path in sorted((FIXTURES / "sources").rglob("*.xml"))}
    reference_hashes = {path.relative_to(ROOT).as_posix(): sha256(path.read_bytes()) for path in sorted((FIXTURES / "reference").iterdir()) if path.is_file()}
    write_json(FIXTURES / "manifest.json", {"schema_version": 1, "license": "Apache-2.0", "reproduction": "python scripts/generate_fixtures.py --sdk <ANDROID_SDK_ROOT>", "tools": {"aapt2": {"version": version, "build_tools": "36.0.0", "host_platform": sys.platform, "executable_sha256": sha256(aapt2.read_bytes())}, "android_platform": {"version": "android-36", "android_jar_sha256": sha256(android_jar.read_bytes())}, "androguard": "4.1.3"}, "source_sha256": source_hashes, "reference_sha256": reference_hashes, "fixtures": records})
    embed_moonbit(valid, invalid)
    print(f"Generated {len(valid)} valid and {len(invalid)} malformed fixtures with independent references.")


if __name__ == "__main__":
    main()
