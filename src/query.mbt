///|
fn query_uri(uri : String?) -> String? {
  match uri {
    Some("") => None
    _ => uri
  }
}

///|
/// Find a start-element attribute by expanded name. An empty namespace URI
/// means no namespace. Namespace prefix spellings are not part of the lookup.
pub fn Event::attribute(
  self : Event,
  namespace_uri : String?,
  name : String,
) -> Attribute? {
  match self.kind {
    StartElement(_, _, attributes) => {
      for attribute in attributes {
        if query_uri(attribute.namespace_uri) == query_uri(namespace_uri) &&
          attribute.name == name {
          return Some(attribute)
        }
      }
      None
    }
    _ => None
  }
}

///|
/// Return the first start-element event, or None if there is no element.
/// This query does not validate a manually constructed event stream.
pub fn Document::root(self : Document) -> Event? {
  for event in self.events {
    match event.kind {
      StartElement(_, _, _) => return Some(event)
      _ => ()
    }
  }
  None
}

///|
/// Select start elements by their exact expanded name in document order.
/// Returned events share their existing attribute arrays with the document.
pub fn Document::elements(
  self : Document,
  namespace_uri : String?,
  name : String,
) -> Array[Event] {
  self.events.filter(fn(event) {
    match event.kind {
      StartElement(uri, local_name, _) =>
        query_uri(uri) == query_uri(namespace_uri) && local_name == name
      _ => false
    }
  })
}
