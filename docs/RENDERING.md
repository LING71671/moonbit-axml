# XML Rendering

[中文](RENDERING_zh.md)

`to_xml(document)` emits compact XML 1.0. `to_xml_pretty(document)` uses the same namespace, name, value, and escaping checks, adding two spaces per nesting level and LF separators between element-only children. Empty elements retain explicit end tags; no declaration or trailing newline is added.

```moonbit
let compact = @axml.to_xml(document)
let readable = @axml.to_xml_pretty(
  document,
  max_output_chars=2 * 1024 * 1024,
  max_depth=256,
)
```

## Content Preservation

A look-ahead pass detects direct text events before writing output. Any element with text retains compact output throughout its subtree, even when text occurs after child elements. Empty and whitespace-only AXML CDATA events count as text. Escaping preserves carriage returns and attribute whitespace as character references.

Subtrees with the expanded attribute `{http://www.w3.org/XML/1998/namespace}space="preserve"` also remain compact. This conservative rule extends through descendants carrying `xml:space="default"`. Formatting may still add a separator around the preserved subtree when its parent has element-only content.

Pretty rendering introduces whitespace text nodes between elements; it is opt-in and is neither canonical nor byte-equivalent XML. Use compact rendering when consumers require the exact text-node sequence. CDATA chunk contents are preserved as escaped text, without reconstructing CDATA delimiters. See the [XML whitespace rules](https://www.w3.org/TR/xml/#sec-white-space).

## Bounds and Diagnostics

Both functions default to a 32 Mi UTF-16-unit output limit. `max_output_chars` includes every added newline and indentation unit; non-BMP characters count as two units. A limit violation raises `DecodeError::Invalid` with the event's source byte offset.

Pretty rendering additionally defaults to `max_depth=256`, including manually constructed documents and compact-preserved subtrees. Both limits must be positive. Explicitly increasing `max_depth` supports documents decoded with larger `Limits`; indentation is checked against the output budget before multiplication or writing. The renderer uses iterative stacks rather than recursive traversal.

Run the rendering tests with `moon test src --target wasm-gc --deny-warn`; repeat with `js` and `native` for the supported targets.
