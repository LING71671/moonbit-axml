///|
fn decoder_test_u16(out : Array[Byte], value : Int32) -> Unit {
  out.push(value.to_byte())
  out.push((value >> 8).to_byte())
}

///|
fn decoder_test_u32(out : Array[Byte], value : UInt32) -> Unit {
  for shift = 0; shift < 32; shift = shift + 8 {
    out.push((value >> shift).to_byte())
  }
}

///|
fn decoder_test_add(out : Array[Byte], bytes : Bytes) -> Unit {
  for byte in bytes.iter() {
    out.push(byte)
  }
}

///|
fn decoder_test_chunk(kind : Int32, header : Int32, payload : Bytes) -> Bytes {
  let out : Array[Byte] = []
  decoder_test_u16(out, kind)
  decoder_test_u16(out, header)
  decoder_test_u32(out, (8 + payload.length()).reinterpret_as_uint())
  decoder_test_add(out, payload)
  Bytes::from_array(out)
}

///|
fn decoder_test_pool(
  entries : Array[(Int32, Bytes)],
  utf8~ : Bool = true,
) -> Bytes {
  let text : Array[Byte] = []
  let offsets : Array[Int32] = []
  for entry in entries {
    offsets.push(text.length())
    if utf8 {
      if entry.0 >= 128 {
        text.push(((entry.0 >> 8) | 0x80).to_byte())
      }
      text.push(entry.0.to_byte())
      if entry.1.length() >= 128 {
        text.push(((entry.1.length() >> 8) | 0x80).to_byte())
      }
      text.push(entry.1.length().to_byte())
    } else {
      if entry.0 >= 32768 {
        decoder_test_u16(text, (entry.0 >> 16) | 0x8000)
      }
      decoder_test_u16(text, entry.0 & 0xffff)
    }
    decoder_test_add(text, entry.1)
    text.push(b'\x00')
    if !utf8 {
      text.push(b'\x00')
    }
  }
  while text.length() % 4 != 0 {
    text.push(b'\x00')
  }
  let payload : Array[Byte] = []
  decoder_test_u32(payload, entries.length().reinterpret_as_uint())
  decoder_test_u32(payload, 0U)
  decoder_test_u32(payload, if utf8 { 0x100U } else { 0U })
  decoder_test_u32(payload, (28 + entries.length() * 4).reinterpret_as_uint())
  decoder_test_u32(payload, 0U)
  for offset in offsets {
    decoder_test_u32(payload, offset.reinterpret_as_uint())
  }
  decoder_test_add(payload, Bytes::from_array(text))
  decoder_test_chunk(1, 28, Bytes::from_array(payload))
}

///|
fn decoder_test_strings() -> Bytes {
  decoder_test_pool([
    (4, b"root"),
    (5, b"child"),
    (1, b"p"),
    (5, b"urn:p"),
    (5, b"value"),
    (5, b"hello"),
  ])
}

///|
fn decoder_test_node(kind : Int32, extension : Bytes) -> Bytes {
  let payload : Array[Byte] = []
  decoder_test_u32(payload, 7U)
  decoder_test_u32(payload, 0xffffffffU)
  decoder_test_add(payload, extension)
  decoder_test_chunk(kind, 16, Bytes::from_array(payload))
}

///|
fn decoder_test_start(
  name~ : UInt32 = 0U,
  ns_index~ : UInt32 = 0xffffffffU,
  attributes~ : Array[Bytes] = [],
) -> Bytes {
  let extension : Array[Byte] = []
  decoder_test_u32(extension, ns_index)
  decoder_test_u32(extension, name)
  decoder_test_u16(extension, 20)
  decoder_test_u16(extension, 20)
  decoder_test_u16(extension, attributes.length())
  for _ in 0..<3 {
    decoder_test_u16(extension, 0)
  }
  for attribute in attributes {
    decoder_test_add(extension, attribute)
  }
  decoder_test_node(0x102, Bytes::from_array(extension))
}

