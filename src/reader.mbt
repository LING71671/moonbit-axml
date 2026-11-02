///|
/// Checked little-endian reads. Subtraction-based bounds checks avoid overflow.
fn decoder_require(
  data : Bytes,
  offset : Int32,
  size : Int32,
  end : Int32,
  what : String,
) -> Unit raise DecodeError {
  if offset < 0 ||
    size < 0 ||
    end > data.length() ||
    offset > end ||
    size > end - offset {
    raise Invalid(offset, "truncated \{what}")
  }
}

///|
fn decoder_u16(
  data : Bytes,
  offset : Int32,
  end : Int32,
) -> Int32 raise DecodeError {
  decoder_require(data, offset, 2, end, "16-bit field")
  data[offset].to_int() | (data[offset + 1].to_int() << 8)
}

///|
fn decoder_u32(
  data : Bytes,
  offset : Int32,
  end : Int32,
) -> UInt32 raise DecodeError {
  decoder_require(data, offset, 4, end, "32-bit field")
  data[offset].to_uint() |
  (data[offset + 1].to_uint() << 8) |
  (data[offset + 2].to_uint() << 16) |
  (data[offset + 3].to_uint() << 24)
}

///|
fn decoder_size(
  data : Bytes,
  offset : Int32,
  end : Int32,
) -> Int32 raise DecodeError {
  let n = decoder_u32(data, offset, end)
  if n > 0x7fffffffU {
    raise Invalid(offset, "size exceeds supported integer range")
  }
  n.reinterpret_as_int()
}

///|
priv struct DecoderChunk {
  offset : Int32
  kind : Int32
  header_size : Int32
  end : Int32
}

///|
fn decoder_chunk(
  data : Bytes,
  offset : Int32,
  end : Int32,
) -> DecoderChunk raise DecodeError {
  decoder_require(data, offset, 8, end, "chunk header")
  let kind = decoder_u16(data, offset, end)
  let header_size = decoder_u16(data, offset + 2, end)
  let size = decoder_size(data, offset + 4, end)
  if header_size < 8 || size < header_size {
    raise Invalid(offset + 2, "chunk size is smaller than its header")
  }
  if offset % 4 != 0 || header_size % 4 != 0 || size % 4 != 0 {
    raise Invalid(offset, "chunk header and size must be four-byte aligned")
  }
  decoder_require(data, offset, size, end, "chunk payload")
  { offset, kind, header_size, end: offset + size, }
}

///|
fn decoder_string(
  strings : Array[String],
  index : UInt32,
  offset : Int32,
) -> String raise DecodeError {
  if index >= strings.length().reinterpret_as_uint() {
    raise Invalid(offset, "string-pool index \{index} is out of bounds")
  }
  strings[index.reinterpret_as_int()]
}

///|
fn decoder_optional_string(
  strings : Array[String],
  index : UInt32,
  offset : Int32,
) -> String? raise DecodeError {
  if index == 0xffffffffU {
    None
  } else {
    Some(decoder_string(strings, index, offset))
  }
}
