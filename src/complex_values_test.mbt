///|
fn complex_value(kind : Int32, data : UInt32) -> @axml.TypedValue {
  { data_type: kind, data, string_value: None, }
}

///|
test "dimension views retain all six units without pixel conversion" {
  for
    (code, unit) in [
      (0U, @axml.Px),
      (1U, @axml.Dip),
      (2U, @axml.Sp),
      (3U, @axml.Pt),
      (4U, @axml.Inch),
      (5U, @axml.Mm),
    ] {
    assert_eq(
      complex_value(5, 0x00001000U | code).as_dimension(),
      Some({ magnitude: 16.0, unit, }),
    )
  }
}

///|
test "complex views interpret all four fixed point radices" {
  for
    (data, magnitude) in [
      (0x00001000U, 16.0),
      (0x0000c010U, 1.5),
      (0x00c00020U, 1.5),
      (0x40000030U, 0.5),
    ] {
    assert_eq(
      complex_value(5, data).as_dimension(),
      Some({ magnitude, unit: @axml.Px, }),
    )
    assert_eq(
      complex_value(6, data).as_fraction(),
      Some({ ratio: magnitude, unit: @axml.Base, }),
    )
  }
}

///|
test "complex signed mantissas preserve negative values and endpoints" {
  for
    (data, magnitude) in [
      (0xfffffe00U, -2.0),
      (0xffff4010U, -1.5),
      (0x7fffff00U, 8388607.0),
      (0x80000000U, -8388608.0),
      (0x00000000U, 0.0),
    ] {
    assert_eq(
      complex_value(5, data).as_dimension(),
      Some({ magnitude, unit: @axml.Px, }),
    )
  }
}

///|
test "fraction views retain ratios and distinguish base from parent" {
  assert_eq(
    complex_value(6, 0x40000030U).as_fraction(),
    Some({ ratio: 0.5, unit: @axml.Base, }),
  )
  assert_eq(
    complex_value(6, 0x40000031U).as_fraction(),
    Some({ ratio: 0.5, unit: @axml.Parent, }),
  )
  assert_eq(complex_value(6, 0x40000030U).text(), "50%")
  assert_eq(complex_value(6, 0x40000031U).text(), "50%p")
}

///|
test "complex views reject invalid units and mismatched types" {
  for unit in 6U..<16U {
    assert_eq(complex_value(5, 0x1000U | unit).as_dimension(), None)
  }
  for unit in 2U..<16U {
    assert_eq(complex_value(6, 0x1000U | unit).as_fraction(), None)
  }
  for kind in [0, 1, 2, 3, 4, 7, 8, 0x10, 0x11, 0x12, 0x1c] {
    assert_eq(complex_value(kind, 0x1000U).as_dimension(), None)
    assert_eq(complex_value(kind, 0x1000U).as_fraction(), None)
  }
  assert_eq(complex_value(5, 0x1000U).as_fraction(), None)
  assert_eq(complex_value(6, 0x1000U).as_dimension(), None)
}

///|
test "reserved complex bits do not affect radix mantissa or unit" {
  assert_eq(
    complex_value(5, 0x0000c0d1U).as_dimension(),
    Some({ magnitude: 1.5, unit: @axml.Dip, }),
  )
}
