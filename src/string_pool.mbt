///|
fn decoder_length8(
  data : Bytes,
  offset : Int32,
  end : Int32,
) -> (Int32, Int32) raise DecodeError {
  decoder_require(data, offset, 1, end, "UTF-8 length")
  let first = data[offset].to_int()
  if (first & 0x80) == 0 {
    (first, offset + 1)
  } else {
    decoder_require(data, offset, 2, end, "UTF-8 length")
    (((first & 0x7f) << 8) | data[offset + 1].to_int(), offset + 2)
  }
}

///|
fn decoder_length16(
  data : Bytes,
  offset : Int32,
  end : Int32,
) -> (Int32, Int32) raise DecodeError {
  let first = decoder_u16(data, offset, end)
  if (first & 0x8000) == 0 {
    (first, offset + 2)
  } else {
    let second = decoder_u16(data, offset + 2, end)
    (((first & 0x7fff) << 16) | second, offset + 4)
  }
}

///|
/// Decode without replacements, overlong encodings, surrogate scalars or BOM removal.
fn decoder_utf8(
  data : Bytes,
  offset : Int32,
  count : Int32,
  units : Int32,
  end : Int32,
) -> String raise DecodeError {
  decoder_require(data, offset, count, end, "UTF-8 string")
  let stop = offset + count
  let builder = StringBuilder()
  let mut at = offset
  let mut actual_units = 0
  while at < stop {
    let first = data[at].to_int()
    let (width, minimum, initial) = if first < 0x80 {
      (1, 0, first)
    } else if first >= 0xc2 && first <= 0xdf {
      (2, 0x80, first & 0x1f)
    } else if first >= 0xe0 && first <= 0xef {
      (3, 0x800, first & 0x0f)
    } else if first >= 0xf0 && first <= 0xf4 {
      (4, 0x10000, first & 0x07)
    } else {
      raise Invalid(at, "invalid UTF-8 leading byte")
    }
    decoder_require(data, at, width, stop, "UTF-8 sequence")
    let mut scalar = initial
    for i = 1; i < width; i = i + 1 {
      let next = data[at + i].to_int()
      if (next & 0xc0) != 0x80 {
        raise Invalid(at + i, "invalid UTF-8 continuation byte")
      }
      scalar = (scalar << 6) | (next & 0x3f)
    }
    if scalar < minimum ||
      scalar > 0x10ffff ||
      (scalar >= 0xd800 && scalar <= 0xdfff) {
      raise Invalid(at, "invalid UTF-8 Unicode scalar")
    }
    actual_units = actual_units + (if scalar > 0xffff { 2 } else { 1 })
    if actual_units > units {
      raise Invalid(at, "UTF-8 string disagrees with its UTF-16 length")
    }
    builder.write_char(scalar.unsafe_to_char())
    at = at + width
  }
  if actual_units != units {
    raise Invalid(offset, "UTF-8 string disagrees with its UTF-16 length")
  }
  builder.to_string()
}

///|
fn decoder_utf16(
  data : Bytes,
  offset : Int32,
  units : Int32,
  end : Int32,
) -> String raise DecodeError {
  if units > (end - offset) / 2 {
    raise Invalid(offset, "truncated UTF-16 string")
  }
  let stop = offset + units * 2
  let builder = StringBuilder()
  let mut at = offset
  while at < stop {
    let first = decoder_u16(data, at, stop)
    if first >= 0xd800 && first <= 0xdbff {
      let second = decoder_u16(data, at + 2, stop)
      if second < 0xdc00 || second > 0xdfff {
        raise Invalid(at + 2, "UTF-16 high surrogate lacks a low surrogate")
      }
      builder.write_char(
        (0x10000 + ((first - 0xd800) << 10) + second - 0xdc00).unsafe_to_char(),
      )
      at = at + 4
    } else if first >= 0xdc00 && first <= 0xdfff {
      raise Invalid(at, "unpaired UTF-16 low surrogate")
    } else {
      builder.write_char(first.unsafe_to_char())
      at = at + 2
    }
  }
  builder.to_string()
}

