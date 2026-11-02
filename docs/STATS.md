# Document Statistics

[中文](STATS_zh.md)

## CLI

```sh
moon build src/cmd/axml --target js --deny-warn
node _build/js/debug/build/cmd/axml/axml.js stats --json fixtures/valid/menu.axml
```

`stats FILE` and `stats --json FILE` write the same indented JSON. Use
`stats -- --leading-dash.axml` or `stats --json -- --leading-dash.axml` for literal
filenames beginning with `--`. `stats --help` and `stats -h` print usage.
The native CLI accepts the same arguments. Binary decoding runs before counting;
malformed input exits with code one and its byte-offset diagnostic. Statistics
do not render XML or require a manifest root.

## Summarize a decoded document

```moonbit
let document = @axml.decode(input_bytes)
let stats = document.stats()
println(stats.max_depth)
println(stats.to_json().stringify(indent=2))
```

`Document::stats() -> DocumentStats` reads the existing pools and events without
rendering XML, resolving resources, or performing I/O. It runs in
`O(strings + events)` time with constant auxiliary space. It does not copy or
modify the document, allocate a tree, or validate the input again.

## Count meanings

| Field | Type | Meaning |
| --- | --- | --- |
| `strings` | `Int32` | Stored string-pool entries, including empty or duplicate entries |
| `string_utf16_units` | `Int64` | Sum of stored string lengths in UTF-16 code units |
| `resource_ids` | `Int32` | Stored resource-map entries, including zeros and duplicates |
| `events` | `Int32` | All events, including namespace starts and ends |
| `start_elements` | `Int32` | Start-element occurrences |
| `attributes` | `Int64` | Total attribute occurrences across start elements |
| `text_events` | `Int32` | Text-event occurrences, including empty text |
| `namespace_declarations` | `Int32` | Start-namespace occurrences; ends are not counted again |
| `max_depth` | `Int32` | Maximum simultaneous element depth, with the root at one |

The two aggregate totals use `Int64` so manually constructed documents can
share long strings or attribute arrays without overflowing a signed 32-bit
counter. `DocumentStats` derives `Eq`, `Debug`, and `ToJson`. MoonBit serializes
its `Int64` fields as decimal JSON strings; the `Int32` fields are JSON numbers.
String length counts a supplementary Unicode character as two units. Repeated
event references do not add to `string_utf16_units`; every stored pool entry is
counted once by position. Reused attribute arrays count once per start event.

## Manually constructed streams

An empty document returns zero counts and depth zero. Statistics do not check
XML names, namespaces, attribute uniqueness, root count, or balanced element
names. Depth increases at each start element and decreases at an end element
only while positive. An unmatched end at zero is ignored for depth; unclosed
starts still contribute to the maximum. A result is therefore a summary of
stored events, not proof that a manual document can be rendered or inspected.

For example, the owned `fixtures/valid/menu.axml` reports 11 strings, 108 UTF-16
units, six resource IDs, eight events, three start elements, eight attributes,
zero text events, one namespace declaration, and maximum depth two.

## Verify

Run `moon test src/stats_test.mbt --target wasm-gc --deny-warn`; repeat with `js`
and `native`. Tests include the committed aapt2 menu fixture, empty pools,
supplementary characters, namespaces, text, nesting and siblings, repeated
attribute arrays, unbalanced manual streams, and a total above `Int32` range.
`python scripts/verify_cli.py` additionally checks the CLI's menu statistics,
JSON field types, informational arguments, and rejection of malformed fixtures.