///|
fn decoder_test_end(
  name~ : UInt32 = 0U,
  ns_index~ : UInt32 = 0xffffffffU,
) -> Bytes {
  let extension : Array[Byte] = []
  decoder_test_u32(extension, ns_index)
  decoder_test_u32(extension, name)
  decoder_test_node(0x103, Bytes::from_array(extension))
}

///|
fn decoder_test_namespace(
  kind : Int32,
  prefix~ : UInt32 = 2U,
  uri~ : UInt32 = 3U,
) -> Bytes {
  let extension : Array[Byte] = []
  decoder_test_u32(extension, prefix)
  decoder_test_u32(extension, uri)
  decoder_test_node(kind, Bytes::from_array(extension))
}

///|
fn decoder_test_attribute(
  ns_index~ : UInt32 = 0xffffffffU,
  name~ : UInt32 = 4U,
  raw~ : UInt32 = 5U,
  data_type~ : Int32 = 3,
  value~ : UInt32 = 5U,
) -> Bytes {
  let out : Array[Byte] = []
  decoder_test_u32(out, ns_index)
  decoder_test_u32(out, name)
  decoder_test_u32(out, raw)
  decoder_test_u16(out, 8)
  out.push(b'\x00')
  out.push(data_type.to_byte())
  decoder_test_u32(out, value)
  Bytes::from_array(out)
}

///|
fn decoder_test_document(chunks : Array[Bytes]) -> Bytes {
  let payload : Array[Byte] = []
  for chunk in chunks {
    decoder_test_add(payload, chunk)
  }
  decoder_test_chunk(3, 8, Bytes::from_array(payload))
}

///|
fn decoder_test_replace(data : Bytes, offset : Int32, value : UInt32) -> Bytes {
  let out = data.to_array()
  for i = 0; i < 4; i = i + 1 {
    out[offset + i] = (value >> (i * 8)).to_byte()
  }
  Bytes::from_array(out)
}

///|
fn decoder_test_invalid(data : Bytes, expected_offset? : Int32) -> Unit raise {
  let error = @test.expect_error(() => decode(data))
  match error {
    Invalid(offset, message) => {
      assert_true(offset >= 0)
      assert_true(!message.is_empty())
      if expected_offset is Some(expected) {
        @test.assert_eq(offset, expected)
      }
    }
  }
}

///|
test "decoder: namespace, resource map, raw and typed attributes" {
  let map_payload : Array[Byte] = []
  for i = 0; i < 5; i = i + 1 {
    decoder_test_u32(map_payload, if i == 4 { 0x01010003U } else { 0U })
  }
  let input = decoder_test_document([
    decoder_test_strings(),
    decoder_test_chunk(0x180, 8, Bytes::from_array(map_payload)),
    decoder_test_namespace(0x100),
    decoder_test_start(ns_index=3U, attributes=[
      decoder_test_attribute(ns_index=3U),
    ]),
    decoder_test_end(ns_index=3U),
    decoder_test_namespace(0x101),
  ])
  let document = decode(input)
  @test.assert_eq(document.events.length(), 4)
  match document.events[1].kind {
    StartElement(Some("urn:p"), "root", attributes) => {
      @test.assert_eq(attributes[0].raw_value, Some("hello"))
      @test.assert_eq(attributes[0].value.string_value, Some("hello"))
      @test.assert_eq(attributes[0].resource_id, Some(0x01010003U))
    }
    _ => fail("expected namespaced root")
  }
  @test.assert_eq(document.events[1].line_number, 7U)
}

///|
test "decoder: strict Unicode and extended string lengths" {
  let unicode_pool = decoder_test_pool([
    (4, b"root"),
    (4, b"\xe6\x9c\x88\xe4\xba\xae\xf0\xa0\x80\x80"),
    (130, Bytes::make(130, b'a')),
  ])
  let document = decode(
    decoder_test_document([
      unicode_pool,
      decoder_test_start(),
      decoder_test_end(),
    ]),
  )
  @test.assert_eq(document.strings[1], "月亮𠀀")
  @test.assert_eq(document.strings[2].length(), 130)
  let utf16_pool = decoder_test_pool(
    [(4, b"r\x00o\x00o\x00t\x00"), (4, b"\x08\x67\xae\x4e\x40\xd8\x00\xdc")],
    utf8=false,
  )
  let document = decode(
    decoder_test_document([utf16_pool, decoder_test_start(), decoder_test_end()]),
  )
  @test.assert_eq(document.strings[1], "月亮𠀀")
  @test.assert_eq(decoder_length16(b"\x00\x80\x00\x80", 0, 4), (32768, 4))
}

