///|
fn pretty_doc(kinds : Array[@axml.EventKind]) -> @axml.Document {
  let events : Array[@axml.Event] = []
  for index = 0; index < kinds.length(); index = index + 1 {
    events.push({ offset: 100 + index, line_number: 1U, kind: kinds[index], })
  }
  { strings: [], resource_ids: [], events, }
}

///|
fn pretty_text(text : String) -> @axml.EventKind {
  @axml.EventKind::Text(text, {
    data_type: 3,
    data: 0U,
    string_value: Some(text),
  })
}

///|
fn pretty_attribute(
  uri : String?,
  name : String,
  text : String,
) -> @axml.Attribute {
  {
    namespace_uri: uri,
    name,
    resource_id: None,
    raw_value: Some(text),
    value: { data_type: 3, data: 0U, string_value: Some(text), },
  }
}

///|
test "pretty XML indents nested elements while keeping empty elements explicit" {
  let document = pretty_doc([
    @axml.EventKind::StartElement(None, "root", []),
    @axml.EventKind::StartElement(None, "branch", []),
    @axml.EventKind::StartElement(None, "leaf", []),
    @axml.EventKind::EndElement(None, "leaf"),
    @axml.EventKind::EndElement(None, "branch"),
    @axml.EventKind::StartElement(None, "empty", []),
    @axml.EventKind::EndElement(None, "empty"),
    @axml.EventKind::EndElement(None, "root"),
  ])
  @test.assert_eq(
    @axml.to_xml_pretty(document),
    "<root>\n  <branch>\n    <leaf></leaf>\n  </branch>\n  <empty></empty>\n</root>",
  )
  @test.assert_eq(
    @axml.to_xml(document),
    "<root><branch><leaf></leaf></branch><empty></empty></root>",
  )
  @test.assert_eq(
    @axml.to_xml_pretty(
      pretty_doc([
        @axml.EventKind::StartElement(None, "empty", []),
        @axml.EventKind::EndElement(None, "empty"),
      ]),
    ),
    "<empty></empty>",
  )
}

///|
test "pretty XML preserves mixed text subtrees even when text follows children" {
  let kinds = [
    @axml.EventKind::StartElement(None, "mixed", []),
    @axml.EventKind::StartElement(None, "nested", []),
    @axml.EventKind::StartElement(None, "leaf", []),
    @axml.EventKind::EndElement(None, "leaf"),
    @axml.EventKind::EndElement(None, "nested"),
    pretty_text(" trailing & <text>"),
    @axml.EventKind::EndElement(None, "mixed"),
  ]
  let mixed = pretty_doc(kinds)
  @test.assert_eq(@axml.to_xml_pretty(mixed), @axml.to_xml(mixed))
  let outer = [@axml.EventKind::StartElement(None, "root", [])]
  for kind in kinds {
    outer.push(kind)
  }
  outer.push(@axml.EventKind::EndElement(None, "root"))
  @test.assert_eq(
    @axml.to_xml_pretty(pretty_doc(outer)),
    "<root>\n  " + @axml.to_xml(mixed) + "\n</root>",
  )
}

///|
test "pretty XML treats empty whitespace and split text events as content" {
  for text in ["", " \n\t", "before"] {
    let document = pretty_doc([
      @axml.EventKind::StartElement(None, "root", []),
      pretty_text(text),
      @axml.EventKind::StartElement(None, "child", []),
      @axml.EventKind::EndElement(None, "child"),
      pretty_text("after"),
      @axml.EventKind::EndElement(None, "root"),
    ])
    @test.assert_eq(@axml.to_xml_pretty(document), @axml.to_xml(document))
  }
}

///|
test "pretty XML preserves pure text escaping and supplementary Unicode" {
  let document = pretty_doc([
    @axml.EventKind::StartElement(None, "root", []),
    @axml.EventKind::StartElement(None, "𐐀", [
      pretty_attribute(None, "value", "𐐁<&>\"\n\t\r"),
    ]),
    pretty_text("𐐂<&>\r\n\t"),
    @axml.EventKind::EndElement(None, "𐐀"),
    @axml.EventKind::EndElement(None, "root"),
  ])
  let expected = "<root>\n  <𐐀 value=\"𐐁&lt;&amp;&gt;&quot;&#10;&#9;&#13;\">𐐂&lt;&amp;&gt;&#13;\n\t</𐐀>\n</root>"
  @test.assert_eq(@axml.to_xml_pretty(document), expected)
  @test.assert_eq(
    @axml.to_xml_pretty(document, max_output_chars=expected.length()),
    expected,
  )
}

