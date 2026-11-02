# MoonBit AXML

[中文](README_zh.md) | [Acceptance](docs/ACCEPTANCE.md) | [Fixtures](fixtures/README.md) | [Account isolation](docs/ACCOUNTS.md)

A pure MoonBit decoder for Android binary XML: checked byte parsing, typed events,
XML reconstruction, and manifest metadata. The offline CLI reads extracted AXML
files. The package namespace is **LING71671/axml**.

**Status: initial implementation, locally verified; not published to Mooncakes.**
Research and the bounded duplicate search are recorded in [docs/RESEARCH.md](docs/RESEARCH.md).

## Run the CLI

Use MoonBit **0.10.18+6c83a7f62** (moon **0.1.20261028**). The JavaScript CLI
requires Node.js **22+**; the native CLI requires a supported native compiler.
Run from this checkout:

```sh
moon run src/cmd/axml --target js -- decode fixtures/valid/manifest_unicode.axml
moon run src/cmd/axml --target js -- inspect --json fixtures/valid/manifest_basic.axml
moon run src/cmd/axml --target js -- validate fixtures/valid/menu.axml
```

The native equivalent uses `src/cmd/axml-native --target native`:

```sh
moon run src/cmd/axml-native --target native -- inspect --json fixtures/valid/manifest_basic.axml
```

For an APK, first extract its `AndroidManifest.xml` ZIP entry. Input is read
locally with a 16 MiB limit. `decode` writes namespace-aware XML, `inspect` writes
JSON, and `validate` checks binary structure and XML renderability. Exit codes are
0 for success, 1 for input/I/O errors, and 2 for invalid arguments. Diagnostics
include byte offsets. CLI errors go to stderr.

## Library API

The checked-in library is imported as `LING71671/axml` (alias `@axml`):

```moonbit
let document = @axml.decode(input)
let xml = @axml.to_xml(document)
let manifest = @axml.inspect_manifest(document)
```

These operations raise `DecodeError::Invalid(offset, message)`. `Document` exposes
string/resource pools and ordered namespace, element, and text events with input
offsets and line numbers. Each attribute retains its namespace URI, name, optional
resource ID, optional raw string, and `TypedValue` containing the Android type
code, original 32-bit payload, and decoded string when applicable.

Manifest inspection exposes package, version/versionCodeMajor, declared SDKs,
permissions, application attributes, and activity/alias/service/receiver/provider
records. Optional JSON fields are omitted when absent. Resource references remain
numeric IDs; component names and Android defaults are not inferred.

## Build and verify

```sh
moon fmt --check
moon check --target all --deny-warn
moon test --target wasm-gc --deny-warn
moon test --target js --deny-warn
moon test --target native --deny-warn
python scripts/verify_cli.py
```

The verifier uses Python's standard library. Regenerating fixtures additionally
requires pinned aapt2 and androguard; see [fixture instructions](fixtures/README.md).
Verification covers **46 tests** on wasm-gc, JavaScript, Windows native, and Linux
native (Debian under WSL2), plus **19 fixtures**, **7 independent XML trees**,
**3 manifest records**, and **12 malformed-input cases** through Node and native
CLIs. Reference outputs come from aapt2/androguard, independently of this parser.
The checked-in GitHub Actions workflow runs the same checks on Linux and Windows;
remote CI status is tracked separately from these local results.

## Bounds and supported scope

| Limit | Default |
| --- | --- |
| Input | 16 MiB |
| String pool | 100,000 entries; 4,194,304 aggregate UTF-16 units |
| Nesting | 256 elements |
| Events / attributes | 500,000 events; 65,535 attributes per element |
| Rendered output | 33,554,432 UTF-16 units |

`decode(input, limits=...)` and `to_xml(document, max_output_chars=...)` allow
explicit budgets. UTF-8/UTF-16 strings, resource maps, namespace scopes, typed
attributes, and CDATA are supported. Style spans are validated but their styling
is discarded in XML output. Unknown chunks and malformed encodings/scopes are
rejected. Resource-table resolution, AXML writing, APK signing, DEX decoding,
repair of obfuscated manifests, and APK archive I/O are outside this version.
The core has no Android/JVM dependency; CLI host adapters provide only file I/O.

## Ownership and license

The GitHub development repository is [LING71671/moonbit-axml](https://github.com/LING71671/moonbit-axml).
For account-sensitive operations on the configured Windows workstation, use
`scripts/moon.ps1` and `scripts/github.ps1`; they select LING71671 without changing
shared login state. See [account isolation](docs/ACCOUNTS.md).

[Apache-2.0](LICENSE). Authored fixture sources, tool versions, hashes, and external
reference licenses are documented in [THIRD_PARTY.md](THIRD_PARTY.md).