///|
test "decoder: rejects every truncated document prefix with a structured offset" {
  let valid = decoder_test_document([
    decoder_test_strings(),
    decoder_test_start(),
    decoder_test_end(),
  ])
  for length = 0; length < valid.length(); length = length + 1 {
    decoder_test_invalid(Bytes::makei(length, fn(i) { valid[i] }))
  }
}

///|
test "decoder: rejects chunk sizes, bad string indices and attribute strides" {
  let pool = decoder_test_strings()
  let valid = decoder_test_document([
    pool,
    decoder_test_start(attributes=[decoder_test_attribute()]),
    decoder_test_end(),
  ])
  decoder_test_invalid(
    decoder_test_replace(valid, 4, 0xffffffffU),
    expected_offset=4,
  )
  decoder_test_invalid(decoder_test_replace(valid, 12, 0U), expected_offset=10)
  decoder_test_invalid(
    decoder_test_replace(valid, 36, 0xffffffffU),
    expected_offset=36,
  )
  let start = 8 + pool.length()
  decoder_test_invalid(
    decoder_test_replace(valid, start + 20, 0xffffffffU),
    expected_offset=start + 20,
  )
  decoder_test_invalid(
    decoder_test_replace(valid, start + 24, 0U),
    expected_offset=start + 24,
  )
  decoder_test_invalid(
    decoder_test_replace(valid, start + 36 + 16, 99U),
    expected_offset=start + 36 + 16,
  )
}

///|
test "decoder: rejects malformed UTF-8, terminators and declared unit lengths" {
  let malformed : Array[(Int32, Bytes)] = [
    (1, b"\xc0\x80"),
    (1, b"\xed\xa0\x80"),
    (2, b"\xf4\x90\x80\x80"),
    (2, b"\xe6\x9c"),
    (2, b"a"),
    (1, b"\x80"),
  ]
  for entry in malformed {
    let pool = decoder_test_pool([(4, b"root"), entry])
    decoder_test_invalid(
      decoder_test_document([pool, decoder_test_start(), decoder_test_end()]),
    )
  }
  let valid = decoder_test_document([
    decoder_test_strings(),
    decoder_test_start(),
    decoder_test_end(),
  ])
  decoder_test_invalid(decoder_test_replace(valid, 8 + 28 + 24 + 6, 0x61U))
}

///|
test "decoder: rejects unpaired UTF-16 surrogates" {
  for bytes in [b"\x00\xd8", b"\x00\xdc", b"\x00\xd8a\x00"] {
    let pool = decoder_test_pool(
      [(4, b"r\x00o\x00o\x00t\x00"), (bytes.length() / 2, bytes)],
      utf8=false,
    )
    decoder_test_invalid(
      decoder_test_document([pool, decoder_test_start(), decoder_test_end()]),
    )
  }
}

///|
test "decoder: enforces document and namespace structure" {
  let pool = decoder_test_strings()
  let begin = decoder_test_start()
  let end = decoder_test_end()
  let invalid : Array[Array[Bytes]] = [
    [pool],
    [pool, end],
    [pool, begin],
    [pool, begin, decoder_test_end(name=1U)],
    [pool, begin, end, begin, end],
    [pool, pool, begin, end],
    [pool, decoder_test_namespace(0x100), begin, end],
    [pool, decoder_test_namespace(0x101), begin, end],
    [
      pool,
      decoder_test_namespace(0x100),
      decoder_test_namespace(0x100),
      begin,
      end,
    ],
    [
      pool,
      decoder_test_namespace(0x100),
      begin,
      decoder_test_namespace(0x101),
      end,
    ],
    [pool, decoder_test_start(ns_index=3U), decoder_test_end(ns_index=3U)],
    [pool, decoder_test_chunk(0x177, 8, b""), begin, end],
    [pool, begin, end, decoder_test_chunk(0x180, 8, b"")],
  ]
  for chunks in invalid {
    decoder_test_invalid(decoder_test_document(chunks))
  }
}

