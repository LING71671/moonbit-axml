# Manifest Helpers

[中文](MANIFEST_zh.md)

`inspect_manifest(document)` preserves declared attributes and typed values.
The helpers below are optional queries; they do not change the inspected data.

## Select components

```moonbit
let manifest = @axml.inspect_manifest(document)
let activities = manifest.components_of_kind("activity")
```

Selection uses the exact element name and retains declaration order. An
`activity-alias` is distinct from an `activity`. An unknown kind returns an empty
array. Only direct children of `application` enter the inspected component list.

## Expand a component name explicitly

```moonbit
let name = @axml.resolve_component_name("example.app", ".ui.MainActivity")
// name == "example.app.ui.MainActivity"
for component in activities {
  let qualified = component.qualified_name(manifest.package_name)
  // qualified is String?: resource references and absent names remain None.
}
```

The caller supplies the package explicitly. `.MainActivity` becomes
`example.app.MainActivity`; bare `MainActivity` also receives the package prefix.
`other.app.MainActivity` remains unchanged. This follows Android manifest name
expansion in [AOSP PackageParser](https://android.googlesource.com/platform/frameworks/base/+/a86290891a661ecdc8115fd441b44dcebedb9e3d/core/java/android/content/pm/PackageParser.java).
It performs syntactic expansion, not Java identifier validation, class loading,
or resource resolution. Supply the correct package context when examining
unmerged sources or manifests affected by build-time namespace rewriting.

`qualified_name` reads only a literal Android-namespace `android:name` typed as a
string. Missing, unresolved and non-string names return `None`; raw symbolic
text is never treated as a resolved value. Empty literal names and empty
explicit package names raise `DecodeError::Invalid(-1, message)`. Offset `-1`
means the helper has no original byte offset. The original `.name`, `.exported`
and `.enabled` attributes stay unchanged.

## Query requested permissions

```moonbit
let requests_camera = manifest.requests_permission("android.permission.CAMERA")
```

The query matches exact, case-sensitive literal `android:name` values from
`uses-permission`, `uses-permission-sdk-23` and `uses-permission-sdk-m` declarations.
An empty query returns `false`. Resource references, differently namespaced
attributes and permission definitions do not match. See Android's
[uses-permission documentation](https://developer.android.com/guide/topics/manifest/uses-permission-element).

This reports declarations only: it does not evaluate `maxSdkVersion`, device SDK,
target SDK, install-time filtering or runtime grants. `false` means no matching
literal declaration was found; an unresolved reference may still exist.

## Verify

Run the helper tests from the repository root:

```sh
moon test src/manifest_helpers_test.mbt --target wasm-gc --deny-warn
```

Repeat with `--target js` and `--target native` for the other supported backends.
