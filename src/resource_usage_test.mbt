///|
fn usage_value(
  kind : Int32,
  data : UInt32,
  text~ : String? = None,
) -> @axml.TypedValue {
  { data_type: kind, data, string_value: text, }
}

///|
fn usage_attribute(
  name : String,
  value : @axml.TypedValue,
  uri~ : String? = None,
  raw~ : String? = None,
  name_id~ : UInt32? = None,
) -> @axml.Attribute {
  { namespace_uri: uri, name, resource_id: name_id, raw_value: raw, value, }
}

///|
fn usage_event(
  kind : @axml.EventKind,
  offset : Int32,
  line~ : UInt32 = 1U,
) -> @axml.Event {
  { kind, offset, line_number: line, }
}

///|
fn usage_document(events : Array[@axml.Event]) -> @axml.Document {
  { strings: ["@string/unreferenced"], resource_ids: [0x7f010001U], events, }
}

///|
test "resource usage inventories are empty without typed references" {
  assert_eq(usage_document([]).resource_references(), [])
  let document = usage_document([
    usage_event(@axml.StartNamespace(Some("p"), "urn:test"), 8),
    usage_event(@axml.StartElement(None, "root", []), 32),
    usage_event(@axml.EndElement(None, "root"), 68),
    usage_event(@axml.EndNamespace(Some("p"), "urn:test"), 92),
  ])
  assert_eq(document.resource_references(), [])
}

///|
test "resource usage attributes preserve all four static and dynamic kinds" {
  let kinds = [
    (1, @axml.ValueReference::Resource(0x7f010001U)),
    (2, @axml.ValueReference::ThemeAttribute(0x7f010001U)),
    (7, @axml.ValueReference::DynamicResource(0x7f010001U)),
    (8, @axml.ValueReference::DynamicThemeAttribute(0x7f010001U)),
  ]
  for (kind, expected) in kinds {
    let document = usage_document([
      usage_event(
        @axml.StartElement(None, "root", [
          usage_attribute("value", usage_value(kind, 0x7f010001U)),
        ]),
        72,
        line=12U,
      ),
    ])
    let usages = document.resource_references()
    assert_eq(usages.length(), 1)
    assert_eq(usages[0].reference, expected)
    assert_eq(usages[0].offset, 72)
    assert_eq(usages[0].line_number, 12U)
    assert_eq(
      usages[0].origin,
      @axml.ResourceUsageOrigin::Attribute(None, "value"),
    )
  }
}

///|
test "resource usage text preserves typed payloads including zero IDs" {
  for
    (kind, expected) in [
      (1, @axml.ValueReference::Resource(0U)),
      (2, @axml.ValueReference::ThemeAttribute(0U)),
      (7, @axml.ValueReference::DynamicResource(0U)),
      (8, @axml.ValueReference::DynamicThemeAttribute(0U)),
    ] {
    let document = usage_document([
      usage_event(
        @axml.Text("literal text", usage_value(kind, 0U)),
        144,
        line=20U,
      ),
    ])
    let usages = document.resource_references()
    assert_eq(usages.length(), 1)
    assert_eq(usages[0].reference, expected)
    assert_eq(usages[0].origin, @axml.ResourceUsageOrigin::Text)
    assert_eq(usages[0].offset, 144)
    assert_eq(usages[0].line_number, 20U)
  }
}

///|
test "resource usage order preserves mixed events attributes and duplicate IDs" {
  let document = usage_document([
    usage_event(
      @axml.StartElement(None, "root", [
        usage_attribute("first", usage_value(1, 42U)),
        usage_attribute("plain", usage_value(0x10, 42U)),
        usage_attribute("second", usage_value(2, 42U)),
      ]),
      80,
      line=3U,
    ),
    usage_event(@axml.Text("text", usage_value(7, 42U)), 24, line=4U),
    usage_event(
      @axml.StartElement(None, "child", [
        usage_attribute("third", usage_value(1, 42U)),
      ]),
      120,
      line=5U,
    ),
  ])
  let usages = document.resource_references()
  assert_eq(usages.length(), 4)
  assert_eq(usages.map(fn(usage) { usage.offset }), [80, 80, 24, 120])
  assert_eq(usages.map(fn(usage) { usage.line_number }), [3U, 3U, 4U, 5U])
  assert_eq(usages.map(fn(usage) { usage.reference }), [
    @axml.ValueReference::Resource(42U),
    @axml.ValueReference::ThemeAttribute(42U),
    @axml.ValueReference::DynamicResource(42U),
    @axml.ValueReference::Resource(42U),
  ])
  assert_eq(usages.map(fn(usage) { usage.origin }), [
    @axml.ResourceUsageOrigin::Attribute(None, "first"),
    @axml.ResourceUsageOrigin::Attribute(None, "second"),
    @axml.ResourceUsageOrigin::Text,
    @axml.ResourceUsageOrigin::Attribute(None, "third"),
  ])
}

///|
test "resource usage origins preserve exact namespaces and local names" {
  let document = usage_document([
    usage_event(
      @axml.StartElement(Some("urn:default"), "root", [
        usage_attribute("name", usage_value(1, 1U)),
        usage_attribute("name", usage_value(1, 1U), uri=Some("urn:one")),
        usage_attribute("Name", usage_value(1, 1U), uri=Some("urn:two")),
      ]),
      40,
    ),
  ])
  assert_eq(document.resource_references().map(fn(usage) { usage.origin }), [
    @axml.ResourceUsageOrigin::Attribute(None, "name"),
    @axml.ResourceUsageOrigin::Attribute(Some("urn:one"), "name"),
    @axml.ResourceUsageOrigin::Attribute(Some("urn:two"), "Name"),
  ])
}

///|
test "resource usage excludes lookalike strings integers and attribute name IDs" {
  let attributes = []
  for kind in [0, 3, 4, 5, 6, 9, 0x10, 0x11, 0x12, 0x1c, 0x1f] {
    attributes.push(
      usage_attribute(
        "value",
        usage_value(kind, 0x7f010001U, text=Some("@string/app_name")),
        raw=Some("@0x7f010001"),
        name_id=Some(0x7f010001U),
      ),
    )
  }
  let document = usage_document([
    usage_event(@axml.StartElement(None, "root", attributes), 40),
    usage_event(
      @axml.Text("?attr/theme", usage_value(3, 0U, text=Some("?attr/theme"))),
      80,
    ),
    usage_event(@axml.Text("@0x7f010001", usage_value(0x11, 0x7f010001U)), 108),
  ])
  assert_eq(document.resource_references(), [])
}
