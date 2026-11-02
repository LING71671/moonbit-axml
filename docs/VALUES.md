# Typed Android value views

[中文](VALUES_zh.md) | [Project](../README.md)

`TypedValue` always preserves `data_type`, the exact 32-bit `data`, and the decoded
`string_value` when applicable. Its views interpret only the matching type family:

| Method | Matching types | Result |
| --- | --- | --- |
| `as_string()` | TYPE_STRING | Optional decoded pool string |
| `as_integer()` | TYPE_INT_DEC / TYPE_INT_HEX | Optional signed Int32, including negative bit patterns |
| `as_boolean()` | TYPE_INT_BOOLEAN | Optional Bool; zero is false, nonzero is true |
| `as_float()` | TYPE_FLOAT | Optional IEEE-754 Float |
| `reference()` | Resource/theme and dynamic references | Optional `ValueReference` with kind and numeric ID |

A mismatch returns `None`. These methods perform no text coercion: a string
containing `"42"` is a string, and an integer containing a resource-looking number
is an integer. Resource and theme references remain distinct; dynamic kinds retain
the fact that package-ID rebinding may be required by an external resource loader.

```moonbit
match attribute.value.reference() {
  Some(@axml.ValueReference::Resource(id)) => ignore(id)
  Some(_) => ()
  None => ignore(attribute.value.as_string())
}
```

The float view retains NaN and infinity payloads for inspection. XML output still
rejects non-finite values. Views do not supply Android defaults or resolve ARSC
entries; raw metadata remains available for application-specific policies.
