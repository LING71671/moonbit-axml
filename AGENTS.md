# Repository Guidelines

[中文](AGENTS_zh.md)

## Project Structure & Module Organization

`moon.mod` defines `LING71671/axml`. Core decoding, XML rendering, and manifest inspection live in `src/`; `query.mbt`, `value_views.mbt`, and `manifest_helpers.mbt` provide convenience APIs. `src/catalog/` independently processes named input batches. `src/cli/` handles arguments; `src/cmd/axml/` and `src/cmd/axml-native/` supply Node.js and native I/O. Tests are colocated. `fixtures/` contains owned samples and independent references; `scripts/` reproduces and verifies them. `docs/` and `evidence/` record scope and verification.

## Build, Test, and Development Commands

Run from the repository root with the pinned MoonBit toolchain:

- `moon fmt --check` and `moon info`: check formatting and regenerate public `.mbti` interfaces.
- `moon check --target all --deny-warn`: check all backends without warnings.
- `moon test --target wasm-gc --deny-warn`: run tests; repeat with `js` and `native`.
- `moon build src/cmd/axml --target js --deny-warn`: build the Node CLI. Build native with `moon build src/cmd/axml-native --target native --deny-warn`.
- `python scripts/verify_cli.py`: verify fixtures and CLI behavior. After building both CLIs, run `python scripts/benchmark.py --backend all --repeats 3`; see `docs/BENCHMARKS.md` for executable paths and measurement limits.

## Coding Style & Naming Conventions

Use two-space indentation and `moon fmt`. Name functions/files in snake_case and public types in UpperCamelCase. Review generated `.mbti` changes; regenerate fixture tests through their script. Maintain English documentation with reciprocal `_zh.md` translations, two-space JSON indentation, and descriptive uppercase documentation filenames.

## Testing Guidelines

Use MoonBit's built-in runner: `*_test.mbt` for public behavior and `*_wbtest.mbt` for internals. No coverage percentage is mandated. Cover bounds, encodings, namespaces, typed values, escaping, batch isolation, and error offsets. Compare semantic trees and metadata against pinned aapt2/androguard references. Preserve fixture provenance and hashes in `fixtures/manifest.json`. Consult `docs/ACCEPTANCE.md` for per-commit verification evidence.

## Commit & Pull Request Guidelines

Use Conventional Commits, such as `feat: decode string pools`. PRs explain behavior, link issues or acceptance items, list executed checks and limitations, and update both documentation languages. Run `git diff --check` before committing.

## Account Isolation & Scope

Follow `docs/ACCOUNTS.md`: use `scripts/moon.ps1` and `scripts/github.ps1` for authenticated operations as `LING71671`. Never switch global accounts or commit credentials. Keep decoding pure MoonBit and offline. Preserve unresolved resource IDs; APK extraction, ARSC resolution, signing, and DEX parsing remain outside scope.
