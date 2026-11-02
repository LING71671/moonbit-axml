# Reproducible fixtures

[中文](README_zh.md) | [Project](../README.md)

All XML sources and synthetic data are authored for this repository and licensed
under the repository's Apache-2.0 license. No third-party APKs are redistributed.
`manifest.json` records source and binary SHA-256 hashes, origins, tool versions,
licenses, and the generation command.

## Corpus

- `valid/manifest_basic.axml`: version, SDK, two permissions, and four component kinds.
- `valid/manifest_unicode.axml`: supplementary Unicode, XML escaping, and attribute whitespace.
- `valid/manifest_references.axml` and `valid/menu.axml`: unresolved app/platform references and compiled resource XML.
- `valid/synthetic_utf*.axml`: independently built UTF-8/UTF-16 pools, namespace-aware elements, text, and a two-word 33,000-unit UTF-16 length.
- `invalid/`: twelve independent truncation/field mutations exercising chunk bounds, indices, encoding, terminators, attribute stride, and mismatched elements.

## Regenerate

Install Android SDK Build Tools **36.0.0** and platform **android-36**, then run:

```powershell
uv venv A:\DevEnv\Envs\moonbit-axml --python 3.12
uv pip install --python A:\DevEnv\Envs\moonbit-axml\Scripts\python.exe androguard==4.1.3
& A:\DevEnv\Envs\moonbit-axml\Scripts\python.exe scripts/generate_fixtures.py --sdk $env:ANDROID_HOME
```

The generator checks aapt2 revision `2.20-13193326`, records local tool hashes,
builds APKs only in ignored `_build/fixtures/`, and extracts committed binary XML.
`reference/*.aapt2.txt` and `*.badging.txt` come from aapt2. `reference/*.xml` and
`*.tree.json` come from **androguard 4.1.3**, independently of the MoonBit code.
Synthetic files are explicitly marked synthetic and are also decoded by androguard.
The generated portable MoonBit tests embed the fixtures and require no filesystem.

## Verify

```powershell
python scripts/verify_cli.py
```

Verification needs only Python's standard library, MoonBit, and Node.js. It checks
hashes, parses CLI output with ElementTree, compares expanded names/attributes/text
with independent trees, checks manifest metadata, and requires offset-bearing errors
for malformed inputs. Equivalent numeric resource spellings are normalized; XML
formatting and namespace prefix selection are not compared.
