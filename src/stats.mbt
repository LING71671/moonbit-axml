///|
/// Counts from the stored pools and event stream, without rendering or I/O.
/// Aggregate UTF-16 units and attributes use Int64 for shared manual inputs.
pub(all) struct DocumentStats {
  strings : Int32
  string_utf16_units : Int64
  resource_ids : Int32
  events : Int32
  start_elements : Int32
  attributes : Int64
  text_events : Int32
  namespace_declarations : Int32
  max_depth : Int32
} derive(Eq, @debug.Debug, ToJson)

///|
/// Summarize stored entries in O(strings + events) time and constant space.
/// Repeated pool entries and attribute occurrences are counted separately.
/// This is not validation: manual streams need not be balanced or name-correct.
/// An unmatched end at depth zero is ignored; open starts still affect depth.
pub fn Document::stats(self : Document) -> DocumentStats {
  let mut string_utf16_units = 0L
  for string in self.strings {
    string_utf16_units = string_utf16_units + string.length().to_int64()
  }
  let mut start_elements = 0
  let mut attributes = 0L
  let mut text_events = 0
  let mut namespace_declarations = 0
  let mut depth = 0
  let mut max_depth = 0
  for event in self.events {
    match event.kind {
      StartElement(_, _, values) => {
        start_elements = start_elements + 1
        attributes = attributes + values.length().to_int64()
        depth = depth + 1
        if depth > max_depth {
          max_depth = depth
        }
      }
      EndElement(_, _) => if depth > 0 { depth = depth - 1 }
      Text(_, _) => text_events = text_events + 1
      StartNamespace(_, _) =>
        namespace_declarations = namespace_declarations + 1
      EndNamespace(_, _) => ()
    }
  }
  {
    strings: self.strings.length(),
    string_utf16_units,
    resource_ids: self.resource_ids.length(),
    events: self.events.length(),
    start_elements,
    attributes,
    text_events,
    namespace_declarations,
    max_depth,
  }
}
