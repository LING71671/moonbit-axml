# Acceptance matrix

[中文](ACCEPTANCE_zh.md) | [Project](../README.md)

Status: **implemented and locally verified on 2026-11-02; release gates remain open**. This is the repository's delivery checklist, not an organizer-approved standard. The GitHub repository is public under Apache-2.0; `LING71671/axml` has not been published to Mooncakes.

## Verification snapshot

| Check | Verified result | Evidence |
| --- | --- | --- |
| Current local MoonBit suite | 75/75 tests each on wasm-gc, JavaScript, and Windows native | [Development verification](../evidence/verification-development.json); colocated tests including `src/catalog/` |
| Current hosted MoonBit suite | 75/75 tests per backend on Linux and Windows; wasm-gc, JavaScript, and native | [CI for `61279a8`](https://github.com/LING71671/moonbit-axml/actions/runs/41391697996), [recorded results](../evidence/verification-development.json) |
| CLI corpus | 19 fixture hashes, 7 XML semantic trees, 3 manifest records, 12 malformed-input errors | `scripts/verify_cli.py`, `fixtures/manifest.json` |
| CLI hosts | Node.js, Windows native, Linux native | Same corpus; [Linux execution record](../evidence/verification-linux.json) |
| Independent references | aapt2 2.20-13193326, Android Build Tools 36.0.0 / android-36, androguard 4.1.3 | `fixtures/reference/`, [reproduction instructions](../fixtures/README.md) |
| Bounded Windows benchmarks | Four cases, JS/native, three measured runs per case; all 24 pass | [Method and results](BENCHMARKS.md), [raw evidence](../evidence/benchmark.json) |

The earlier 46-test Linux snapshot ran as a native executable inside Debian on WSL2. It is distinct from hosted CI and does not cover subsequent APIs. Evidence files identify their toolchain versions and source hashes; new code changes require rerunning the relevant checks.

## Format and behavior

- [x] Decode all MVP chunk kinds, UTF-8/UTF-16 pools, namespaces, resource maps, CDATA, and raw/typed attributes; validate indices, chunk bounds, and document scopes.
- [x] Preserve raw values, typed payloads, and unresolved resource IDs. Resource references remain numeric; no ARSC lookup is implied.
- [x] Render escaped XML with equivalent expanded names and values. Independent ElementTree comparison uses normalized semantic trees, including namespace shadowing and Unicode cases.
- [x] Extract package/version, SDK declarations, permissions, application attributes, and components; compare three owned compiled manifests against independent references.
- [x] Reject malformed input with byte offsets. Twelve invalid fixtures plus whitebox truncation, Unicode, namespace, limits, and single-byte mutation tests pass; this is bounded testing, not exhaustive fuzzing.

## End-to-end workflows

- [x] Build-check scenario: decode and inspect extracted compiled manifests; package, SDK, permissions, and component records match references locally.
- [x] Catalog scenario: `LING71671/axml/catalog` processes named byte inputs in order, retaining successes and stage/offset diagnostics for individual failures. Tests cover mixed batches, custom limits, duplicate labels, and non-manifest XML; see [the API](CATALOG.md).
- [x] Resource XML scenario: compiled menu AXML renders into independently parsed, namespace-aware XML with equivalent semantics.

The CLI accepts extracted AXML files, one per invocation, with help/version flags and a literal-file `--` terminator. The batch library performs no I/O and does not cap aggregate retained data. APK extraction and a persistent catalog application are not implemented.

## Limits and reproducibility

- [x] Defaults enforce 16 MiB input, 100,000 strings, depth 256, 500,000 events, 65,535 attributes per element, and 4 Mi aggregate decoded UTF-16 string units; configurable-limit tests exercise rejection.
- [x] XML output defaults to 32 Mi UTF-16 units. Output-limit tests and shared-string/style-offset cases guard expansion; a 32,768-unit whitebox string and 33,000-unit corpus string exercise extended UTF-16 lengths.
- [x] Owned fixtures include origins, licenses, hashes, source XML, reference outputs, and generation scripts. No third-party APK is redistributed; the library itself needs no Android/JVM runtime.
- [x] Measure large-pool, maximal-depth, repeated-reference, and malformed-input time/memory benchmarks on Windows JS/native. Independent expected XML hashes and exact malformed offsets are checked; see [BENCHMARKS.md](BENCHMARKS.md). Results are bounded observations, not portable throughput, memory, or zero-copy guarantees.
- [x] Commit the implementation, evidence, licenses, and reproducibility material together. Initial commit `087beb9` was cloned into a clean checkout; formatting, all-backend checking, 46 JavaScript tests, CLI build, and the complete corpus verifier passed with a clean working tree.

## Release gates

- [x] Current hosted Linux and Windows verification passed for `61279a8`: 75 tests per backend and the complete JS/native CLI corpus, including help/version/terminator checks. [GitHub Actions run](https://github.com/LING71671/moonbit-axml/actions/runs/41391697996), [recorded results](../evidence/verification-development.json). Subsequent documentation/evidence commits do not change the tested source.
- [x] Initial hosted Linux and Windows format/interface/check/build/test and JS/native CLI-corpus jobs passed for commit `19c2e11`: [GitHub Actions run](https://github.com/LING71671/moonbit-axml/actions/runs/41377746057), [recorded results](../evidence/verification-hosted.json). Each backend ran 46 tests on each host. This historical snapshot predates the query, batch, and rendering additions; current verification is recorded separately.
- [ ] Review package contents and final metadata, verify the authenticated owner, and explicitly authorize publication. Use repository-scoped account wrappers from [ACCOUNTS.md](ACCOUNTS.md); never switch global accounts.
- [ ] Publish the approved Mooncakes release and verify installation from the registry. Current status remains unpublished.
- [ ] Before any contest application, rerun duplicate searches and have the participant review eligibility, application wording, and AI-use declarations. No automatic submission is implied.
