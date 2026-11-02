///|
fn query_test_event(kind : @axml.EventKind, offset : Int32) -> @axml.Event {
  { kind, offset, line_number: 7U, }
}

///|
fn query_test_document(events : Array[@axml.Event]) -> @axml.Document {
  { strings: [], resource_ids: [], events, }
}

///|
fn query_test_attribute(
  uri : String?,
  name : String,
  value : String,
) -> @axml.Attribute {
  {
    namespace_uri: uri,
    name,
    resource_id: None,
    raw_value: Some(value),
    value: { data_type: 3, data: 0U, string_value: Some(value), },
  }
}

///|
test "expanded element queries preserve input order and exact namespaces" {
  let first = query_test_event(
    @axml.StartElement(Some("urn:one"), "item", []),
    10,
  )
  let other = query_test_event(
    @axml.StartElement(Some("urn:two"), "item", []),
    20,
  )
  let unqualified = query_test_event(@axml.StartElement(None, "item", []), 30)
  let last = query_test_event(
    @axml.StartElement(Some("urn:one"), "item", []),
    40,
  )
  let document = query_test_document([first, other, unqualified, last])
  assert_eq(document.elements(Some("urn:one"), "item"), [first, last])
  assert_eq(document.elements(Some("urn:two"), "item"), [other])
  assert_eq(document.elements(Some(""), "item"), [unqualified])
  assert_eq(document.elements(None, "Item"), [])
}

///|
test "root query skips declarations and text and retains original locations" {
  let root = query_test_event(@axml.StartElement(None, "root", []), 88)
  let document = query_test_document([
    query_test_event(@axml.StartNamespace(Some("p"), "urn:one"), 8),
    root,
    query_test_event(@axml.EndElement(None, "root"), 120),
  ])
  assert_eq(document.root(), Some(root))
  assert_eq(query_test_document([]).root(), None)
  assert_eq(
    query_test_document([
      query_test_event(@axml.EndNamespace(Some("p"), "urn:one"), 8),
    ]).root(),
    None,
  )
}

///|
test "attribute lookup distinguishes unqualified and qualified attributes" {
  let plain = query_test_attribute(None, "name", "plain")
  let android = query_test_attribute(
    Some("http://schemas.android.com/apk/res/android"),
    "name",
    ".Main",
  )
  let event = query_test_event(
    @axml.StartElement(Some("urn:default"), "application", [plain, android]),
    50,
  )
  assert_eq(event.attribute(None, "name"), Some(plain))
  assert_eq(event.attribute(Some(""), "name"), Some(plain))
  assert_eq(
    event.attribute(Some("http://schemas.android.com/apk/res/android"), "name"),
    Some(android),
  )
  assert_eq(event.attribute(Some("urn:default"), "name"), None)
  assert_eq(event.attribute(None, "Name"), None)
}

///|
test "non-start events and missing names have no attributes" {
  let event = query_test_event(@axml.EndElement(None, "root"), 20)
  assert_eq(event.attribute(None, "name"), None)
  let event = query_test_event(@axml.StartElement(None, "root", []), 20)
  assert_eq(event.attribute(None, "missing"), None)
}
