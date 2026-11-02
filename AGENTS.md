# Repository Guidelines

[中文](AGENTS_zh.md)

## Project Structure & Module Organization

`moon.mod` defines `LING71671/axml`, with the library in `src/`. `reader.mbt`, `string_pool.mbt`, and `decoder.mbt` decode bytes; `model.mbt`, `render.mbt`, and `manifest.mbt` expose events, XML, and metadata. `src/cli/` handles commands; `src/cmd/axml/` supplies Node.js I/O and `src/cmd/axml-native/` native I/O. Tests are colocated. `fixtures/` contains owned sources, binaries, and independent references; `scripts/` reproduces and verifies them. `docs/` and `evidence/` record scope and verification.

## Build, Test, and Development Commands

Run from the repository root with the pinned MoonBit toolchain:

- `moon fmt --check` and `moon info`: verify formatting and regenerate public interfaces; review resulting `.mbti` changes.
- `moon check --target all --deny-warn`: check all backends without warnings.
- `moon test --target wasm-gc --deny-warn`: run tests; repeat with `js` and `native`.
- `moon build src/cmd/axml --target js --deny-warn`: build the Node CLI; run `node _build/js/debug/build/cmd/axml/axml.js validate fixtures/valid/menu.axml`.
- `python scripts/verify_cli.py`: check fixture hashes, XML semantics, metadata, and malformed-input diagnostics. See `fixtures/README.md` for regeneration.

## Coding Style & Naming Conventions

Use two-space indentation and `moon fmt`. Name functions/files in snake_case and public types in UpperCamelCase. Keep generated `.mbti` files synchronized with `moon info`; do not edit generated fixture tests manually. Write English documentation with reciprocal `_zh.md` translations. Preserve two-space JSON indentation and descriptive uppercase documentation filenames.

## Testing Guidelines

Use MoonBit's built-in test runner: `*_test.mbt` for public behavior and `*_wbtest.mbt` for internals. No coverage percentage is mandated. Cover bounds, encodings, namespace scopes, typed values, escaping, and error offsets. Compare expanded-name semantic trees and metadata against pinned aapt2/androguard references. Maintain origins, licenses, hashes, and reproduction commands in `fixtures/manifest.json`. Local and hosted Linux/Windows checks pass; see `docs/ACCEPTANCE.md` for the verified commit and evidence.

## Commit & Pull Request Guidelines

Use Conventional Commits, such as `feat: decode string pools`. PRs should explain behavior, link acceptance items or issues, list executed checks, identify limitations, and update both documentation languages. Run `git diff --check` before committing.

## Account Isolation & Scope

Follow `docs/ACCOUNTS.md`: use repository account wrappers for authenticated operations; never switch global Mooncakes/GitHub accounts or commit credentials. Keep decoding pure MoonBit and offline. Preserve unresolved resource IDs; APK extraction, ARSC resolution, signing, and DEX parsing remain outside scope.
