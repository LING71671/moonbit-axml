///|
fn helper_literal_name(name : String) -> @axml.Attribute {
  {
    namespace_uri: Some("http://schemas.android.com/apk/res/android"),
    name: "name",
    resource_id: None,
    raw_value: Some(name),
    value: { data_type: 3, data: 0U, string_value: Some(name), },
  }
}

///|
fn helper_component(
  kind : String,
  name : @axml.Attribute?,
) -> @axml.ManifestComponent {
  {
    kind,
    name,
    exported: None,
    enabled: None,
    authorities: None,
    permission: None,
    attributes: [],
  }
}

///|
fn helper_manifest(
  components : Array[@axml.ManifestComponent],
  permissions : Array[@axml.ManifestPermission],
) -> @axml.Manifest {
  {
    package_name: "example.app",
    version_code: None,
    version_code_major: None,
    version_name: None,
    sdk: None,
    application: None,
    components,
    permissions,
  }
}

///|
fn helper_permission(
  kind : String,
  name : @axml.Attribute?,
) -> @axml.ManifestPermission {
  { kind, name, max_sdk: None, attributes: [], }
}

///|
test "manifest helpers expand relative bare and fully qualified names" {
  let examples = [
    (".MainActivity", "example.app.MainActivity"),
    (".ui.MainActivity", "example.app.ui.MainActivity"),
    ("MainActivity", "example.app.MainActivity"),
    ("MainActivity$Nested", "example.app.MainActivity$Nested"),
    ("other.app.MainActivity", "other.app.MainActivity"),
  ]
  for example in examples {
    @test.assert_eq(
      @axml.resolve_component_name("example.app", example.0),
      example.1,
    )
  }
}

///|
test "manifest helpers reject empty names with no synthetic byte offset" {
  for inputs in [("", ".MainActivity"), ("example.app", "")] {
    let offset = try {
      @axml.resolve_component_name(inputs.0, inputs.1) |> ignore
      Some(0)
    } catch {
      @axml.DecodeError::Invalid(offset, _) => Some(offset)
    }
    @test.assert_eq(offset, Some(-1))
  }
  let empty = helper_component("activity", Some(helper_literal_name("")))
  let rejected = try {
    empty.qualified_name("example.app") |> ignore
    false
  } catch {
    @axml.DecodeError::Invalid(-1, _) => true
    _ => false
  }
  assert_true(rejected)
}

///|
test "manifest helpers preserve raw component names after opt in expansion" {
  let attribute = helper_literal_name(".MainActivity")
  let component = helper_component("activity", Some(attribute))
  @test.assert_eq(
    component.qualified_name("example.app"),
    Some("example.app.MainActivity"),
  )
  @test.assert_eq(component.name, Some(attribute))
  @test.assert_eq(component.exported, None)
  @test.assert_eq(component.enabled, None)
}

///|
test "manifest helpers never infer unresolved or non string component names" {
  let reference : @axml.Attribute = {
    namespace_uri: Some("http://schemas.android.com/apk/res/android"),
    name: "name",
    resource_id: None,
    raw_value: Some(".ApparentName"),
    value: { data_type: 1, data: 0x7f010000U, string_value: None, },
  }
  let non_string : @axml.Attribute = {
    ..reference,
    value: { data_type: 0x10, data: 42U, string_value: Some(".NotAString"), },
  }
  for attribute in [None, Some(reference), Some(non_string)] {
    @test.assert_eq(
      helper_component("activity", attribute).qualified_name("example.app"),
      None,
    )
  }
}

///|
test "manifest helpers filter exact component kind in declaration order" {
  let first = helper_component("activity", Some(helper_literal_name(".First")))
  let activity_alias = helper_component(
    "activity-alias",
    Some(helper_literal_name(".Alias")),
  )
  let second = helper_component(
    "activity",
    Some(helper_literal_name(".Second")),
  )
  let manifest = helper_manifest([first, activity_alias, second], [])
  @test.assert_eq(manifest.components_of_kind("activity"), [first, second])
  @test.assert_eq(manifest.components_of_kind("activity-alias"), [
    activity_alias,
  ])
  @test.assert_eq(manifest.components_of_kind("unknown"), [])
  @test.assert_eq(manifest.components.length(), 3)
}

///|
test "manifest helpers recognize literal permission request variants" {
  for
    kind in [
      "uses-permission", "uses-permission-sdk-23", "uses-permission-sdk-m",
    ] {
    let permission : @axml.ManifestPermission = {
      ..helper_permission(
        kind,
        Some(helper_literal_name("android.permission.CAMERA")),
      ),
      max_sdk: Some({ ..helper_literal_name("21"), name: "maxSdkVersion", }),
    }
    let manifest = helper_manifest([], [permission])
    assert_true(manifest.requests_permission("android.permission.CAMERA"))
    assert_false(manifest.requests_permission("android.permission.camera"))
    assert_false(manifest.requests_permission(""))
  }
  let reference : @axml.Attribute = {
    ..helper_literal_name("android.permission.CAMERA"),
    value: { data_type: 1, data: 0x7f010000U, string_value: None, },
  }
  let manifest = helper_manifest([], [
    helper_permission("uses-permission", Some(reference)),
    helper_permission("uses-permission", None),
    helper_permission(
      "permission",
      Some(helper_literal_name("android.permission.CAMERA")),
    ),
  ])
  assert_false(manifest.requests_permission("android.permission.CAMERA"))
}

///|
test "manifest helpers reject wrong namespace and non name attributes" {
  let literal = helper_literal_name("android.permission.CAMERA")
  for
    attribute in [
      { ..literal, namespace_uri: None, },
      { ..literal, namespace_uri: Some("urn:extension"), },
      { ..literal, name: "label", },
    ] {
    let manifest = helper_manifest([], [
      helper_permission("uses-permission", Some(attribute)),
    ])
    assert_false(manifest.requests_permission("android.permission.CAMERA"))
    @test.assert_eq(
      helper_component("activity", Some(attribute)).qualified_name(
        "example.app",
      ),
      None,
    )
  }
}
