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
      ["validate", "--help"],
    ] {
    let result = Some(@cli.parse_args(args)) catch { _ => None }
    guard result is None else { fail("expected usage error") }
  }
}