///|
test "pretty XML preserves default namespace resets and qualified attributes" {
  let document = pretty_doc([
    @axml.EventKind::StartNamespace(None, "urn:one"),
    @axml.EventKind::StartElement(Some("urn:one"), "root", [
      pretty_attribute(None, "plain", "p"),
      pretty_attribute(Some("urn:one"), "qualified", "q"),
    ]),
    @axml.EventKind::StartElement(None, "child", []),
    @axml.EventKind::EndElement(None, "child"),
    @axml.EventKind::EndElement(Some("urn:one"), "root"),
    @axml.EventKind::EndNamespace(None, "urn:one"),
  ])
  @test.assert_eq(
    @axml.to_xml_pretty(document),
    "<root xmlns=\"urn:one\" xmlns:ns0=\"urn:one\" plain=\"p\" ns0:qualified=\"q\">\n  <child xmlns=\"\"></child>\n</root>",
  )
}

///|
test "pretty XML keeps namespace shadowing and arbitrary scope end order" {
  let document = pretty_doc([
    @axml.EventKind::StartNamespace(Some("p"), "urn:one"),
    @axml.EventKind::StartElement(Some("urn:one"), "root", []),
    @axml.EventKind::StartNamespace(Some("p"), "urn:two"),
    @axml.EventKind::StartNamespace(Some("q"), "urn:three"),
    @axml.EventKind::StartElement(Some("urn:two"), "child", []),
    @axml.EventKind::EndElement(Some("urn:two"), "child"),
    @axml.EventKind::EndNamespace(Some("p"), "urn:two"),
    @axml.EventKind::EndNamespace(Some("q"), "urn:three"),
    @axml.EventKind::StartElement(Some("urn:one"), "sibling", []),
    @axml.EventKind::EndElement(Some("urn:one"), "sibling"),
    @axml.EventKind::EndElement(Some("urn:one"), "root"),
    @axml.EventKind::EndNamespace(Some("p"), "urn:one"),
  ])
  @test.assert_eq(
    @axml.to_xml_pretty(document),
    "<p:root xmlns:p=\"urn:one\">\n  <p:child xmlns:p=\"urn:two\" xmlns:q=\"urn:three\"></p:child>\n  <p:sibling></p:sibling>\n</p:root>",
  )
}

///|
test "pretty XML conservatively preserves xml space subtrees" {
  let document = pretty_doc([
    @axml.EventKind::StartElement(None, "root", []),
    @axml.EventKind::StartElement(None, "preserved", [
      pretty_attribute(
        Some("http://www.w3.org/XML/1998/namespace"),
        "space",
        "preserve",
      ),
    ]),
    @axml.EventKind::StartElement(None, "nested", [
      pretty_attribute(
        Some("http://www.w3.org/XML/1998/namespace"),
        "space",
        "default",
      ),
    ]),
    @axml.EventKind::StartElement(None, "leaf", []),
    @axml.EventKind::EndElement(None, "leaf"),
    @axml.EventKind::EndElement(None, "nested"),
    @axml.EventKind::EndElement(None, "preserved"),
    @axml.EventKind::EndElement(None, "root"),
  ])
  @test.assert_eq(
    @axml.to_xml_pretty(document),
    "<root>\n  <preserved xml:space=\"preserve\"><nested xml:space=\"default\"><leaf></leaf></nested></preserved>\n</root>",
  )
}

