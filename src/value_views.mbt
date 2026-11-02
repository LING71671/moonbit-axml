///|
/// An unresolved reference distinguishes resources from theme attributes and
/// dynamic package IDs. Numeric IDs are retained without resource-table lookup.
pub(all) enum ValueReference {
  Resource(UInt32)
  ThemeAttribute(UInt32)
  DynamicResource(UInt32)
  DynamicThemeAttribute(UInt32)
} derive(Eq, @debug.Debug, ToJson)

///|
/// Read a string only when its Android type is TYPE_STRING.
pub fn TypedValue::as_string(self : TypedValue) -> String? {
  if self.data_type == 3 {
    self.string_value
  } else {
    None
  }
}

///|
/// Read decimal/hex integer payloads as signed 32-bit Android integers.
/// Booleans, colors and resource IDs retain their own distinct types.
pub fn TypedValue::as_integer(self : TypedValue) -> Int32? {
  if self.data_type == 0x10 || self.data_type == 0x11 {
    Some(self.data.reinterpret_as_int())
  } else {
    None
  }
}

///|
/// Android booleans use zero for false and any nonzero payload for true.
pub fn TypedValue::as_boolean(self : TypedValue) -> Bool? {
  if self.data_type == 0x12 {
    Some(self.data != 0U)
  } else {
    None
  }
}

///|
/// Interpret the original IEEE-754 payload without coercing other types.
/// Non-finite values are retained here; XML rendering rejects them.
pub fn TypedValue::as_float(self : TypedValue) -> Float? {
  if self.data_type == 4 {
    Some(Float::reinterpret_from_uint(self.data))
  } else {
    None
  }
}

///|
/// Inspect a resource/theme reference while preserving dynamic-reference kinds.
pub fn TypedValue::reference(self : TypedValue) -> ValueReference? {
  match self.data_type {
    1 => Some(Resource(self.data))
    2 => Some(ThemeAttribute(self.data))
    7 => Some(DynamicResource(self.data))
    8 => Some(DynamicThemeAttribute(self.data))
    _ => None
  }
}
