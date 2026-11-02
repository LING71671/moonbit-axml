# Typed resource usage inventory

[中文](REFERENCES_zh.md) | [Typed values](VALUES.md) | [Project](../README.md)

## Collect usages

`Document::resource_references() -> Array[ResourceUsage]` lists typed resource and theme-attribute references without resource-table resolution:

```moonbit
let document = @axml.decode(bytes)
for usage in document.resource_references() {
  // The original event location, not an offset inside its attribute record.
  println("byte \{usage.offset}, line \{usage.line_number}")
  match usage.reference {
    Resource(id) => println("resource \{id}")
    ThemeAttribute(id) => println("theme attribute \{id}")
    DynamicResource(id) => println("dynamic resource \{id}")
    DynamicThemeAttribute(id) => println("dynamic theme attribute \{id}")
  }
}
```

## Records and ordering

`ResourceUsage` contains `offset: Int32`, `line_number: UInt32`, `origin: ResourceUsageOrigin`, and `reference: ValueReference`. Its origin is either `Attribute(namespace_uri, local_name)` or `Text`. Attribute origins retain their original namespace URI and case-sensitive local name; the enclosing element's default namespace is not assigned to an unqualified attribute.

Records follow the document's event array. Attributes within a start element follow their existing attribute-array order. Repeated IDs remain separate records, including repeated occurrences of the same kind. Entries are not sorted by offset or deduplicated. Text origins retain the text event's typed payload, even when its human-readable text differs.

## Boundaries

The method delegates type classification to `TypedValue::reference()`: Android type codes 1, 2, 7, and 8 remain distinct. Numeric IDs, including zero, are preserved exactly. It never parses reference-looking raw strings, converts integer/string values into references, or treats an attribute-name `resource_id` as an attribute-value usage. Unreferenced string-pool and resource-map entries are excluded.

This is a read-only event query. It does not resolve ARSC, infer resource names, extract APK entries, or validate manually constructed documents. Decode untrusted input first; locations in a valid decoded document identify the original event chunk and source line. The result is a fresh array and does not change the document.

## Verify

```sh
moon test src --target wasm-gc --filter '*resource*usage*' --deny-warn
moon test src --target js --filter '*resource*usage*' --deny-warn
```

Tests cover all four reference kinds in attributes and text, event/attribute ordering, duplicate IDs, exact namespaces, locations, zero IDs, empty inventories, and rejection of lookalike strings or numeric values.
