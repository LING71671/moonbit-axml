///|
/// A declared SDK requirement. Values may be integer levels, codenames or
/// unresolved resources; no platform defaults are inferred.
pub(all) struct ManifestSdk {
  min_sdk : Attribute?
  target_sdk : Attribute?
  max_sdk : Attribute?
} derive(Eq, @debug.Debug, ToJson)

///|
/// A uses-permission declaration, retaining all original attributes.
pub(all) struct ManifestPermission {
  kind : String
  name : Attribute?
  max_sdk : Attribute?
  attributes : Array[Attribute]
} derive(Eq, @debug.Debug, ToJson)

///|
/// Declared application attributes. Absent fields remain absent.
pub(all) struct ManifestApplication {
  name : Attribute?
  label : Attribute?
  debuggable : Attribute?
  enabled : Attribute?
  attributes : Array[Attribute]
} derive(Eq, @debug.Debug, ToJson)

///|
/// An activity, alias, service, receiver or provider declared directly in
/// application. Names and exported/enabled state are not expanded or inferred.
pub(all) struct ManifestComponent {
  kind : String
  name : Attribute?
  exported : Attribute?
  enabled : Attribute?
  authorities : Attribute?
  permission : Attribute?
  attributes : Array[Attribute]
} derive(Eq, @debug.Debug, ToJson)

///|
/// Manifest metadata preserves raw and typed values through Attribute.
pub(all) struct Manifest {
  package_name : String
  version_code : Attribute?
  version_code_major : Attribute?
  version_name : Attribute?
  sdk : ManifestSdk?
  permissions : Array[ManifestPermission]
  application : ManifestApplication?
  components : Array[ManifestComponent]
} derive(Eq, @debug.Debug, ToJson)

///|
fn manifest_attribute(
  attributes : Array[Attribute],
  name : String,
) -> Attribute? {
  for attribute in attributes {
    if attribute.namespace_uri ==
      Some("http://schemas.android.com/apk/res/android") &&
      attribute.name == name {
      return Some(attribute)
    }
  }
  None
}

///|
/// Read declarations from an AndroidManifest event stream. The root package
/// must be a literal string. Android defaults and resource resolution require
/// external context and are deliberately not guessed.
pub fn inspect_manifest(document : Document) -> Manifest raise DecodeError {
  // This also validates manually constructed documents and namespace/name
  // legality instead of relying only on the binary decoder's checks.
  to_xml(document) |> ignore
  let path : Array[String] = []
  let mut package_name : String? = None
  let mut version_code : Attribute? = None
  let mut version_code_major : Attribute? = None
  let mut version_name : Attribute? = None
  let mut sdk : ManifestSdk? = None
  let permissions : Array[ManifestPermission] = []
  let mut application : ManifestApplication? = None
  let components : Array[ManifestComponent] = []
  for event in document.events {
    match event.kind {
      StartElement(uri, name, attributes) => {
        let unqualified = render_normal_uri(uri) == None
        if path.is_empty() {
          if !unqualified || name != "manifest" {
            raise Invalid(
              event.offset,
              "manifest inspection requires an unqualified manifest root",
            )
          }
          for attribute in attributes {
            if render_normal_uri(attribute.namespace_uri) == None &&
              attribute.name == "package" {
              if attribute.value.data_type != 3 {
                raise Invalid(
                  event.offset,
                  "manifest package must be a literal string",
                )
              }
              match attribute.value.string_value {
                Some(value) if value != "" => package_name = Some(value)
                _ =>
                  raise Invalid(
                    event.offset,
                    "manifest package must be a nonempty literal string",
                  )
              }
            }
          }
          if package_name == None {
            raise Invalid(event.offset, "manifest has no package attribute")
          }
          version_code = manifest_attribute(attributes, "versionCode")
          version_code_major = manifest_attribute(
            attributes, "versionCodeMajor",
          )
          version_name = manifest_attribute(attributes, "versionName")
        } else if unqualified && path.length() == 1 {
          match name {
            "uses-sdk" => {
              if sdk != None {
                raise Invalid(event.offset, "duplicate uses-sdk declaration")
              }
              sdk = Some({
                min_sdk: manifest_attribute(attributes, "minSdkVersion"),
                target_sdk: manifest_attribute(attributes, "targetSdkVersion"),
                max_sdk: manifest_attribute(attributes, "maxSdkVersion"),
              })
            }
            "uses-permission"
            | "uses-permission-sdk-23"
            | "uses-permission-sdk-m" =>
              permissions.push({
                kind: name,
                name: manifest_attribute(attributes, "name"),
                max_sdk: manifest_attribute(attributes, "maxSdkVersion"),
                attributes,
              })
            "application" => {
              if application != None {
                raise Invalid(event.offset, "duplicate application declaration")
              }
              application = Some({
                name: manifest_attribute(attributes, "name"),
                label: manifest_attribute(attributes, "label"),
                debuggable: manifest_attribute(attributes, "debuggable"),
                enabled: manifest_attribute(attributes, "enabled"),
                attributes,
              })
            }
            _ => ()
          }
        } else if unqualified && path.length() == 2 && path[1] == "application" {
          match name {
            "activity"
            | "activity-alias"
            | "service"
            | "receiver"
            | "provider" =>
              components.push({
                kind: name,
                name: manifest_attribute(attributes, "name"),
                exported: manifest_attribute(attributes, "exported"),
                enabled: manifest_attribute(attributes, "enabled"),
                authorities: manifest_attribute(attributes, "authorities"),
                permission: manifest_attribute(attributes, "permission"),
                attributes,
              })
            _ => ()
          }
        }
        // Namespace-qualified extensions cannot masquerade as application.
        path.push(if unqualified { name } else { "" })
      }
      EndElement(_, _) => path.pop() |> ignore
      _ => ()
    }
  }
  match package_name {
    Some(package_name) =>
      {
        package_name,
        version_code,
        version_code_major,
        version_name,
        sdk,
        permissions,
        application,
        components,
      }
    None => raise Invalid(0, "manifest has no package attribute")
  }
}
