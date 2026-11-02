///|
fn render_doc(kinds : Array[@axml.EventKind]) -> @axml.Document {
  {
    strings: [],
    resource_ids: [],
    events: kinds.map(fn(kind) { { offset: 100, line_number: 1U, kind, } }),
  }
}

///|
fn render_string_attribute(
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
fn render_rejected(kinds : Array[@axml.EventKind]) -> Bool {
  try {
    @axml.to_xml(render_doc(kinds)) |> ignore
    false
  } catch {
    @axml.DecodeError::Invalid(_, _) => true
  }
}

///|
test "XML escaping preserves text and normalized attribute whitespace" {
  let document = render_doc([
    @axml.EventKind::StartElement(None, "root", [
      render_string_attribute(None, "value", "<&>\"\n\t\r"),
    ]),
    @axml.EventKind::Text("<&>\r\n\t", {
      data_type: 3,
      data: 0U,
      string_value: Some("<&>\r\n\t"),
    }),
    @axml.EventKind::EndElement(None, "root"),
  ])
  @test.assert_eq(
    @axml.to_xml(document),
    "<root value=\"&lt;&amp;&gt;&quot;&#10;&#9;&#13;\">&lt;&amp;&gt;&#13;\n\t</root>",
  )
}

///|
test "default namespaces never apply to unqualified attributes" {
  let document = render_doc([
    @axml.EventKind::StartNamespace(None, "urn:one"),
    @axml.EventKind::StartElement(Some("urn:one"), "root", [
      render_string_attribute(None, "plain", "p"),
      render_string_attribute(Some("urn:one"), "qualified", "q"),
    ]),
    @axml.EventKind::StartElement(None, "child", []),
    @axml.EventKind::EndElement(None, "child"),
    @axml.EventKind::EndElement(Some("urn:one"), "root"),
    @axml.EventKind::EndNamespace(None, "urn:one"),
  ])
  @test.assert_eq(
    @axml.to_xml(document),
    "<root xmlns=\"urn:one\" xmlns:ns0=\"urn:one\" plain=\"p\" ns0:qualified=\"q\"><child xmlns=\"\"></child></root>",
  )
}

///|
test "prefix shadowing ends at the declaring child" {
  let document = render_doc([
    @axml.EventKind::StartNamespace(Some("p"), "urn:one"),
    @axml.EventKind::StartElement(Some("urn:one"), "root", []),
    @axml.EventKind::StartNamespace(Some("p"), "urn:two"),
    @axml.EventKind::StartElement(Some("urn:two"), "child", []),
    @axml.EventKind::EndElement(Some("urn:two"), "child"),
    @axml.EventKind::EndNamespace(Some("p"), "urn:two"),
    @axml.EventKind::StartElement(Some("urn:one"), "sibling", []),
    @axml.EventKind::EndElement(Some("urn:one"), "sibling"),
    @axml.EventKind::EndElement(Some("urn:one"), "root"),
    @axml.EventKind::EndNamespace(Some("p"), "urn:one"),
  ])
  @test.assert_eq(
    @axml.to_xml(document),
    "<p:root xmlns:p=\"urn:one\"><p:child xmlns:p=\"urn:two\"></p:child><p:sibling></p:sibling></p:root>",
  )
}

///|
test "explicit default namespace undeclaration is scoped" {
  let document = render_doc([
    @axml.EventKind::StartNamespace(None, "urn:one"),
    @axml.EventKind::StartElement(Some("urn:one"), "root", []),
    @axml.EventKind::StartNamespace(None, ""),
    @axml.EventKind::StartElement(None, "child", []),
    @axml.EventKind::EndElement(None, "child"),
    @axml.EventKind::EndNamespace(None, ""),
    @axml.EventKind::EndElement(Some("urn:one"), "root"),
    @axml.EventKind::EndNamespace(None, "urn:one"),
  ])
  @test.assert_eq(
    @axml.to_xml(document),
    "<root xmlns=\"urn:one\"><child xmlns=\"\"></child></root>",
  )
}

///|
test "Android values retain numeric unresolved references" {
  let value : @axml.TypedValue = {
    data_type: 1,
    data: 0x7f010001U,
    string_value: None,
  }
  @test.assert_eq(value.text(), "@0x7f010001")
  let attribute : @axml.Attribute = {
    namespace_uri: None,
    name: "label",
    resource_id: None,
    raw_value: Some("@string/guessed_label"),
    value,
  }
  @test.assert_eq(
    @axml.to_xml(
      render_doc([
        @axml.EventKind::StartElement(None, "root", [attribute]),
        @axml.EventKind::EndElement(None, "root"),
      ]),
    ),
    "<root label=\"@0x7f010001\"></root>",
  )
  let samples : Array[(@axml.TypedValue, String)] = [
    ({ data_type: 0, data: 0U, string_value: None, }, "@null"),
    ({ data_type: 0, data: 1U, string_value: None, }, "@empty"),
    ({ data_type: 2, data: 0x01010001U, string_value: None, }, "?0x01010001"),
    ({ data_type: 0x10, data: 0xffffffffU, string_value: None, }, "-1"),
    ({ data_type: 0x11, data: 0xffU, string_value: None, }, "0xff"),
    ({ data_type: 0x12, data: 0xffffffffU, string_value: None, }, "true"),
    ({ data_type: 0x12, data: 0U, string_value: None, }, "false"),
    ({ data_type: 0x1c, data: 0xff00aa55U, string_value: None, }, "#ff00aa55"),
    ({ data_type: 4, data: 0x3fc00000U, string_value: None, }, "1.5"),
    ({ data_type: 5, data: 0x00003001U, string_value: None, }, "48dip"),
    ({ data_type: 5, data: 0xfffffe01U, string_value: None, }, "-2dip"),
    ({ data_type: 6, data: 0x40000030U, string_value: None, }, "50%"),
    ({ data_type: 6, data: 0x40000031U, string_value: None, }, "50%p"),
  ]
  for sample in samples {
    @test.assert_eq(sample.0.text(), sample.1)
  }
}

///|
test "invalid manually constructed XML events fail instead of emitting broken XML" {
  assert_true(
    render_rejected([
      @axml.EventKind::StartElement(None, "bad:name", []),
      @axml.EventKind::EndElement(None, "bad:name"),
    ]),
  )
  assert_true(
    render_rejected([
      @axml.EventKind::StartElement(None, "root", []),
      @axml.EventKind::EndElement(None, "other"),
    ]),
  )
  assert_true(
    render_rejected([
      @axml.EventKind::StartElement(None, "root", []),
      @axml.EventKind::EndElement(None, "root"),
      @axml.EventKind::StartElement(None, "second", []),
      @axml.EventKind::EndElement(None, "second"),
    ]),
  )
  assert_true(
    render_rejected([
      @axml.EventKind::StartNamespace(Some("xml"), "urn:wrong"),
      @axml.EventKind::StartElement(None, "root", []),
      @axml.EventKind::EndElement(None, "root"),
      @axml.EventKind::EndNamespace(Some("xml"), "urn:wrong"),
    ]),
  )
  assert_true(
    render_rejected([
      @axml.EventKind::StartElement(None, "root", [
        render_string_attribute(None, "bad", "\u0000"),
      ]),
      @axml.EventKind::EndElement(None, "root"),
    ]),
  )
  assert_true(
    render_rejected([
      @axml.EventKind::StartElement(None, "root", [
        render_string_attribute(None, "duplicate", "a"),
        render_string_attribute(None, "duplicate", "b"),
      ]),
      @axml.EventKind::EndElement(None, "root"),
    ]),
  )
  assert_true(
    render_rejected([
      @axml.EventKind::StartNamespace(Some("p"), "urn:one"),
      @axml.EventKind::StartElement(None, "root", []),
      @axml.EventKind::EndElement(None, "root"),
    ]),
  )
  assert_true(render_rejected([@axml.EventKind::EndNamespace(None, "urn:one")]))
}

///|
test "renderer enforces configured output limit" {
  let result = try {
    @axml.to_xml(
      render_doc([
        @axml.EventKind::StartElement(None, "root", []),
        @axml.EventKind::EndElement(None, "root"),
      ]),
      max_output_chars=10,
    )
    |> ignore
    false
  } catch {
    @axml.DecodeError::Invalid(100, _) => true
    _ => false
  }
  assert_true(result)
}

///|
test "many namespace declarations allow arbitrary end order and restore aliases" {
  let kinds : Array[@axml.EventKind] = []
  for index = 0; index < 5000; index = index + 1 {
    kinds.push(
      @axml.EventKind::StartNamespace(
        Some("p" + index.to_string()),
        "urn:" + index.to_string(),
      ),
    )
  }
  kinds.push(@axml.EventKind::StartElement(Some("urn:0"), "root", []))
  kinds.push(@axml.EventKind::StartNamespace(Some("alias"), "urn:0"))
  kinds.push(@axml.EventKind::StartNamespace(Some("p0"), "urn:shadow"))
  kinds.push(
    @axml.EventKind::StartElement(Some("urn:0"), "child", [
      render_string_attribute(Some("urn:shadow"), "value", "kept"),
    ]),
  )
  kinds.push(@axml.EventKind::EndElement(Some("urn:0"), "child"))
  kinds.push(@axml.EventKind::EndNamespace(Some("alias"), "urn:0"))
  kinds.push(@axml.EventKind::EndNamespace(Some("p0"), "urn:shadow"))
  kinds.push(@axml.EventKind::StartElement(Some("urn:0"), "sibling", []))
  kinds.push(@axml.EventKind::EndElement(Some("urn:0"), "sibling"))
  kinds.push(@axml.EventKind::EndElement(Some("urn:0"), "root"))
  for index = 0; index < 5000; index = index + 1 {
    kinds.push(
      @axml.EventKind::EndNamespace(
        Some("p" + index.to_string()),
        "urn:" + index.to_string(),
      ),
    )
  }
  let xml = @axml.to_xml(render_doc(kinds))
  assert_true(
    xml.contains(
      "<alias:child xmlns:alias=\"urn:0\" xmlns:p0=\"urn:shadow\" p0:value=\"kept\"></alias:child>",
    ),
  )
  assert_true(xml.contains("<p0:sibling></p0:sibling></p0:root>"))
}
