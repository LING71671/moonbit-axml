///|
fn render_allocation_document(kinds : Array[@axml.EventKind]) -> @axml.Document {
  {
    strings: [],
    resource_ids: [],
    events: kinds.map(fn(kind) { { offset: 123, line_number: 1U, kind, } }),
  }
}

///|
fn render_allocation_attribute(value : String) -> @axml.Attribute {
  {
    namespace_uri: None,
    name: "value",
    resource_id: None,
    raw_value: Some(value),
    value: { data_type: 3, data: 0U, string_value: Some(value), },
  }
}

///|
fn render_allocation_text(value : String) -> @axml.EventKind {
  @axml.EventKind::Text(value, {
    data_type: 3,
    data: 0U,
    string_value: Some(value),
  })
}

///|
test "long ordinary attribute and text spans remain unchanged" {
  let value = "ordinary ASCII ".repeat(1024)
  let document = render_allocation_document([
    @axml.EventKind::StartElement(None, "root", [
      render_allocation_attribute(value),
    ]),
    render_allocation_text(value),
    @axml.EventKind::EndElement(None, "root"),
  ])
  assert_eq(
    @axml.to_xml(document),
    "<root value=\"" + value + "\">" + value + "</root>",
  )
}

///|
test "escape boundaries retain supplementary UTF16 pairs and complete spans" {
  let document = render_allocation_document([
    @axml.EventKind::StartElement(None, "root", [
      render_allocation_attribute("&𠀀\"middle𠀀\n\t\r>"),
    ]),
    render_allocation_text("<𠀀&𠀀\"\n\t\r>"),
    @axml.EventKind::EndElement(None, "root"),
  ])
  assert_eq(
    @axml.to_xml(document),
    "<root value=\"&amp;𠀀&quot;middle𠀀&#10;&#9;&#13;&gt;\">&lt;𠀀&amp;𠀀\"\n\t&#13;&gt;</root>",
  )
}

///|
test "invalid controls fail inside ordinary spans and after replacements" {
  for value in ["prefix\u0000suffix", "𠀀&\u0001", "prefix\uFFFE"] {
    for
      kind in [
        @axml.EventKind::StartElement(None, "child", [
          render_allocation_attribute(value),
        ]),
        render_allocation_text(value),
      ] {
      let rejected = try {
        @axml.to_xml(
          render_allocation_document([
            @axml.EventKind::StartElement(None, "root", []),
            kind,
          ]),
        )
        |> ignore
        false
      } catch {
        @axml.DecodeError::Invalid(123, "character is forbidden by XML 1.0") =>
          true
        _ => false
      }
      assert_true(rejected)
    }
  }
}

///|
test "repeated pool sized values produce complete sibling XML" {
  let value = "a".repeat(4096)
  let kinds : Array[@axml.EventKind] = [
    @axml.EventKind::StartElement(None, "root", []),
  ]
  for _ in 0..<256 {
    kinds.push(
      @axml.EventKind::StartElement(None, "item", [
        render_allocation_attribute(value),
      ]),
    )
    kinds.push(@axml.EventKind::EndElement(None, "item"))
  }
  kinds.push(@axml.EventKind::EndElement(None, "root"))
  let document = render_allocation_document(kinds)
  let expected = "<root>" +
    ("<item value=\"" + value + "\"></item>").repeat(256) +
    "</root>"
  assert_eq(@axml.to_xml(document), expected)
}

///|
test "output budget counts escaped UTF16 units at exact boundaries" {
  for value in ["plain𠀀", "&𠀀\"\r", ""] {
    let document = render_allocation_document([
      @axml.EventKind::StartElement(None, "root", [
        render_allocation_attribute(value),
      ]),
      render_allocation_text(value),
      @axml.EventKind::EndElement(None, "root"),
    ])
    let expected = @axml.to_xml(document)
    assert_eq(
      @axml.to_xml(document, max_output_chars=expected.length()),
      expected,
    )
    let rejected = try {
      @axml.to_xml(document, max_output_chars=expected.length() - 1) |> ignore
      false
    } catch {
      @axml.DecodeError::Invalid(123, "XML output exceeds configured limit") =>
        true
      _ => false
    }
    assert_true(rejected)
  }
}