///|
test "decoder: duplicate expanded attributes and undeclared attribute namespaces fail" {
  let pool = decoder_test_strings()
  let attr = decoder_test_attribute()
  decoder_test_invalid(
    decoder_test_document([
      pool,
      decoder_test_start(attributes=[attr, attr]),
      decoder_test_end(),
    ]),
  )
  decoder_test_invalid(
    decoder_test_document([
      pool,
      decoder_test_namespace(0x100, prefix=0xffffffffU),
      decoder_test_start(attributes=[decoder_test_attribute(ns_index=3U)]),
      decoder_test_end(),
      decoder_test_namespace(0x101, prefix=0xffffffffU),
    ]),
  )
}

///|
test "decoder: configurable limits bound every expansion" {
  let input = decoder_test_document([
    decoder_test_strings(),
    decoder_test_start(attributes=[decoder_test_attribute()]),
    decoder_test_start(name=1U),
    decoder_test_end(name=1U),
    decoder_test_end(),
  ])
  let defaults = Limits::default()
  let limits = [
    { ..defaults, max_input_bytes: input.length() - 1, },
    { ..defaults, max_strings: 1, },
    { ..defaults, max_string_units: 5, },
    { ..defaults, max_depth: 1, },
    { ..defaults, max_events: 1, },
    { ..defaults, max_attributes: 0, },
    { ..defaults, max_depth: 0, },
  ]
  for limit in limits {
    ignore(@test.expect_error(() => decode(input, limits=limit)))
  }
}

///|
test "decoder: namespace shadowing restores the parent binding" {
  let pool = decoder_test_pool([
    (4, b"root"),
    (5, b"child"),
    (1, b"p"),
    (5, b"urn:p"),
    (5, b"urn:q"),
  ])
  let document = decode(
    decoder_test_document([
      pool,
      decoder_test_namespace(0x100),
      decoder_test_start(ns_index=3U),
      decoder_test_namespace(0x100, uri=4U),
      decoder_test_start(name=1U, ns_index=4U),
      decoder_test_end(name=1U, ns_index=4U),
      decoder_test_namespace(0x101, uri=4U),
      decoder_test_start(name=1U, ns_index=3U),
      decoder_test_end(name=1U, ns_index=3U),
      decoder_test_end(ns_index=3U),
      decoder_test_namespace(0x101),
    ]),
  )
  @test.assert_eq(document.events.length(), 10)
}

///|
fn decoder_test_styled_pool(second_length : Int32, last : UInt32) -> Bytes {
  let payload : Array[Byte] = []
  decoder_test_u32(payload, 2U)
  decoder_test_u32(payload, 2U)
  decoder_test_u32(payload, 0x100U)
  decoder_test_u32(payload, 44U)
  decoder_test_u32(payload, 60U)
  decoder_test_u32(payload, 0U)
  decoder_test_u32(payload, 7U)
  decoder_test_u32(payload, 0U)
  decoder_test_u32(payload, 0U)
  decoder_test_add(payload, b"\x04\x04root\x00")
  payload.push(second_length.to_byte())
  payload.push(second_length.to_byte())
  for _ in 0..<second_length {
    payload.push(b'a')
  }
  payload.push(b'\x00')
  while payload.length() < 52 {
    payload.push(b'\x00')
  }
  decoder_test_u32(payload, 0U)
  decoder_test_u32(payload, 0U)
  decoder_test_u32(payload, last)
  decoder_test_u32(payload, 0xffffffffU)
  decoder_test_chunk(1, 28, Bytes::from_array(payload))
}

