///|
/// The attribute or text origin of a typed resource or theme reference.
/// Attribute names retain their original namespace URI and local name.
pub(all) enum ResourceUsageOrigin {
  Attribute(String?, String)
  Text
} derive(Eq, @debug.Debug, ToJson)

///|
/// One unresolved typed reference, preserving its kind, ID and source location.
/// Repeated references remain separate records in document order.
pub(all) struct ResourceUsage {
  offset : Int32
  line_number : UInt32
  origin : ResourceUsageOrigin
  reference : ValueReference
} derive(Eq, @debug.Debug, ToJson)

///|
/// Collect typed attribute and text references in event/attribute order.
/// This does not interpret raw strings, resolve ARSC, or validate a manually
/// constructed document. Attribute-name resource IDs are not value usages.
pub fn Document::resource_references(self : Document) -> Array[ResourceUsage] {
  let references : Array[ResourceUsage] = []
  for event in self.events {
    match event.kind {
      StartElement(_, _, attributes) =>
        for attribute in attributes {
          if attribute.value.reference() is Some(reference) {
            references.push({
              offset: event.offset,
              line_number: event.line_number,
              origin: ResourceUsageOrigin::Attribute(
                attribute.namespace_uri,
                attribute.name,
              ),
              reference,
            })
          }
        }
      Text(_, value) =>
        if value.reference() is Some(reference) {
          references.push({
            offset: event.offset,
            line_number: event.line_number,
            origin: ResourceUsageOrigin::Text,
            reference,
          })
        }
      _ => ()
    }
  }
  references
}
