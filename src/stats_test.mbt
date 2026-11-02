///|
fn stats_document(
  kinds : Array[@axml.EventKind],
  strings~ : Array[String] = [],
  resource_ids~ : Array[UInt32] = [],
) -> @axml.Document {
  {
    strings,
    resource_ids,
    events: kinds.map(fn(kind) { { kind, offset: 8, line_number: 1U, } }),
  }
}

///|
fn stats_attribute() -> @axml.Attribute {
  {
    namespace_uri: None,
    name: "same",
    resource_id: None,
    raw_value: None,
    value: { data_type: 0x10, data: 1U, string_value: None, },
  }
}

///|
fn stats_text(value : String) -> @axml.EventKind {
  @axml.Text(value, { data_type: 3, data: 0U, string_value: Some(value), })
}

///|
test "empty document has zero statistics without requiring a root" {
  assert_eq(stats_document([]).stats(), @axml.DocumentStats::{
    strings: 0,
    string_utf16_units: 0L,
    resource_ids: 0,
    events: 0,
    start_elements: 0,
    attributes: 0L,
    text_events: 0,
    namespace_declarations: 0,
    max_depth: 0,
  })
}

///|
test "pool counts retain duplicates and measure UTF16 rather than scalars" {
  let document = stats_document([], strings=["", "a", "𠀀", "a"], resource_ids=[
    0U, 0x7f010001U, 0x7f010001U,
  ])
  let stats = document.stats()
  assert_eq(stats.strings, 4)
  assert_eq(stats.string_utf16_units, 4L)
  assert_eq(stats.resource_ids, 3)
  assert_eq(stats.events, 0)
  assert_eq(stats.max_depth, 0)
}

///|
test "namespace declarations and text events do not increase element depth" {
  let document = stats_document([
    @axml.StartNamespace(Some("p"), "urn:p"),
    @axml.StartElement(Some("urn:p"), "root", [stats_attribute()]),
    stats_text("before"),
    @axml.StartNamespace(Some("q"), "urn:q"),
    @axml.StartElement(Some("urn:q"), "child", [
      stats_attribute(),
      stats_attribute(),
    ]),
    stats_text(""),
    @axml.EndElement(Some("urn:q"), "child"),
    @axml.EndNamespace(Some("q"), "urn:q"),
    @axml.EndElement(Some("urn:p"), "root"),
    @axml.EndNamespace(Some("p"), "urn:p"),
  ])
  let stats = document.stats()
  assert_eq(stats.events, 10)
  assert_eq(stats.start_elements, 2)
  assert_eq(stats.attributes, 3L)
  assert_eq(stats.text_events, 2)
  assert_eq(stats.namespace_declarations, 2)
  assert_eq(stats.max_depth, 2)
}

///|
test "sibling elements reset depth and count every shared attribute occurrence" {
  let shared = [stats_attribute(), stats_attribute()]
  let document = stats_document([
    @axml.StartElement(None, "root", []),
    @axml.StartElement(None, "first", shared),
    @axml.StartElement(None, "nested", []),
    @axml.EndElement(None, "nested"),
    @axml.EndElement(None, "first"),
    @axml.StartElement(None, "second", shared),
    @axml.EndElement(None, "second"),
    @axml.EndElement(None, "root"),
  ])
  let stats = document.stats()
  assert_eq(stats.max_depth, 3)
  assert_eq(stats.start_elements, 4)
  assert_eq(stats.attributes, 4L)
  assert_eq(shared.length(), 2)
  assert_eq(document.events.length(), 8)
}

///|
test "manual unbalanced streams are counted without implicit validation" {
  let stats = stats_document([
    @axml.EndElement(None, "orphan"),
    @axml.EndNamespace(None, "urn:orphan"),
    @axml.StartElement(None, "open", []),
    @axml.EndElement(None, "different-name"),
    @axml.StartElement(None, "open-again", []),
    @axml.StartElement(None, "still-open", []),
  ]).stats()
  assert_eq(stats.events, 6)
  assert_eq(stats.start_elements, 3)
  assert_eq(stats.namespace_declarations, 0)
  assert_eq(stats.max_depth, 2)
}

///|
test "shared pool strings accumulate beyond signed Int32 without overflow" {
  let string = "a".repeat(65536)
  let stats = stats_document([], strings=Array::make(32768, string)).stats()
  assert_eq(stats.strings, 32768)
  assert_eq(stats.string_utf16_units, 2147483648L)
}

///|
test "shared attribute arrays accumulate beyond signed Int32 without expansion" {
  let shared = Array::make(65536, stats_attribute())
  let stats = stats_document(
    Array::make(32768, @axml.StartElement(None, "open", shared)),
  ).stats()
  assert_eq(stats.attributes, 2147483648L)
  assert_eq(stats.start_elements, 32768)
  assert_eq(stats.max_depth, 32768)
  assert_eq(shared.length(), 65536)
}