///|
test "decoder: shared style spans validate each target string and stay bounded" {
  let document = decode(
    decoder_test_document([
      decoder_test_styled_pool(4, 3U),
      decoder_test_start(),
      decoder_test_end(),
    ]),
  )
  @test.assert_eq(document.strings, ["root", "aaaa"])
  decoder_test_invalid(
    decoder_test_document([
      decoder_test_styled_pool(1, 3U),
      decoder_test_start(),
      decoder_test_end(),
    ]),
  )
  decoder_test_invalid(
    decoder_test_document([
      decoder_test_styled_pool(4, 0xffffffffU),
      decoder_test_start(),
      decoder_test_end(),
    ]),
  )
}

///|
test "decoder: implicit xml namespace works and reserved bindings reject misuse" {
  let xml_uri = b"http://www.w3.org/XML/1998/namespace"
  let pool = decoder_test_pool([
    (4, b"root"),
    (3, b"xml"),
    (xml_uri.length(), xml_uri),
    (5, b"value"),
    (5, b"hello"),
  ])
  let document = decode(
    decoder_test_document([
      pool,
      decoder_test_start(attributes=[
        decoder_test_attribute(ns_index=2U, name=3U, raw=4U, value=4U),
      ]),
      decoder_test_end(),
    ]),
  )
  @test.assert_eq(document.events.length(), 2)
  decoder_test_invalid(
    decoder_test_document([
      pool,
      decoder_test_namespace(0x100, prefix=1U, uri=4U),
      decoder_test_start(),
      decoder_test_end(),
    ]),
  )
  decoder_test_invalid(
    decoder_test_document([
      pool,
      decoder_test_namespace(0x100, prefix=3U, uri=2U),
      decoder_test_start(),
      decoder_test_end(),
    ]),
  )
}

///|
test "decoder: shared namespace declarations may close in either order" {
  let pool = decoder_test_pool([
    (4, b"root"),
    (1, b"q"),
    (1, b"p"),
    (5, b"urn:p"),
  ])
  let document = decode(
    decoder_test_document([
      pool,
      decoder_test_namespace(0x100),
      decoder_test_namespace(0x100, prefix=1U),
      decoder_test_start(ns_index=3U),
      decoder_test_end(ns_index=3U),
      decoder_test_namespace(0x101),
      decoder_test_namespace(0x101, prefix=1U),
    ]),
  )
  @test.assert_eq(document.events.length(), 6)
}

///|
test "decoder: long UTF-16 lengths and aggregate expansion limit are checked" {
  let units = 32768
  let payload = Bytes::makei(units * 2, fn(i) {
    if i % 2 == 0 {
      b'a'
    } else {
      b'\x00'
    }
  })
  let pool = decoder_test_pool(
    [(4, b"r\x00o\x00o\x00t\x00"), (units, payload)],
    utf8=false,
  )
  let document = decode(
    decoder_test_document([pool, decoder_test_start(), decoder_test_end()]),
  )
  @test.assert_eq(document.strings[1].length(), units)
  let duplicate_offset = decoder_test_replace(pool, 32, 0U)
  let defaults = Limits::default()
  let input = decoder_test_document([
    duplicate_offset,
    decoder_test_start(),
    decoder_test_end(),
  ])
  ignore(
    @test.expect_error(() => {
      decode(input, limits={ ..defaults, max_string_units: 7, })
    }),
  )
}

///|
test "decoder: single-byte mutation grid never escapes the structured error boundary" {
  let inputs = [
    decoder_test_document([
      decoder_test_strings(),
      decoder_test_start(attributes=[decoder_test_attribute()]),
      decoder_test_end(),
    ]),
    decoder_test_document([
      decoder_test_styled_pool(4, 3U),
      decoder_test_start(),
      decoder_test_end(),
    ]),
    decoder_test_document([
      decoder_test_pool([(4, b"r\x00o\x00o\x00t\x00")], utf8=false),
      decoder_test_start(),
      decoder_test_end(),
    ]),
  ]
  for input in inputs {
    for position = 0; position < input.length(); position = position + 1 {
      for replacement in [b'\x00', b'\x7f', b'\x80', b'\xff'] {
        let mutated = input.to_array()
        mutated[position] = replacement
        ignore(decode(Bytes::from_array(mutated))) catch {
          Invalid(offset, message) => {
            assert_true(offset >= 0)
            assert_true(!message.is_empty())
          }
        }
      }
    }
  }
}
