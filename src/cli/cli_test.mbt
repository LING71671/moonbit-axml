///|
test "parse supported operations" {
  assert_eq(
    @cli.parse_args(["decode", "example.axml"]),
    @cli.Decode("example.axml"),
  )
  assert_eq(
    @cli.parse_args(["inspect", "--json", "example.axml"]),
    @cli.Inspect("example.axml"),
  )
  assert_eq(
    @cli.parse_args(["inspect", "example.axml"]),
    @cli.Inspect("example.axml"),
  )
  assert_eq(
    @cli.parse_args(["validate", "example.axml"]),
    @cli.Validate("example.axml"),
  )
  assert_eq(@cli.parse_args(["--help"]), @cli.Help)
}

///|
test "invalid commands do not silently choose a file" {
  for
    args in [
      [],
      ["decode"],
      ["decode", "one", "two"],
      ["inspect", "--json"],
      ["unknown", "file"],
    ] {
    let result = Some(@cli.parse_args(args)) catch { _ => None }
    guard result is None else { fail("expected usage error") }
  }
}

///|
test "informational commands require neither a path nor binary input" {
  assert_eq(@cli.parse_args(["--version"]), @cli.Version)
  assert_eq(@cli.parse_args(["-V"]), @cli.Version)
  assert_eq(@cli.Version.path(), None)
  assert_eq(@cli.execute(@cli.Version, b"not binary XML"), @cli.version)
  assert_eq(@cli.execute(@cli.Help, b"not binary XML"), @cli.usage)
  for command in ["decode", "inspect", "stats", "refs", "validate"] {
    assert_eq(@cli.parse_args([command, "--help"]), @cli.Help)
    assert_eq(@cli.parse_args([command, "-h"]), @cli.Help)
  }
}

///|
test "stats arguments support JSON help literal filenames and host path selection" {
  assert_eq(@cli.parse_args(["stats", "input.axml"]), @cli.Stats("input.axml"))
  assert_eq(
    @cli.parse_args(["stats", "--json", "input.axml"]),
    @cli.Stats("input.axml"),
  )
  assert_eq(@cli.parse_args(["stats", "--", "--help"]), @cli.Stats("--help"))
  assert_eq(
    @cli.parse_args(["stats", "--json", "--", "--json"]),
    @cli.Stats("--json"),
  )
  assert_eq(@cli.Stats("input.axml").path(), Some("input.axml"))
}

///|
test "stats rejects empty missing extra and unrecognized option arguments" {
  for
    args in [
      ["stats"],
      ["stats", ""],
      ["stats", "--json"],
      ["stats", "--json", ""],
      ["stats", "--"],
      ["stats", "--json", "--"],
      ["stats", "--", ""],
      ["stats", "one", "two"],
      ["stats", "--unknown"],
    ] {
    let parsed = Some(@cli.parse_args(args)) catch { _ => None }
    assert_eq(parsed, None)
  }
}

///|
test "stats malformed bytes preserve decoder offset instead of returning JSON" {
  let rejected = try {
    @cli.execute(@cli.Stats("broken"), b"") |> ignore
    false
  } catch {
    @axml.DecodeError::Invalid(0, _) => true
    _ => false
  }
  assert_true(rejected)
}

///|
test "stats execution returns typed JSON for a minimal decoded root" {
  // Owned one-entry UTF-8 pool followed by the root start and end chunks.
  let data = b"\x03\x00\x08\x00\x6c\x00\x00\x00\x01\x00\x1c\x00\x28\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x20\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x04\x04root\x00\x00\x02\x01\x10\x00\x24\x00\x00\x00\x01\x00\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff\x00\x00\x00\x00\x14\x00\x14\x00\x00\x00\x00\x00\x00\x00\x00\x00\x03\x01\x10\x00\x18\x00\x00\x00\x01\x00\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff\x00\x00\x00\x00"
  let expected : Json = {
    "strings": 1,
    "string_utf16_units": "4",
    "resource_ids": 0,
    "events": 2,
    "start_elements": 1,
    "attributes": "0",
    "text_events": 0,
    "namespace_declarations": 0,
    "max_depth": 1,
  }
  assert_eq(
    @cli.execute(@cli.Stats("root.axml"), data),
    expected.stringify(indent=2),
  )
}