///|
/// String-pool offsets and all lengths are checked before allocating strings.
fn decoder_pool(
  data : Bytes,
  chunk : DecoderChunk,
  limits : Limits,
) -> Array[String] raise DecodeError {
  let base = chunk.offset
  if chunk.header_size < 28 {
    raise Invalid(base + 2, "string-pool header must contain 28 bytes")
  }
  let count = decoder_size(data, base + 8, chunk.end)
  let styles = decoder_size(data, base + 12, chunk.end)
  let flags = decoder_u32(data, base + 16, chunk.end)
  let strings_start = decoder_size(data, base + 20, chunk.end)
  let styles_start = decoder_size(data, base + 24, chunk.end)
  let payload_size = chunk.end - base
  if count > limits.max_strings {
    raise Invalid(base + 8, "string count exceeds max_strings")
  }
  if styles > count {
    raise Invalid(base + 12, "style count exceeds string count")
  }
  if (flags & 0xfffffefeU) != 0U {
    raise Invalid(base + 16, "unsupported string-pool flags")
  }
  let table_start = base + chunk.header_size
  if count > (chunk.end - table_start) / 4 ||
    styles > (chunk.end - table_start) / 4 - count {
    raise Invalid(table_start, "truncated string/style offset tables")
  }
  let table_end = chunk.header_size + (count + styles) * 4
  if strings_start < table_end || strings_start > payload_size {
    raise Invalid(base + 20, "string data overlaps the header or offset tables")
  }
  if styles == 0 && styles_start != 0 {
    raise Invalid(base + 24, "style data present without a style table")
  }
  if styles > 0 &&
    (
      styles_start < strings_start ||
      styles_start > payload_size ||
      styles_start % 4 != 0
    ) {
    raise Invalid(base + 24, "invalid style-data offset")
  }
  let string_end = if styles > 0 { base + styles_start } else { chunk.end }
  let utf8 = (flags & 0x100U) != 0U
  if !utf8 && strings_start % 2 != 0 {
    raise Invalid(base + 20, "UTF-16 string data must be two-byte aligned")
  }
  let strings : Array[String] = []
  let mut total_units = 0
  for i = 0; i < count; i = i + 1 {
    let entry = table_start + i * 4
    let relative = decoder_size(data, entry, chunk.end)
    if relative >= string_end - (base + strings_start) {
      raise Invalid(entry, "string offset is outside string data")
    }
    let at = base + strings_start + relative
    if !utf8 && at % 2 != 0 {
      raise Invalid(entry, "UTF-16 string offset must be two-byte aligned")
    }
    let (units, text_start) = if utf8 {
      decoder_length8(data, at, string_end)
    } else {
      decoder_length16(data, at, string_end)
    }
    if units > limits.max_string_units - total_units {
      raise Invalid(at, "decoded strings exceed max_string_units")
    }
    total_units = total_units + units
    let text = if utf8 {
      let (bytes, text_start) = decoder_length8(data, text_start, string_end)
      decoder_require(data, text_start, bytes, string_end, "UTF-8 string")
      decoder_require(
        data,
        text_start + bytes,
        1,
        string_end,
        "UTF-8 terminator",
      )
      if data[text_start + bytes] != b'\x00' {
        raise Invalid(text_start + bytes, "missing UTF-8 terminator")
      }
      decoder_utf8(data, text_start, bytes, units, string_end)
    } else {
      if units > (string_end - text_start) / 2 {
        raise Invalid(text_start, "truncated UTF-16 string")
      }
      let terminator = text_start + units * 2
      if decoder_u16(data, terminator, string_end) != 0 {
        raise Invalid(terminator, "missing UTF-16 terminator")
      }
      decoder_utf16(data, text_start, units, string_end)
    }
    strings.push(text)
  }
  // Style spans are validated although presentation markup is not exposed.
  let seen : Map[Int32, Int32] = Map([])
  let mut span_budget = limits.max_string_units
  for i = 0; i < styles; i = i + 1 {
    let entry = table_start + (count + i) * 4
    let raw = decoder_u32(data, entry, chunk.end)
    if raw == 0xffffffffU {
      continue
    }
    if raw > (payload_size - styles_start).reinterpret_as_uint() ||
      raw % 4U != 0U {
      raise Invalid(entry, "invalid style-span offset")
    }
    let start = base + styles_start + raw.reinterpret_as_int()
    if seen.get(start) is Some(required_units) {
      if required_units > strings[i].length() {
        raise Invalid(entry, "shared style span is outside its string")
      }
      continue
    }
    let mut at = start
    let mut required_units = 0
    while true {
      let name = decoder_u32(data, at, chunk.end)
      if name == 0xffffffffU {
        break
      }
      if span_budget == 0 {
        raise Invalid(at, "style spans exceed max_string_units")
      }
      span_budget = span_budget - 1
      ignore(decoder_string(strings, name, at))
      let first = decoder_u32(data, at + 4, chunk.end)
      let last = decoder_u32(data, at + 8, chunk.end)
      if first > last || last >= strings[i].length().reinterpret_as_uint() {
        raise Invalid(at + 4, "style span is outside its string")
      }
      required_units = required_units.max(last.reinterpret_as_int() + 1)
      at = at + 12
    }
    seen[start] = required_units
  }
  strings
}
