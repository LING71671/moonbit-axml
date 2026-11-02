# Product

<!-- impeccable:product-schema 1 -->

[中文](PRODUCT_zh.md)

## Platform

web

## Stack

Confirmed: Vite, TypeScript, Tailwind CSS, and pnpm. The demo is a static site
compatible with GitHub Pages. Build directly in code; the workflow preference
is stored in `.impeccable/config.json`.
The [deployed workbench](https://ling71671.github.io/moonbit-axml/) uses GitHub Pages.

## Users

Developers evaluating the MoonBit AXML library or inspecting extracted compiled
Android XML. The main task is choosing a sample or local file and examining its
decoded XML, manifest declarations, structure, and resource references.

## Product Purpose

Make the actual MoonBit decoder usable in a browser workbench. Success means a
visitor can load an input, understand its result or diagnostic, and copy or
download the relevant output without installing Android tooling.

## Capabilities and Constraints

The pure MoonBit core supports checked AXML decoding, rendering, manifest and
intent-filter inspection, statistics, and located typed references. The browser
adapter exports a standalone ESM bridge; Node-specific CLI I/O must not enter its bundle.
The library and CLI offer bounded, opt-in pretty XML rendering. Structure and
References offer local literal search; Structure remains a 1,000-event preview,
and filtering never narrows exported results.
Local files are processed on the client, with no upload or server API. Input
budgets and display truncation must be visible where they affect an action.
APK extraction, resource-table resolution, repair, and security verdicts are
outside the demo. Ordinary resource XML remains useful when manifest inspection
is inapplicable. Heavy parsing belongs in a cancellable worker.

## Brand Commitments

Name: MoonAXML. Confirmed icon direction: XML brackets with binary blocks.
The surface is an interactive workbench rather than a marketing landing page.
Use concise, factual product copy, without a decorative onboarding flow.
Use a dark-first workspace. The selected continuous-folio direction translates
warm stock into charcoal, ivory, sepia rules, and restrained scarlet controls.

## Evidence on Hand

Linux/Windows CI at `ef6591b` verifies 130 wasm-gc tests, 133 JavaScript tests,
130 native tests, and 18 frontend tests per host. The same revision is deployed
to Pages; [two-round evidence](evidence/verification-two-rounds.json) records
the runs and hosted search/download checks. `fixtures/`
contains 19 owned valid/invalid inputs and pinned independent references.
`docs/ACCEPTANCE.md` and `evidence/` identify tested source revisions. Do not
invent customers, performance rankings, or deployment status.

## Product Principles

- Use the compiled MoonBit implementation, not precomputed demo answers.
- Keep local input contents and filenames on the user's device.
- Preserve useful views when another inspection stage fails.
- Distinguish declarations and unresolved values from inferred platform behavior.
- Keep file selection, result navigation, and diagnostics usable with a keyboard.
