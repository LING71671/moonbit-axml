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
  for command in ["decode", "inspect", "validate"] {
    assert_eq(@cli.parse_args([command, "--help"]), @cli.Help)
    assert_eq(@cli.parse_args([command, "-h"]), @cli.Help)
  }
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