///|
test "option terminators select literal leading dash filenames" {
  assert_eq(@cli.parse_args(["decode", "--", "--help"]), @cli.Decode("--help"))
  assert_eq(
    @cli.parse_args(["inspect", "--", "--json"]),
    @cli.Inspect("--json"),
  )
  assert_eq(
    @cli.parse_args(["inspect", "--json", "--", "--version"]),
    @cli.Inspect("--version"),
  )
  assert_eq(
    @cli.parse_args(["validate", "--", "--help"]),
    @cli.Validate("--help"),
  )
}

///|
test "empty paths and incomplete terminators remain usage errors" {
  for
    args in [
      ["decode", ""],
      ["inspect", ""],
      ["inspect", "--json", ""],
      ["validate", ""],
      ["decode", "--"],
      ["inspect", "--json", "--"],
      ["validate", "--", ""],
    ] {
    let parsed = Some(@cli.parse_args(args)) catch { _ => None }
    assert_eq(parsed, None)
  }
}

///|
test "refs arguments support JSON help literal filenames and host path selection" {
  assert_eq(@cli.parse_args(["refs", "input.axml"]), @cli.Refs("input.axml"))
  assert_eq(
    @cli.parse_args(["refs", "--json", "input.axml"]),
    @cli.Refs("input.axml"),
  )
  assert_eq(@cli.parse_args(["refs", "--", "--help"]), @cli.Refs("--help"))
  assert_eq(
    @cli.parse_args(["refs", "--json", "--", "--json"]),
    @cli.Refs("--json"),
  )
  assert_eq(@cli.Refs("input.axml").path(), Some("input.axml"))
}

///|
test "refs rejects missing empty extra and unrecognized option arguments" {
  for
    args in [
      ["refs"],
      ["refs", ""],
      ["refs", "--json"],
      ["refs", "--json", ""],
      ["refs", "--"],
      ["refs", "--json", "--"],
      ["refs", "--", ""],
      ["refs", "one", "two"],
      ["refs", "--unknown"],
    ] {
    let parsed = Some(@cli.parse_args(args)) catch { _ => None }
    assert_eq(parsed, None)
  }
}

///|
test "refs malformed bytes preserve decoder offset instead of returning an empty inventory" {
  let rejected = try {
    @cli.execute(@cli.Refs("broken"), b"") |> ignore
    false
  } catch {
    @axml.DecodeError::Invalid(0, _) => true
    _ => false
  }
  assert_true(rejected)
}

///|
test "refs execution returns an empty JSON array for an ordinary root" {
  let data = b"\x03\x00\x08\x00\x6c\x00\x00\x00\x01\x00\x1c\x00\x28\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x20\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x04\x04root\x00\x00\x02\x01\x10\x00\x24\x00\x00\x00\x01\x00\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff\x00\x00\x00\x00\x14\x00\x14\x00\x00\x00\x00\x00\x00\x00\x00\x00\x03\x01\x10\x00\x18\x00\x00\x00\x01\x00\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff\x00\x00\x00\x00"
  assert_eq(@cli.execute(@cli.Refs("root.axml"), data), "[]")
}

///|
test "refs execution retains typed ID attribute origin and containing event location" {
  // Owned two-entry UTF-8 pool and one unqualified typed-reference attribute.
  let data = b"\x03\x00\x08\x00\x8c\x00\x00\x00\x01\x00\x1c\x00\x34\x00\x00\x00\x02\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x24\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x07\x00\x00\x00\x04\x04root\x00\x05\x05value\x00\x00\x02\x01\x10\x00\x38\x00\x00\x00\x07\x00\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff\x00\x00\x00\x00\x14\x00\x14\x00\x01\x00\x00\x00\x00\x00\x00\x00\xff\xff\xff\xff\x01\x00\x00\x00\xff\xff\xff\xff\x08\x00\x00\x01\x01\x00\x01\x7f\x03\x01\x10\x00\x18\x00\x00\x00\x07\x00\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff\x00\x00\x00\x00"
  let expected : Json = [
    {
      "offset": 60,
      "line_number": 7,
      "origin": ["Attribute", null, "value"],
      "reference": ["Resource", 2130771969],
    },
  ]
  assert_eq(
    @cli.execute(@cli.Refs("root.axml"), data),
    expected.stringify(indent=2),
  )
}
