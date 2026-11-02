# Browser Analysis Bridge

[中文](BROWSER_zh.md) | [Statistics](STATS.md) | [References](REFERENCES.md)

## Build and call

```sh
moon build src/browser --target js --release --deny-warn
node --experimental-vm-modules scripts/verify_browser.mjs
```

The JS-only foreign-library package produces
`_build/js/release/build/browser/browser.js`, a self-contained ES module with
the named export `analyze_bytes`. Generated `browser.d.ts` and `moonbit.d.ts`
sit alongside it. MoonBit `Bytes` is a JavaScript `Uint8Array`; `String` is a
JavaScript string. The function uses no Node globals, file I/O, or networking.
It retains no state between calls and does not modify its input.

```js
import { analyze_bytes } from "./browser.js";
const report = JSON.parse(analyze_bytes(new Uint8Array(arrayBuffer)));
```

Run this synchronous call in a module Worker to keep large analyses off the UI
thread. Decode once per selected file and retain the parsed report when changing
views. A `Uint8Array` subarray is supported: only its visible bytes are decoded.
Transfer an owned `ArrayBuffer` to a Worker when the caller no longer needs it.

## Response schema, version 1

Every response is JSON text with `schema_version`, `ok`, and `input_bytes`.
`ok` reports binary decoding success, independently of the derived views.
Failure returns a top-level `error` with `stage: "decode"`, the original byte
`offset`, and `message`; it does not include partial view payloads.

A decoded response includes these fields:

| Field | Shape and meaning |
| --- | --- |
| `xml` | `{ok, value}` or `{ok, error}`; always includes `limit_utf16_units: 2097152` |
| `manifest`, `intents` | Independent `{ok: true, value}` or `{ok: false, error}` results |
| `stats` | [DocumentStats](STATS.md); `attributes` and `string_utf16_units` are decimal JSON strings |
| `references` | [ResourceUsage](REFERENCES.md) array with numeric IDs and original event locations |
| `events` | `{total, preview, limit: 1000, truncated}` with ordered event summaries |

View errors use stages `xml`, `manifest`, or `intents`, plus byte `offset` and
`message`. A valid menu therefore retains XML, statistics, references, and event
summaries even when manifest and intent inspection fail. An XML preview limit
failure also retains the other views. Check each view's `ok` before reading its
`value`; do not treat the top-level `ok` as successful XML or manifest validation.

## Event previews and limits

Each preview item contains `index`, `offset`, `line_number`, `kind`,
`namespace_uri`, `name`, `attribute_count`, and `text_utf16_units`. Kind strings
are `StartNamespace`, `EndNamespace`, `StartElement`, `EndElement`, and `Text`.
Namespace events use their prefix as `name`; absent or irrelevant names/URIs
are `null`. Irrelevant counts are zero. Indices refer to the original event
array, not a filtered table. Only the first 1,000 events are previewed.

The preview does not repeat attribute or text payloads and never exports string
or resource pools. References and manifest attributes preserve their existing
derived JSON representation, including optional positional namespace arrays.
Input decoding uses the core defaults, including a 16-MiB input limit. The XML
view has a separate 2-Mi UTF-16-unit output budget and returns an error rather
than partial XML. The browser bridge does not impose another metadata/JSON size
budget; a Worker host should support terminating and replacing a long-running
analysis. Manifest and intent APIs currently perform their own XML validation
internally, so the bridge avoids repeated byte decoding but can render-check
the same document more than once.

## Verification scope

The verifier executes the compiled ESM in a VM sandbox with no `process`,
`require`, or `Buffer`, and rejects module imports and Node dependencies. It
checks owned menu/basic/reference/Unicode fixtures, malformed inputs, nonzero
typed-array offsets, exact event summaries, the 1,000-event boundary, forbidden
XML characters, the input limit, and XML-budget failure isolation. These checks
establish the bridge's host boundary; browser Worker/UI integration is a
separate verification step.
