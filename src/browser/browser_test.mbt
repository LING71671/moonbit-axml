///|
fn browser_test_root() -> Bytes {
  b"\x03\x00\x08\x00\x6c\x00\x00\x00\x01\x00\x1c\x00\x28\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x20\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x04\x04root\x00\x00\x02\x01\x10\x00\x24\x00\x00\x00\x01\x00\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff\x00\x00\x00\x00\x14\x00\x14\x00\x00\x00\x00\x00\x00\x00\x00\x00\x03\x01\x10\x00\x18\x00\x00\x00\x01\x00\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff\x00\x00\x00\x00"
}

///|
test "browser facade returns a structured decode failure for empty bytes" {
  let expected : Json = {
    "schema_version": 1,
    "ok": false,
    "input_bytes": 0,
    "error": {
      "stage": "decode",
      "offset": 0,
      "message": "truncated chunk header",
    },
  }
  assert_eq(@browser.analyze_bytes(b""), expected.stringify())
}

///|
test "browser facade retains XML stats and references for a nonmanifest root" {
  let report = @browser.analyze_bytes(browser_test_root())
  assert_true(report.contains("\"schema_version\":1"))
  assert_true(report.contains("\"input_bytes\":108"))
  assert_true(report.contains("\"value\":\"<root></root>\""))
  assert_true(report.contains("\"string_utf16_units\":\"4\""))
  assert_true(report.contains("\"references\":[]"))
  assert_true(report.contains("\"limit_utf16_units\":2097152"))
  assert_true(report.contains("\"stage\":\"manifest\""))
  assert_true(report.contains("\"stage\":\"intents\""))
}

///|
test "browser facade has no retained state across successful and failing inputs" {
  let first = @browser.analyze_bytes(browser_test_root())
  @browser.analyze_bytes(b"not binary XML") |> ignore
  assert_eq(@browser.analyze_bytes(browser_test_root()), first)
}
