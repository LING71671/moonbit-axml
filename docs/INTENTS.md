# Manifest Intent Filters

[中文](INTENTS_zh.md)

`inspect_intent_filters(document)` returns declarations in document order without
changing `Manifest` or inferring Android runtime behavior.

## Inspect declarations

```moonbit
let filters = @axml.inspect_intent_filters(document)
for filter in filters {
  let declares_view = filter.has_action("android.intent.action.VIEW")
  let declares_browsable = filter.has_category("android.intent.category.BROWSABLE")
  // Inspect filter.component_name and filter.data for the original typed values.
}
```

The inspector selects unqualified `intent-filter` elements directly inside
unqualified `activity`, `activity-alias`, `service` and `receiver` declarations
under `manifest/application`. Provider filters are outside this API's current
scope. Namespace-qualified extensions and extra wrappers cannot impersonate
these ancestors. Nested declarations, including data inside
`uri-relative-filter-group`, are not flattened into the result.

Android's [intent-filter reference](https://developer.android.com/guide/topics/manifest/intent-filter-element)
describes platform declarations. This API reports the subset above; it does not
implement Android's intent resolution or validate the full manifest schema.

## Retained information

| Field | Meaning |
| --- | --- |
| `component_kind`, `component_name` | Original parent kind and optional Android-namespace `name` attribute. Relative names and resource references remain unchanged. |
| `offset`, `line_number` | Original filter start-element location. |
| `attributes` | All original filter attributes, including unknown attributes. |
| `actions`, `categories` | Android-namespace `name` attributes of direct unqualified children, preserving order, duplicates, raw values and typed references. Children without that attribute are omitted. |
| `data` | One attribute array per direct unqualified `data` child, retaining empty declarations, ordering and every namespace. |

Each filter has separate action, category and data arrays. Attribute arrays
retained from document events are shared with the document; treat them as
read-only when preserving the original inspection result.

`has_action` and `has_category` perform case-sensitive matches against literal
string typed `android:name` values. Empty queries, unresolved references and
non-string values never match; apparent raw text is not a resolved value.
These helpers test declarations only. They do not decide launchability,
exported/enabled state, App Links verification, URI matching or platform defaults.

## Validation and tests

Inspection calls `inspect_manifest` once before collecting filters. Its manifest
and XML validation, offset-bearing `DecodeError` diagnostics and XML output limit
also apply to manually constructed documents. An otherwise valid manifest with
no selected filters returns an empty array; an empty filter is retained without
requiring an action declaration.

```sh
moon test src/intent_filters_test.mbt --target wasm-gc --deny-warn
```

Repeat with `--target js` and `--target native` for the other supported backends.
