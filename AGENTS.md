# Repository Guidelines

[中文](AGENTS_zh.md)

## Project Structure & Module Organization

`moon.mod` defines `LING71671/axml`. `src/` contains decoding, rendering, manifest inspection, statistics, references, and intents. `src/catalog/` handles batches; `src/cli/` and `src/cmd/` provide arguments and host I/O. `src/browser/` exports the JS bridge. `playground/` holds the Vite/TypeScript/Tailwind workbench, Worker controller, and Node tests. MoonBit tests are colocated. `fixtures/`, `scripts/`, `docs/`, and `evidence/` preserve samples, reproduction, guidance, and verification.

## Build, Test, and Development Commands

Use README-pinned MoonBit; frontend requirements are Node.js 22.18+ and pnpm 11.14.0. From the root:

- `moon fmt --check` and `moon info`: check formatting and regenerate public `.mbti` interfaces.
- `moon check --target all --deny-warn`; `moon test --target wasm-gc --deny-warn`: check/test; repeat tests with `js` and `native`.
- `python scripts/verify_cli.py`: verify independent fixtures. Build both CLIs before `python scripts/benchmark.py`.
- `pnpm --dir playground install --frozen-lockfile`; `pnpm --dir playground dev`: prepare ESM/samples and start Vite.
- `pnpm --dir playground test`, `pnpm --dir playground build`, `pnpm --dir playground preview`: test, type-check/build, or locally serve existing output. See `docs/DEMO.md`.

## Coding Style & Naming Conventions

Use two-space indentation and `moon fmt`. MoonBit functions/files use snake_case; public types use UpperCamelCase. TypeScript follows existing camelCase functions and kebab-case filenames. Review generated interfaces; regenerate fixture tests through scripts. Synchronize English documentation and reciprocal `_zh.md` translations.

## Testing Guidelines

Use `*_test.mbt` for public behavior and `*_wbtest.mbt` for internals; no coverage percentage is mandated. Local counts are 130 wasm-gc, 133 JS, 130 Windows native, and 12 frontend Node tests. Cover bounds, namespaces, typed data, diagnostics, cancellation, stale results, and compiled-bridge integration. Preserve fixture provenance/hashes and independent references. Keep generated frontend code, samples, dependencies, and `dist/` ignored. Record browser checks separately.

## Commit & Pull Request Guidelines

Use Conventional Commits. PRs explain behavior, link issues/acceptance items, list executed checks and limitations, and update both documentation languages. Run `git diff --check`.

## Account Isolation & Scope

Follow `docs/ACCOUNTS.md` for authenticated wrappers; never switch global accounts or commit credentials. Public builds require no login. Keep parsing local and IDs unresolved. Browser input is capped at 16 MiB with a 10-second watchdog. APK extraction and ARSC resolution remain outside scope. `.github/workflows/pages.yml` publishes only `playground/dist` to GitHub Pages.
