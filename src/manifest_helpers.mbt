///|
/// Expand a declared component name relative to an explicit package name.
/// Leading-dot and bare names are prefixed; names containing a dot are kept.
/// This is syntactic expansion, not Java class validation or resource lookup.
/// Empty inputs raise Invalid(-1, message), since no byte offset is available.
pub fn resolve_component_name(
  package_name : String,
  declared_name : String,
) -> String raise DecodeError {
  if package_name.is_empty() {
    raise Invalid(-1, "component package must be nonempty")
  }
  if declared_name.is_empty() {
    raise Invalid(-1, "component name must be nonempty")
  }
  if declared_name.code_unit_at(0) == 46 {
    package_name + declared_name
  } else if !declared_name.contains(".") {
    package_name + "." + declared_name
  } else {
    declared_name
  }
}

///|
fn manifest_helper_literal_name(attribute : Attribute?) -> String? {
  match attribute {
    Some(attribute) if attribute.namespace_uri ==
      Some("http://schemas.android.com/apk/res/android") &&
      attribute.name == "name" &&
      attribute.value.data_type == 3 => attribute.value.string_value
    _ => None
  }
}

///|
/// Expand a literal android:name without changing this component's metadata.
/// Missing, non-string and unresolved resource names return None. Empty literal
/// names raise DecodeError. The package is supplied explicitly by the caller.
pub fn ManifestComponent::qualified_name(
  self : ManifestComponent,
  package_name : String,
) -> String? raise DecodeError {
  match manifest_helper_literal_name(self.name) {
    Some(name) => Some(resolve_component_name(package_name, name))
    None => None
  }
}

///|
/// Select directly declared components by their exact element kind, preserving
/// declaration order. For example, activity does not also select activity-alias.
pub fn Manifest::components_of_kind(
  self : Manifest,
  kind : String,
) -> Array[ManifestComponent] {
  self.components.filter(fn(component) { component.kind == kind })
}

///|
/// Test whether a uses-permission variant requests this literal name.
/// Resource references do not match, even if their raw text resembles a name.
/// This does not evaluate maxSdkVersion or determine runtime permission grants.
pub fn Manifest::requests_permission(self : Manifest, name : String) -> Bool {
  if name.is_empty() {
    return false
  }
  for permission in self.permissions {
    if (
        permission.kind == "uses-permission" ||
        permission.kind == "uses-permission-sdk-23" ||
        permission.kind == "uses-permission-sdk-m"
      ) &&
      manifest_helper_literal_name(permission.name) == Some(name) {
      return true
    }
  }
  false
}
