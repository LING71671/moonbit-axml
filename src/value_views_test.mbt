///|
fn value_view(
  kind : Int32,
  data : UInt32,
  text~ : String? = None,
) -> @axml.TypedValue {
  { data_type: kind, data, string_value: text, }
}

///|
test "typed string views do not coerce raw numeric payloads" {
  assert_eq(
    value_view(3, 9U, text=Some("literal")).as_string(),
    Some("literal"),
  )
  assert_eq(value_view(3, 9U).as_string(), None)
  assert_eq(value_view(0x10, 9U, text=Some("literal")).as_string(), None)
  assert_eq(value_view(3, 9U, text=Some("42")).as_integer(), None)
}

///|
test "integer views preserve signed bit patterns and reject other families" {
  assert_eq(value_view(0x10, 0xffffffffU).as_integer(), Some(-1))
  assert_eq(value_view(0x11, 0x80000000U).as_integer(), Some(-2147483648))
  assert_eq(value_view(0x10, 2147483647U).as_integer(), Some(2147483647))
  for kind in [0, 1, 2, 3, 4, 5, 6, 7, 8, 0x12, 0x1c] {
    assert_eq(value_view(kind, 1U).as_integer(), None)
  }
}

///|
test "boolean view requires the boolean type and preserves Android nonzero semantics" {
  assert_eq(value_view(0x12, 0U).as_boolean(), Some(false))
  assert_eq(value_view(0x12, 1U).as_boolean(), Some(true))
  assert_eq(value_view(0x12, 0xffffffffU).as_boolean(), Some(true))
  assert_eq(value_view(0x10, 1U).as_boolean(), None)
  assert_eq(value_view(3, 0U, text=Some("true")).as_boolean(), None)
}

///|
test "reference views distinguish static dynamic resources and theme attributes" {
  for
    (kind, expected) in [
      (1, @axml.ValueReference::Resource(0x7f010001U)),
      (2, @axml.ValueReference::ThemeAttribute(0x7f010001U)),
      (7, @axml.ValueReference::DynamicResource(0x7f010001U)),
      (8, @axml.ValueReference::DynamicThemeAttribute(0x7f010001U)),
    ] {
    assert_eq(value_view(kind, 0x7f010001U).reference(), Some(expected))
  }
  assert_eq(value_view(0x11, 0x7f010001U).reference(), None)
  assert_eq(value_view(3, 0U, text=Some("@string/name")).reference(), None)
}

///|
test "float views preserve finite and non-finite IEEE754 values" {
  assert_eq(value_view(4, 0x3fc00000U).as_float(), Some(1.5F))
  guard value_view(4, 0x7fc00000U).as_float() is Some(nan) else {
    fail("missing NaN payload")
  }
  assert_true(nan.is_nan())
  guard value_view(4, 0x7f800000U).as_float() is Some(infinite) else {
    fail("missing infinity payload")
  }
  assert_true(infinite.is_inf())
  assert_eq(value_view(0x10, 0x3fc00000U).as_float(), None)
}
