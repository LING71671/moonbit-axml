///|
/// Android's Res_value, preserving the exact type code and 32-bit payload.
/// String values additionally contain the decoded string-pool entry.
pub(all) struct TypedValue {
  data_type : Int32
  data : UInt32
  string_value : String?
} derive(Eq, @debug.Debug, ToJson)

///|
/// An attribute retains its expanded name, original string and typed value.
pub(all) struct Attribute {
  namespace_uri : String?
  name : String
  resource_id : UInt32?
  raw_value : String?
  value : TypedValue
} derive(Eq, @debug.Debug, ToJson)

///|
/// Namespace-aware XML events in input order.
pub(all) enum EventKind {
  StartNamespace(String?, String)
  EndNamespace(String?, String)
  StartElement(String?, String, Array[Attribute])
  EndElement(String?, String)
  Text(String, TypedValue)
} derive(Eq, @debug.Debug, ToJson)

///|
/// Each event identifies its original chunk offset and source line number.
pub(all) struct Event {
  offset : Int32
  line_number : UInt32
  kind : EventKind
} derive(Eq, @debug.Debug, ToJson)

///|
/// Decoded pools and events. Unresolved resources remain numeric IDs.
pub(all) struct Document {
  strings : Array[String]
  resource_ids : Array[UInt32]
  events : Array[Event]
} derive(Eq, @debug.Debug, ToJson)

///|
/// A structural or encoding failure, with its original byte offset.
pub suberror DecodeError {
  Invalid(Int32, String)
} derive(@debug.Debug, ToJson)

///|
/// Resource limits checked before allocation or event expansion.
/// max_string_units caps aggregate decoded UTF-16 units across the pool.
pub(all) struct Limits {
  max_input_bytes : Int32
  max_strings : Int32
  max_depth : Int32
  max_events : Int32
  max_attributes : Int32
  max_string_units : Int32
} derive(Eq, @debug.Debug, ToJson)

///|
/// Conservative defaults for untrusted, extracted binary XML files.
pub fn Limits::default() -> Limits {
  {
    max_input_bytes: 16 * 1024 * 1024,
    max_strings: 100000,
    max_depth: 256,
    max_events: 500000,
    max_attributes: 65535,
    max_string_units: 4 * 1024 * 1024,
  }
}
