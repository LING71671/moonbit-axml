// Small owned ASCII documents assembled from Android binary XML chunks.

///|
fn catalog_test_add(out : Array[Byte], bytes : Bytes) -> Unit {
  for byte in bytes.iter() {
    out.push(byte)
  }
}

///|
fn catalog_test_u32(out : Array[Byte], value : UInt32) -> Unit {
  for shift = 0; shift < 32; shift = shift + 8 {
    out.push((value >> shift).to_byte())
  }
}

///|
fn catalog_test_chunk(kind : Int32, header : Int32, data : Bytes) -> Bytes {
  let out : Array[Byte] = [
    kind.to_byte(),
    (kind >> 8).to_byte(),
    header.to_byte(),
    (header >> 8).to_byte(),
  ]
  catalog_test_u32(out, (8 + data.length()).reinterpret_as_uint())
  catalog_test_add(out, data)
  Bytes::from_array(out)
}

///|
fn catalog_test_pool() -> Bytes {
  let strings : Array[Bytes] = [
    b"manifest", b"package", b"org.example.catalog", b"menu", b"urn:missing",
  ]
  let text : Array[Byte] = []
  let offsets : Array[UInt32] = []
  for string in strings {
    offsets.push(text.length().reinterpret_as_uint())
    text.push(string.length().to_byte())
    text.push(string.length().to_byte())
    catalog_test_add(text, string)
    text.push(b'\x00')
  }
  while text.length() % 4 != 0 {
    text.push(b'\x00')
  }
  let pool : Array[Byte] = []
  for value in [5U, 0U, 0x100U, 48U, 0U] {
    catalog_test_u32(pool, value)
  }
  for offset in offsets {
    catalog_test_u32(pool, offset)
  }
  catalog_test_add(pool, Bytes::from_array(text))
  catalog_test_chunk(1, 28, Bytes::from_array(pool))
}

///|
fn catalog_test_document(
  has_package~ : Bool = true,
  root~ : UInt32 = 0U,
  namespace_index~ : UInt32 = 0xffffffffU,
) -> Bytes {
  let start : Array[Byte] = []
  // Source line, comment, namespace and root-name index.
  for value in [1U, 0xffffffffU, namespace_index, root] {
    catalog_test_u32(start, value)
  }
  catalog_test_add(start, b"\x14\x00\x14\x00")
  catalog_test_add(start, if has_package { b"\x01\x00" } else { b"\x00\x00" })
  catalog_test_add(start, b"\x00\x00\x00\x00\x00\x00")
  if has_package {
    // Unqualified package attribute with a literal string value.
    for value in [0xffffffffU, 1U, 2U] {
      catalog_test_u32(start, value)
    }
    catalog_test_add(start, b"\x08\x00\x00\x03")
    catalog_test_u32(start, 2U)
  }
  let end : Array[Byte] = []
  for value in [1U, 0xffffffffU, namespace_index, root] {
    catalog_test_u32(end, value)
  }
  let body : Array[Byte] = []
  catalog_test_add(body, catalog_test_pool())
  catalog_test_add(
    body,
    catalog_test_chunk(0x102, 16, Bytes::from_array(start)),
  )
  catalog_test_add(body, catalog_test_chunk(0x103, 16, Bytes::from_array(end)))
  catalog_test_chunk(3, 8, Bytes::from_array(body))
}

///|
test "empty batches return no synthetic records" {
  assert_eq(@catalog.decode_batch([]), [])
  assert_eq(@catalog.inspect_batch([]), [])
}

///|
test "decode batch preserves ordered successes around a corrupt input" {
  let data = catalog_test_document()
  let records = @catalog.decode_batch([
    { name: "first", data, },
    { name: "broken", data: b"", },
    { name: "last", data, },
  ])
  assert_eq(records.length(), 3)
  assert_eq(records.map(fn(record) { record.name }), ["first", "broken", "last"])
  for index in [0, 2] {
    assert_eq(records[index].byte_length, data.length())
    guard records[index].outcome is @catalog.Success(document) else {
      fail("valid document was discarded")
    }
    assert_eq(document.events.length(), 2)
  }
  guard records[1].outcome is @catalog.Failure(diagnostic) else {
    fail("corrupt input was accepted")
  }
  assert_eq(records[1].byte_length, 0)
  assert_eq(diagnostic.stage, @catalog.Decode)
  assert_eq(diagnostic.offset, 0)
  assert_true(diagnostic.message.length() > 0)
}

///|
test "manifest batch separates decode namespace and metadata failures" {
  let records = @catalog.inspect_batch([
    { name: "valid", data: catalog_test_document(), },
    { name: "unbound", data: catalog_test_document(namespace_index=4U), },
    { name: "menu", data: catalog_test_document(root=3U), },
    { name: "no-package", data: catalog_test_document(has_package=false), },
    { name: "valid-again", data: catalog_test_document(), },
  ])
  assert_eq(records.length(), 5)
  for index in [0, 4] {
    guard records[index].outcome is @catalog.Success(manifest) else {
      fail("valid manifest was discarded")
    }
    assert_eq(manifest.package_name, "org.example.catalog")
  }
  guard records[1].outcome is @catalog.Failure(namespace_error) else {
    fail("unbound namespace was accepted")
  }
  assert_eq(namespace_error.stage, @catalog.Decode)
  assert_eq(namespace_error.offset, 8 + catalog_test_pool().length() + 16)
  assert_eq(namespace_error.message, "namespace URI has no active binding")
  for index in [2, 3] {
    guard records[index].outcome is @catalog.Failure(metadata_error) else {
      fail("non-manifest input was accepted")
    }
    assert_eq(metadata_error.stage, @catalog.InspectManifest)
    assert_eq(metadata_error.offset, 8 + catalog_test_pool().length())
  }
}

///|
test "duplicate and empty labels are retained without merging" {
  let data = catalog_test_document()
  let inputs : Array[@catalog.NamedInput] = [
    { name: "same", data, },
    { name: "same", data: b"", },
    { name: "", data, },
  ]
  let records = @catalog.inspect_batch(inputs)
  assert_eq(records.map(fn(record) { record.name }), ["same", "same", ""])
  guard records[0].outcome is @catalog.Success(_) else {
    fail("first duplicate lost its success")
  }
  guard records[1].outcome is @catalog.Failure(_) else {
    fail("second duplicate lost its failure")
  }
  guard records[2].outcome is @catalog.Success(_) else {
    fail("empty label must not be interpreted as a path")
  }
  assert_eq(inputs[1].data, b"")
}

///|
test "custom limits apply to every input without a batch exception" {
  let data = catalog_test_document()
  let limits = @axml.Limits::{
    ..@axml.Limits::default(),
    max_input_bytes: data.length() - 1,
  }
  let records = @catalog.inspect_batch(
    [
      { name: "oversize", data, },
      { name: "empty", data: b"", },
      { name: "oversize-again", data, },
    ],
    limits~,
  )
  assert_eq(records.length(), 3)
  for index in [0, 2] {
    assert_eq(
      records[index].outcome,
      @catalog.Failure({
        stage: @catalog.Decode,
        offset: 0,
        message: "input exceeds max_input_bytes",
      }),
    )
  }
  let invalid_limits = @axml.Limits::{ ..limits, max_depth: 0, }
  let invalid = @catalog.decode_batch(
    [{ name: "one", data, }],
    limits=invalid_limits,
  )
  assert_eq(
    invalid[0].outcome,
    @catalog.Failure({
      stage: @catalog.Decode,
      offset: 0,
      message: "invalid decoder limits",
    }),
  )
}
