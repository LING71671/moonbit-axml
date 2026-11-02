# Namespace-aware document queries

[中文](QUERIES_zh.md) | [Project](../README.md)

`Document::root()` returns the first start-element event, including its original
byte offset and line number, or `None` for a document without an element.
`Document::elements(namespace_uri, local_name)` returns matching start events in
document order. `Event::attribute(namespace_uri, local_name)` returns the matching
attribute on a start event; other event kinds return `None`.

```moonbit
let document = @axml.decode(input)
let applications = document.elements(None, "application")
for application in applications {
  let label = application.attribute(
    Some("http://schemas.android.com/apk/res/android"), "label",
  )
  // label retains raw_value and the original TypedValue.
  ignore(label)
}
```

Queries use expanded names: a namespace URI and case-sensitive local name.
`None` and `Some("")` both select the absence of a namespace. An element's default
namespace does not qualify its unprefixed attributes. Supply the Android namespace
URI to select `android:name`, independently of the prefix used in the input.

Queries operate on existing events without reparsing bytes or resolving resource
IDs. They do not validate manually constructed documents. Returned events retain
their attribute arrays; the helpers do not make a deep copy. Decode first when
working with untrusted input.
