# Local browser workbench

[中文](DEMO_zh.md) | [Project](../README.md) | [Bridge schema](BROWSER.md)

## Start from the checkout

Install the project README's pinned MoonBit toolchain, Node.js 22.18+, and pnpm
11.14.0. No Mooncakes account is required. From the repository root:

```sh
cd playground
pnpm install --frozen-lockfile
pnpm dev
```

Open Vite's printed local address. Preparation compiles the actual MoonBit
release ESM, copies its declarations, and verifies owned sample hashes against
`fixtures/manifest.json`. Generated code, samples, dependencies, and `dist/`
remain ignored.

Choose a sample, select a local extracted AXML file, or drop one onto the page.
A module Worker parses the file; selected bytes are not uploaded. The app
requests its own static assets and bundled samples. A new selection or Cancel
stops the previous task. The language button switches English/Chinese; only
that preference is stored locally.

## Follow the owned samples

All six fixtures are repository-owned Apache-2.0 material. Their exact origins,
licenses, sizes, and SHA-256 hashes remain in the fixture manifest.

| Selection | File | Inspection path |
| --- | --- | --- |
| Basic manifest | `manifest_basic.axml` | XML, package/version, SDK declarations, permissions, and four components |
| Unicode manifest | `manifest_unicode.axml` | Literal Unicode names and metadata |
| Resource references | `manifest_references.axml` | Original typed resource IDs and manifest attributes |
| Menu XML | `menu.axml` | XML and four references; manifest inspection reports a different root |
| UTF-16 string pool | `synthetic_utf16.axml` | UTF-16 decoding, Unicode, and XML escaping |
| Truncated header | `truncated_header.axml` | Decode-stage error with its original byte offset |

Switch among XML, Manifest, Structure, and References without re-decoding.
Manifest includes declared intent filters when present. Source-location buttons
select corresponding event summaries within the preview. IDs remain numeric;
resource tables and Android runtime defaults are not inferred. Extract APK
entries separately: the workbench accepts AXML, not APK archives or textual XML.

## Filter events and references

This feature is deployed at [the live workbench](https://ling71671.github.io/moonbit-axml/)
from `ef6591b`; [verification](../evidence/verification-two-rounds.json) records
Linux/Windows CI, Pages, and hosted search/export/source-selection checks.

Structure and References each have a search field and Clear button. Matching is
a case-insensitive literal substring search after trimming surrounding spaces;
there is no regular-expression or query syntax. It runs locally without
re-decoding or uploading the input.

| View | Searchable fields | Examples |
| --- | --- | --- |
| Structure | Element/namespace name, protocol event kind, namespace URI, and byte offset in decimal or padded hexadecimal | `application`, `StartElement`, `android`, `0x00000100` |
| References | Reference kind, numeric ID, attribute/text origin, attribute namespace URI/name or expanded name, and byte offset | `Resource`, `0x7f010000`, `2130771968`, `Attribute`, `android` |

Hexadecimal IDs and offsets use `0x` followed by eight digits; decimal searches
do not use display grouping separators. Kind names use protocol values such as
`StartElement`, `Resource`, `Attribute`, and `Text` in both interface languages.
Queries stay in memory across view and language switches, and reset when a new
sample or file is selected. Clearing or editing a query returns to the first
result page. Source-location selection clears the Structure query and selects
the matching original event page; a source beyond the preview stays unavailable.

Structure's match count uses the retained event-preview length as its
denominator, at most 1,000, rather than the complete document event count.
References uses the full reference list. Both filtered tables retain 50-row
pagination. Copy/Download ignore the query and export the corresponding analysis
result; Structure JSON still has only the bounded event preview, never omitted
original events.

## Understand the limits

| Boundary | Workbench behavior |
| --- | --- |
| Input and processing | Reject files larger than 16 MiB before reading; a 10-second watchdog covers reading, Worker startup, and analysis |
| XML generation | Browser bridge budget is 2,097,152 UTF-16 units; exceeding it returns an XML-view error |
| XML display | Preview the first 100,000 UTF-16 units, wrapped by default; Copy/Download use the complete successful XML |
| Events and references | Retain the first 1,000 event summaries; event/reference tables show 50 rows per page |
| Manifest collections | Permissions, components, and intent filters each preview 50 entries with totals; full JSON remains available through Copy/Download |

Statistics cover the complete decoded document. Structure JSON contains the
bounded event preview; it does not restore omitted events. Detail JSON is
rendered when expanded. XML, manifest, and intent views report failures
independently, so decoding non-manifest XML does not establish a valid manifest.
The core library has separate configurable budgets, including a larger default
XML output limit. Display wrapping and preview truncation do not change raw
download output. Copy availability depends on the browser's clipboard access.

## Test and preview a production build

Run inside `playground/`:

```sh
pnpm test
pnpm build
pnpm preview
```

The frontend has 18 Node tests for limits, cancellation/races, Worker failures,
fixture copying, account-free contributor setup, the compiled bridge, and
literal filtering/source-page helpers.
`build` runs strict TypeScript checks and Vite; `preview` serves the resulting
`dist/` locally. Local MoonBit counts are 133 JavaScript tests, including the
JS-only bridge, and 130 each on wasm-gc and Windows native.

Local browser checks covered Unicode files, replacing prior results with a
malformed-input error, independent menu/manifest results, source-location
selection, language state, keyboard tabs, and exact XML download content.
A production build also loaded and decoded under the local `/moonbit-axml/`
prefix. These observations do not establish clipboard payload contents.

## GitHub Pages deployment

The production bundle uses relative paths (`base: "./"`) and includes its fonts,
Worker, and samples, supporting repository subpaths such as GitHub Pages.
Target: [LING71671 AXML workbench](https://ling71671.github.io/moonbit-axml/).
**Deployed and verified on 2026-11-02.** The basic manifest and menu samples,
local Unicode file parsing, reference-to-event selection, and XML download
worked at the hosted address. See [the deployment run](https://github.com/LING71671/moonbit-axml/actions/runs/41399307093).

The [Pages workflow](../.github/workflows/pages.yml) runs on pushes to `main`.
To rerun it manually, open repository Actions, choose **Deploy browser
workbench**, and use **Run workflow** on `main`. The repository Pages source
must be GitHub Actions; publishing settings are separate from local builds.

The build job pins Node.js 22, pnpm 11.14.0, and the project MoonBit toolchain,
installs the frozen lockfile, runs frontend tests, and builds the workbench.
Only `playground/dist` is uploaded. The deployment job requires a successful
build and uses the `github-pages` environment; failed tests/builds prevent that
deployment. Check the workflow's deployment URL and load a sample after each
release. `pnpm preview` remains a local server and does not publish the site.