///|
test "pretty XML output budget includes every indentation unit" {
  let document = pretty_doc([
    @axml.EventKind::StartElement(None, "root", []),
    @axml.EventKind::StartElement(None, "child", []),
    @axml.EventKind::EndElement(None, "child"),
    @axml.EventKind::EndElement(None, "root"),
  ])
  let expected = "<root>\n  <child></child>\n</root>"
  @test.assert_eq(
    @axml.to_xml_pretty(document, max_output_chars=expected.length()),
    expected,
  )
  let rejected = try {
    @axml.to_xml_pretty(document, max_output_chars=expected.length() - 1)
    |> ignore
    false
  } catch {
    @axml.DecodeError::Invalid(103, _) => true
    _ => false
  }
  assert_true(rejected)
  // Compact output still fits its own exact budget.
  let compact = @axml.to_xml(document)
  @test.assert_eq(
    @axml.to_xml(document, max_output_chars=compact.length()),
    compact,
  )
}

///|
test "pretty XML rejects indentation before expanding beyond output budget" {
  let document = pretty_doc([
    @axml.EventKind::StartElement(None, "r", []),
    @axml.EventKind::StartElement(None, "c", []),
    @axml.EventKind::EndElement(None, "c"),
    @axml.EventKind::EndElement(None, "r"),
  ])
  for limit in [3, 4, 5] {
    let rejected = try {
      @axml.to_xml_pretty(document, max_output_chars=limit) |> ignore
      false
    } catch {
      @axml.DecodeError::Invalid(101, _) => true
      _ => false
    }
    assert_true(rejected)
  }
}

///|
test "pretty XML depth limit applies to constructed and text suppressed trees" {
  let document = pretty_doc([
    @axml.EventKind::StartElement(None, "root", []),
    pretty_text(""),
    @axml.EventKind::StartElement(None, "child", []),
    @axml.EventKind::EndElement(None, "child"),
    @axml.EventKind::EndElement(None, "root"),
  ])
  let rejected = try {
    @axml.to_xml_pretty(document, max_depth=1) |> ignore
    false
  } catch {
    @axml.DecodeError::Invalid(102, _) => true
    _ => false
  }
  assert_true(rejected)
  @test.assert_eq(
    @axml.to_xml_pretty(document, max_depth=2),
    @axml.to_xml(document),
  )
  let invalid_depth = try {
    @axml.to_xml_pretty(document, max_depth=0) |> ignore
    false
  } catch {
    @axml.DecodeError::Invalid(0, _) => true
    _ => false
  }
  assert_true(invalid_depth)
  let invalid_output = try {
    @axml.to_xml_pretty(document, max_output_chars=0) |> ignore
    false
  } catch {
    @axml.DecodeError::Invalid(0, _) => true
    _ => false
  }
  assert_true(invalid_output)
}

///|
test "pretty XML retains invalid structure and forbidden character diagnostics" {
  let documents = [
    pretty_doc([
      @axml.EventKind::StartElement(None, "root", []),
      @axml.EventKind::EndElement(None, "other"),
    ]),
    pretty_doc([
      @axml.EventKind::StartElement(None, "root", []),
      pretty_text("\u0000"),
      @axml.EventKind::EndElement(None, "root"),
    ]),
    pretty_doc([
      @axml.EventKind::StartNamespace(Some("p"), "urn:one"),
      @axml.EventKind::StartElement(None, "root", []),
      @axml.EventKind::EndElement(None, "root"),
    ]),
  ]
  for document in documents {
    let rejected = try {
      @axml.to_xml_pretty(document) |> ignore
      false
    } catch {
      @axml.DecodeError::Invalid(_, _) => true
    }
    assert_true(rejected)
  }
}

///|
test "pretty XML default depth is bounded and explicit larger limits work" {
  let kinds : Array[@axml.EventKind] = []
  for index = 0; index < 257; index = index + 1 {
    kinds.push(@axml.EventKind::StartElement(None, "n", []))
  }
  for index = 0; index < 257; index = index + 1 {
    kinds.push(@axml.EventKind::EndElement(None, "n"))
  }
  let document = pretty_doc(kinds)
  let rejected = try {
    @axml.to_xml_pretty(document) |> ignore
    false
  } catch {
    @axml.DecodeError::Invalid(356, _) => true
    _ => false
  }
  assert_true(rejected)
  let pretty = @axml.to_xml_pretty(document, max_depth=257)
  assert_true(pretty.contains("\n  <n>"))
  assert_true(pretty.length() > @axml.to_xml(document).length())
}
