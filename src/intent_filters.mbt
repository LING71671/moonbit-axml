///|
/// A directly declared intent filter. All attributes retain raw and typed
/// values, and no component defaults or intent matching rules are inferred.
pub(all) struct ManifestIntentFilter {
  component_kind : String
  component_name : Attribute?
  offset : Int32
  line_number : UInt32
  attributes : Array[Attribute]
  actions : Array[Attribute]
  categories : Array[Attribute]
  data : Array[Array[Attribute]]
} derive(Eq, @debug.Debug, ToJson)

///|
fn intent_filter_has_name(attributes : Array[Attribute], name : String) -> Bool {
  if name == "" {
    return false
  }
  for attribute in attributes {
    if attribute.namespace_uri ==
      Some("http://schemas.android.com/apk/res/android") &&
      attribute.name == "name" &&
      attribute.value.data_type == 3 &&
      attribute.value.string_value == Some(name) {
      return true
    }
  }
  false
}

///|
/// Match an exact literal android:name declaration. References do not match.
pub fn ManifestIntentFilter::has_action(
  self : ManifestIntentFilter,
  name : String,
) -> Bool {
  intent_filter_has_name(self.actions, name)
}

///|
/// Match an exact literal android:name declaration. References do not match.
pub fn ManifestIntentFilter::has_category(
  self : ManifestIntentFilter,
  name : String,
) -> Bool {
  intent_filter_has_name(self.categories, name)
}

///|
/// Inspect direct intent-filter children of unqualified activity, activity-alias,
/// service and receiver declarations under manifest/application. Missing action
/// and category names are omitted; data declarations retain all attributes.
pub fn inspect_intent_filters(
  document : Document,
) -> Array[ManifestIntentFilter] raise DecodeError {
  inspect_manifest(document) |> ignore
  let path : Array[String] = []
  let filters : Array[ManifestIntentFilter] = []
  let mut component : (String, Attribute?)? = None
  let mut current_filter : ManifestIntentFilter? = None
  for event in document.events {
    match event.kind {
      StartElement(uri, name, attributes) => {
        let unqualified = render_normal_uri(uri) == None
        if unqualified && path.length() == 2 && path[1] == "application" {
          match name {
            "activity" | "activity-alias" | "service" | "receiver" =>
              component = Some((name, manifest_attribute(attributes, "name")))
            _ => ()
          }
        } else if unqualified && path.length() == 3 && name == "intent-filter" {
          match component {
            Some((component_kind, component_name)) => {
              let filter : ManifestIntentFilter = {
                component_kind,
                component_name,
                offset: event.offset,
                line_number: event.line_number,
                attributes,
                actions: [],
                categories: [],
                data: [],
              }
              filters.push(filter)
              current_filter = Some(filter)
            }
            None => ()
          }
        } else if unqualified && path.length() == 4 {
          match current_filter {
            Some(filter) =>
              match name {
                "action" =>
                  match manifest_attribute(attributes, "name") {
                    Some(attribute) => filter.actions.push(attribute)
                    None => ()
                  }
                "category" =>
                  match manifest_attribute(attributes, "name") {
                    Some(attribute) => filter.categories.push(attribute)
                    None => ()
                  }
                "data" => filter.data.push(attributes)
                _ => ()
              }
            None => ()
          }
        }
        path.push(if unqualified { name } else { "" })
      }
      EndElement(_, _) => {
        if path.length() == 4 {
          current_filter = None
        } else if path.length() == 3 {
          component = None
        }
        path.pop() |> ignore
      }
      _ => ()
    }
  }
  filters
}
