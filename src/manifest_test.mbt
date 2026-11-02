///|
fn manifest_doc(kinds : Array[@axml.EventKind]) -> @axml.Document {
  {
    strings: [],
    resource_ids: [],
    events: kinds.map(fn(kind) { { offset: 100, line_number: 1U, kind, } }),
  }
}

///|
fn manifest_attr(name : String, value : String) -> @axml.Attribute {
  {
    namespace_uri: Some("http://schemas.android.com/apk/res/android"),
    name,
    resource_id: None,
    raw_value: Some(value),
    value: { data_type: 3, data: 0U, string_value: Some(value), },
  }
}

///|
fn manifest_package(value : @axml.TypedValue) -> @axml.Attribute {
  {
    namespace_uri: None,
    name: "package",
    resource_id: None,
    raw_value: None,
    value,
  }
}

///|
test "manifest preserves declarations and unresolved raw typed values" {
  let reference : @axml.Attribute = {
    namespace_uri: Some("http://schemas.android.com/apk/res/android"),
    name: "versionName",
    resource_id: Some(0x0101021cU),
    raw_value: Some("@string/version"),
    value: { data_type: 1, data: 0x7f010000U, string_value: None, },
  }
  let version_code = manifest_attr("versionCode", "42")
  let target_sdk = manifest_attr("targetSdkVersion", "35")
  let permission = manifest_attr("name", "android.permission.INTERNET")
  let component_name = manifest_attr("name", ".MainActivity")
  let exported = manifest_attr("exported", "true")
  let package_attr = manifest_package({
    data_type: 3,
    data: 0U,
    string_value: Some("example.app"),
  })
  let document = manifest_doc([
    @axml.EventKind::StartNamespace(
      Some("android"),
      "http://schemas.android.com/apk/res/android",
    ),
    @axml.EventKind::StartElement(None, "manifest", [
      package_attr, reference, version_code,
    ]),
    @axml.EventKind::StartElement(None, "uses-sdk", [target_sdk]),
    @axml.EventKind::EndElement(None, "uses-sdk"),
    @axml.EventKind::StartElement(None, "uses-permission", [permission]),
    @axml.EventKind::EndElement(None, "uses-permission"),
    @axml.EventKind::StartElement(None, "application", [
      manifest_attr("label", "Example"),
    ]),
    @axml.EventKind::StartElement(None, "activity", [component_name, exported]),
    @axml.EventKind::EndElement(None, "activity"),
    @axml.EventKind::EndElement(None, "application"),
    @axml.EventKind::EndElement(None, "manifest"),
    @axml.EventKind::EndNamespace(
      Some("android"),
      "http://schemas.android.com/apk/res/android",
    ),
  ])
  let metadata = @axml.inspect_manifest(document)
  @test.assert_eq(metadata.package_name, "example.app")
  @test.assert_eq(metadata.version_name, Some(reference))
  @test.assert_eq(metadata.version_code, Some(version_code))
  @test.assert_eq(metadata.sdk.unwrap().target_sdk, Some(target_sdk))
  @test.assert_eq(metadata.sdk.unwrap().min_sdk, None)
  @test.assert_eq(metadata.permissions[0].name, Some(permission))
  @test.assert_eq(metadata.components[0].name, Some(component_name))
  @test.assert_eq(metadata.components[0].exported, Some(exported))
  @test.assert_eq(metadata.components[0].enabled, None)
  @test.assert_eq(metadata.components[0].kind, "activity")
  @test.assert_eq(metadata.application.unwrap().enabled, None)
}

///|
test "manifest inspection only collects declarations at their legal depth" {
  let package_attr = manifest_package({
    data_type: 3,
    data: 0U,
    string_value: Some("example.app"),
  })
  let metadata = @axml.inspect_manifest(
    manifest_doc([
      @axml.EventKind::StartElement(None, "manifest", [package_attr]),
      @axml.EventKind::StartElement(None, "application", []),
      @axml.EventKind::StartElement(None, "activity", [
        manifest_attr("name", ".MainActivity"),
      ]),
      @axml.EventKind::StartElement(None, "service", [
        manifest_attr("name", ".Nested"),
      ]),
      @axml.EventKind::EndElement(None, "service"),
      @axml.EventKind::EndElement(None, "activity"),
      @axml.EventKind::StartElement(Some("urn:extension"), "receiver", []),
      @axml.EventKind::EndElement(Some("urn:extension"), "receiver"),
      @axml.EventKind::EndElement(None, "application"),
      @axml.EventKind::EndElement(None, "manifest"),
    ]),
  )
  @test.assert_eq(metadata.components.length(), 1)
  @test.assert_eq(metadata.permissions.length(), 0)
  @test.assert_eq(metadata.sdk, None)
}

///|
test "manifest requires literal package and manifest root" {
  let cases : Array[Array[@axml.EventKind]] = [
    [
      @axml.EventKind::StartElement(None, "layout", []),
      @axml.EventKind::EndElement(None, "layout"),
    ],
    [
      @axml.EventKind::StartElement(None, "manifest", []),
      @axml.EventKind::EndElement(None, "manifest"),
    ],
    [
      @axml.EventKind::StartElement(None, "manifest", [
        manifest_package({
          data_type: 1,
          data: 0x7f010000U,
          string_value: None,
        }),
      ]),
      @axml.EventKind::EndElement(None, "manifest"),
    ],
  ]
  for kinds in cases {
    let rejected = try {
      @axml.inspect_manifest(manifest_doc(kinds)) |> ignore
      false
    } catch {
      @axml.DecodeError::Invalid(_, _) => true
    }
    assert_true(rejected)
  }
}
