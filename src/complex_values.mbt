///|
/// Encoded dimension units, without applying display or font metrics.
pub(all) enum DimensionUnit {
  Px
  Dip
  Sp
  Pt
  Inch
  Mm
} derive(Eq, @debug.Debug, ToJson)

///|
pub(all) struct Dimension {
  magnitude : Double
  unit : DimensionUnit
} derive(Eq, @debug.Debug, ToJson)

///|
pub(all) enum FractionUnit {
  Base
  Parent
} derive(Eq, @debug.Debug, ToJson)

///|
/// Ratio is the encoded number, so 50% has ratio 0.5.
pub(all) struct Fraction {
  ratio : Double
  unit : FractionUnit
} derive(Eq, @debug.Debug, ToJson)

///|
fn value_complex_magnitude(data : UInt32) -> Double {
  let radix = ((data >> 4) & 3U).reinterpret_as_int()
  (data & 0xffffff00U).reinterpret_as_int().to_double() /
  [256.0, 32768.0, 8388608.0, 2147483648.0][radix]
}

///|
/// Read TYPE_DIMENSION. Wrong types and unknown unit codes return None.
pub fn TypedValue::as_dimension(self : TypedValue) -> Dimension? {
  guard self.data_type == 5 else { return None }
  let unit = match self.data & 15U {
    0U => Px
    1U => Dip
    2U => Sp
    3U => Pt
    4U => Inch
    5U => Mm
    _ => return None
  }
  Some({ magnitude: value_complex_magnitude(self.data), unit, })
}

///|
/// Read TYPE_FRACTION without choosing base or parent dimensions.
pub fn TypedValue::as_fraction(self : TypedValue) -> Fraction? {
  guard self.data_type == 6 else { return None }
  let unit = match self.data & 15U {
    0U => Base
    1U => Parent
    _ => return None
  }
  Some({ ratio: value_complex_magnitude(self.data), unit, })
}
