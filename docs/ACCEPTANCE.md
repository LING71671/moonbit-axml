# Acceptance matrix

[中文](ACCEPTANCE_zh.md) | [Project](../README.md)

Status: **implemented and locally verified on 2026-11-02; release gates remain open**. This is the repository's delivery checklist, not an organizer-approved standard. The GitHub repository is public under Apache-2.0; `LING71671/axml` has not been published to Mooncakes.

## Verification snapshot

| Check | Verified result | Evidence |
| --- | --- | --- |
| MoonBit suite | 46/46 tests each on wasm-gc, JavaScript, Windows native, and Linux native | Colocated `src/*_test.mbt`, `src/*_wbtest.mbt`; Linux snapshot below |
| CLI corpus | 19 fixture hashes, 7 XML semantic trees, 3 manifest records, 12 malformed-input errors | `scripts/verify_cli.py`, `fixtures/manifest.json` |
| CLI hosts | Node.js, Windows native, Linux native | Same corpus; [Linux execution record](../evidence/verification-linux.json) |
| Independent references | aapt2 2.20-13193326, Android Build Tools 36.0.0 / android-36, androguard 4.1.3 | `fixtures/reference/`, [reproduction instructions](../fixtures/README.md) |

Linux verification ran as a native executable inside Debian on WSL2. It is not a remote CI result. Evidence files identify their toolchain versions and source hashes; new code changes require rerunning the relevant checks.

## Format and behavior

- [x] Decode all MVP chunk kinds, UTF-8/UTF-16 pools, namespaces, resource maps, CDATA, and raw/typed attributes; validate indices, chunk bounds, and document scopes.
- [x] Preserve raw values, typed payloads, and unresolved resource IDs. Resource references remain numeric; no ARSC lookup is implied.
- [x] Render escaped XML with equivalent expanded names and values. Independent ElementTree comparison uses normalized semantic trees, including namespace shadowing and Unicode cases.
- [x] Extract package/version, SDK declarations, permissions, application attributes, and components; compare three owned compiled manifests against independent references.
- [x] Reject malformed input with byte offsets. Twelve invalid fixtures plus whitebox truncation, Unicode, namespace, limits, and single-byte mutation tests pass; this is bounded testing, not exhaustive fuzzing.

## End-to-end workflows

- [x] Build-check scenario: decode and inspect extracted compiled manifests; package, SDK, permissions, and component records match references locally.
- [x] Catalog scenario: the verifier processes valid and invalid files separately; valid results survive, and each invalid invocation identifies its file and error.
- [x] Resource XML scenario: compiled menu AXML renders into independently parsed, namespace-aware XML with equivalent semantics.

The CLI accepts extracted AXML files, one per invocation. APK extraction and a persistent batch/catalog application are not implemented.

## Limits and reproducibility

- [x] Defaults enforce 16 MiB input, 100,000 strings, depth 256, 500,000 events, 65,535 attributes per element, and 4 Mi aggregate decoded UTF-16 string units; configurable-limit tests exercise rejection.
- [x] XML output defaults to 32 Mi UTF-16 units. Output-limit tests and shared-string/style-offset cases guard expansion; a 32,768-unit whitebox string and 33,000-unit corpus string exercise extended UTF-16 lengths.
- [x] Owned fixtures include origins, licenses, hashes, source XML, reference outputs, and generation scripts. No third-party APK is redistributed; the library itself needs no Android/JVM runtime.
- [ ] Establish measured large-pool, maximal-depth, repeated-reference, and malformed-input time/memory benchmarks. No throughput, peak-memory, or zero-copy guarantee is claimed.
- [x] Commit the implementation, evidence, licenses, and reproducibility material together. Initial commit `087beb9` was cloned into a clean checkout; formatting, all-backend checking, 46 JavaScript tests, CLI build, and the complete corpus verifier passed with a clean working tree.

## Release gates

- [x] Hosted Linux and Windows format/interface/check/build/test and JS/native CLI-corpus jobs passed for commit `19c2e11`: [GitHub Actions run](https://github.com/LING71671/moonbit-axml/actions/runs/41377746057), [recorded results](../evidence/verification-hosted.json). Each backend ran 46 tests on each host. Later documentation-only verification records do not alter that tested code.
- [ ] Review package contents and final metadata, verify the authenticated owner, and explicitly authorize publication. Use repository-scoped account wrappers from [ACCOUNTS.md](ACCOUNTS.md); never switch global accounts.
- [ ] Publish the approved Mooncakes release and verify installation from the registry. Current status remains unpublished.
- [ ] Before any contest application, rerun duplicate searches and have the participant review eligibility, application wording, and AI-use declarations. No automatic submission is implied.