///|
test "compiled menu fixture reports pools declarations attributes and depth" {
  // fixtures/valid/menu.axml, from the owned aapt2-compiled menu source.
  // SHA-256: 79bf57f4ecbe71657af02cea1418de730e9512ad1d783be61a011800b760b154
  let document = @axml.decode(
    b"\x03\x00\x08\x00\x84\x02\x00\x00\x01\x00\x1c\x00\xd8\x00\x00\x00\x0b\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x48\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x07\x00\x00\x00\x11\x00\x00\x00\x16\x00\x00\x00\x20\x00\x00\x00\x32\x00\x00\x00\x3a\x00\x00\x00\x48\x00\x00\x00\x52\x00\x00\x00\x7f\x00\x00\x00\x86\x00\x00\x00\x04\x04\x69\x63\x6f\x6e\x00\x07\x07\x65\x6e\x61\x62\x6c\x65\x64\x00\x02\x02\x69\x64\x00\x07\x07\x76\x69\x73\x69\x62\x6c\x65\x00\x0f\x0f\x6f\x72\x64\x65\x72\x49\x6e\x43\x61\x74\x65\x67\x6f\x72\x79\x00\x05\x05\x74\x69\x74\x6c\x65\x00\x0b\x0b\x41\x64\x64\x20\x26\x20\x3c\x6e\x65\x77\x3e\x00\x07\x07\x61\x6e\x64\x72\x6f\x69\x64\x00\x2a\x2a\x68\x74\x74\x70\x3a\x2f\x2f\x73\x63\x68\x65\x6d\x61\x73\x2e\x61\x6e\x64\x72\x6f\x69\x64\x2e\x63\x6f\x6d\x2f\x61\x70\x6b\x2f\x72\x65\x73\x2f\x61\x6e\x64\x72\x6f\x69\x64\x00\x04\x04\x69\x74\x65\x6d\x00\x04\x04\x6d\x65\x6e\x75\x00\x00\x00\x00\x80\x01\x08\x00\x20\x00\x00\x00\x02\x00\x01\x01\x0e\x00\x01\x01\xd0\x00\x01\x01\x94\x01\x01\x01\xdf\x01\x01\x01\xe1\x01\x01\x01\x00\x01\x10\x00\x18\x00\x00\x00\x02\x00\x00\x00\xff\xff\xff\xff\x07\x00\x00\x00\x08\x00\x00\x00\x02\x01\x10\x00\x24\x00\x00\x00\x02\x00\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff\x0a\x00\x00\x00\x14\x00\x14\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x01\x10\x00\x74\x00\x00\x00\x03\x00\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff\x09\x00\x00\x00\x14\x00\x14\x00\x04\x00\x03\x00\x00\x00\x00\x00\x08\x00\x00\x00\x00\x00\x00\x00\xff\xff\xff\xff\x08\x00\x00\x01\x33\x00\x08\x01\x08\x00\x00\x00\x01\x00\x00\x00\xff\xff\xff\xff\x08\x00\x00\x12\xff\xff\xff\xff\x08\x00\x00\x00\x02\x00\x00\x00\xff\xff\xff\xff\x08\x00\x00\x01\x00\x00\x01\x7f\x08\x00\x00\x00\x05\x00\x00\x00\x06\x00\x00\x00\x08\x00\x00\x03\x06\x00\x00\x00\x03\x01\x10\x00\x18\x00\x00\x00\x03\x00\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff\x09\x00\x00\x00\x02\x01\x10\x00\x74\x00\x00\x00\x04\x00\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff\x09\x00\x00\x00\x14\x00\x14\x00\x04\x00\x01\x00\x00\x00\x00\x00\x08\x00\x00\x00\x02\x00\x00\x00\xff\xff\xff\xff\x08\x00\x00\x01\x01\x00\x01\x7f\x08\x00\x00\x00\x03\x00\x00\x00\xff\xff\xff\xff\x08\x00\x00\x12\x00\x00\x00\x00\x08\x00\x00\x00\x04\x00\x00\x00\xff\xff\xff\xff\x08\x00\x00\x10\x0a\x00\x00\x00\x08\x00\x00\x00\x05\x00\x00\x00\xff\xff\xff\xff\x08\x00\x00\x01\x00\x00\x03\x7f\x03\x01\x10\x00\x18\x00\x00\x00\x04\x00\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff\x09\x00\x00\x00\x03\x01\x10\x00\x18\x00\x00\x00\x02\x00\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff\x0a\x00\x00\x00\x01\x01\x10\x00\x18\x00\x00\x00\x02\x00\x00\x00\xff\xff\xff\xff\x07\x00\x00\x00\x08\x00\x00\x00",
  )
  assert_eq(document.stats(), @axml.DocumentStats::{
    strings: 11,
    string_utf16_units: 108L,
    resource_ids: 6,
    events: 8,
    start_elements: 3,
    attributes: 8L,
    text_events: 0,
    namespace_declarations: 1,
    max_depth: 2,
  })
}
