///|
fn decoder_prefix(prefix : String?) -> String? {
  match prefix {
    Some("") => None
    _ => prefix
  }
}

///|
/// An attribute needs a non-default binding; elements can use a default binding.
fn decoder_check_namespace(
  active_uris : Map[String, Int32],
  uri : String?,
  offset : Int32,
) -> Unit raise DecodeError {
  guard uri is Some(uri) else { return }
  if uri.is_empty() {
    raise Invalid(
      offset, "an empty namespace URI must use the absent-string sentinel",
    )
  }
  if active_uris.get_or_default(uri, 0) == 0 {
    raise Invalid(offset, "namespace URI has no active binding")
  }
}

///|
fn decoder_uri_count(
  uris : Map[String, Int32],
  uri : String,
  change : Int32,
) -> Unit {
  let count = uris.get_or_default(uri, 0) + change
  if count == 0 {
    uris.remove(uri)
  } else {
    uris[uri] = count
  }
}

///|
/// Maintain effective URI counts so namespace checks stay constant-time even
/// for adversarial documents with many declarations and attributes.
fn decoder_binding_change(
  prefix : String?,
  old_uri : String?,
  new_uri : String?,
  element_uris : Map[String, Int32],
  attribute_uris : Map[String, Int32],
) -> Unit {
  if old_uri is Some(uri) {
    decoder_uri_count(element_uris, uri, -1)
    if prefix != None {
      decoder_uri_count(attribute_uris, uri, -1)
    }
  }
  if new_uri is Some(uri) {
    decoder_uri_count(element_uris, uri, 1)
    if prefix != None {
      decoder_uri_count(attribute_uris, uri, 1)
    }
  }
}

///|
fn decoder_value(
  data : Bytes,
  offset : Int32,
  end : Int32,
  strings : Array[String],
) -> TypedValue raise DecodeError {
  decoder_require(data, offset, 8, end, "typed value")
  if decoder_u16(data, offset, end) != 8 {
    raise Invalid(offset, "typed value size must be eight bytes")
  }
  if data[offset + 2] != b'\x00' {
    raise Invalid(offset + 2, "typed value reserved byte must be zero")
  }
  let data_type = data[offset + 3].to_int()
  let value = decoder_u32(data, offset + 4, end)
  let string_value = if data_type == 3 {
    Some(decoder_string(strings, value, offset + 4))
  } else {
    None
  }
  { data_type, data: value, string_value, }
}

///|
fn decoder_limits(limits : Limits) -> Unit raise DecodeError {
  if limits.max_input_bytes < 8 ||
    limits.max_strings < 0 ||
    limits.max_depth < 1 ||
    limits.max_events < 1 ||
    limits.max_attributes < 0 ||
    limits.max_string_units < 0 {
    raise Invalid(0, "invalid decoder limits")
  }
}

///|
/// Decode one complete Android binary XML document with bounded allocation.
/// Unknown chunks, broken Unicode, invalid references and unbalanced scopes fail
/// with their original byte offset. The input must be extracted XML, not an APK.
pub fn decode(
  data : Bytes,
  limits~ : Limits = Limits::default(),
) -> Document raise DecodeError {
  decoder_limits(limits)
  if data.length() > limits.max_input_bytes {
    raise Invalid(0, "input exceeds max_input_bytes")
  }
  let outer = decoder_chunk(data, 0, data.length())
  if outer.kind != 0x0003 {
    raise Invalid(0, "expected an Android binary XML document (RES_XML_TYPE)")
  }
  if outer.header_size != 8 {
    raise Invalid(2, "binary XML document header must contain eight bytes")
  }
  if outer.end != data.length() {
    raise Invalid(outer.end, "trailing data after binary XML document")
  }
  let mut strings : Array[String] = []
  let resource_ids : Array[UInt32] = []
  let events : Array[Event] = []
  let elements : Array[(String?, String)] = []
  let declarations : Map[(Int32, String?), String] = Map([])
  let namespace_counts : Map[Int32, Int32] = Map([])
  let namespace_stacks : Map[String?, Array[String]] = Map([])
  let element_uris : Map[String, Int32] = Map([])
  let attribute_uris : Map[String, Int32] = Map([])
  // XML defines this binding implicitly; a source need not declare it.
  namespace_stacks[Some("xml")] = ["http://www.w3.org/XML/1998/namespace"]
  element_uris["http://www.w3.org/XML/1998/namespace"] = 1
  attribute_uris["http://www.w3.org/XML/1998/namespace"] = 1
  let mut pool_seen = false
  let mut map_seen = false
  let mut nodes_seen = false
  let mut root_seen = false
  let mut root_closed = false
  let mut pending_start_namespaces = false
  let mut pending_end_namespaces = 0
  let mut at = outer.header_size
  while at < outer.end {
    let chunk = decoder_chunk(data, at, outer.end)
    if chunk.kind == 0x0001 {
      if pool_seen || nodes_seen || map_seen {
        raise Invalid(
          at, "string pool must appear exactly once before XML nodes",
        )
      }
      strings = decoder_pool(data, chunk, limits)
      pool_seen = true
    } else if chunk.kind == 0x0180 {
      if !pool_seen || map_seen || nodes_seen {
        raise Invalid(
          at, "resource map must appear once after the string pool and before XML nodes",
        )
      }
      let count = (chunk.end - at - chunk.header_size) / 4
      if count > strings.length() {
        raise Invalid(at, "resource map has more entries than the string pool")
      }
      for i = 0; i < count; i = i + 1 {
        resource_ids.push(
          decoder_u32(data, at + chunk.header_size + i * 4, chunk.end),
        )
      }
      map_seen = true
    } else {
      if !pool_seen {
        raise Invalid(at, "XML node appears before the string pool")
      }
      if chunk.kind < 0x0100 || chunk.kind > 0x0104 {
        raise Invalid(at, "unsupported binary XML chunk type \{chunk.kind}")
      }
      if events.length() >= limits.max_events {
        raise Invalid(at, "event count exceeds max_events")
      }
      nodes_seen = true
      if chunk.header_size < 16 {
        raise Invalid(
          at + 2,
          "XML node header must contain at least sixteen bytes",
        )
      }
      let line_number = decoder_u32(data, at + 8, chunk.end)
      ignore(
        decoder_optional_string(
          strings,
          decoder_u32(data, at + 12, chunk.end),
          at + 12,
        ),
      )
      let ext = at + chunk.header_size
      if pending_end_namespaces > 0 && chunk.kind != 0x0101 {
        raise Invalid(at, "namespace scope must close before another XML node")
      }
      if pending_start_namespaces &&
        chunk.kind != 0x0100 &&
        chunk.kind != 0x0102 {
        raise Invalid(
          at, "namespace declarations must precede their start element",
        )
      }
      let kind : EventKind = match chunk.kind {
        0x0100 => {
          if root_closed {
            raise Invalid(
              at, "namespace declaration appears after the root element",
            )
          }
          if chunk.end - ext != 8 {
            raise Invalid(
              ext, "namespace node payload must contain eight bytes",
            )
          }
          let prefix = decoder_prefix(
            decoder_optional_string(
              strings,
              decoder_u32(data, ext, chunk.end),
              ext,
            ),
          )
          let uri = decoder_string(
            strings,
            decoder_u32(data, ext + 4, chunk.end),
            ext + 4,
          )
          if prefix == Some("xmlns") || uri == "http://www.w3.org/2000/xmlns/" {
            raise Invalid(ext, "the xmlns namespace is reserved")
          }
          if (prefix == Some("xml")) !=
            (uri == "http://www.w3.org/XML/1998/namespace") {
            raise Invalid(
              ext, "the xml prefix must use its reserved namespace URI",
            )
          }
          if prefix != None && uri.is_empty() {
            raise Invalid(
              ext + 4,
              "a named namespace prefix cannot have an empty URI",
            )
          }
          let key = (elements.length(), prefix)
          if declarations.contains(key) {
            raise Invalid(ext, "duplicate namespace prefix on an element")
          }
          declarations[key] = uri
          namespace_counts[elements.length()] = namespace_counts.get_or_default(
              elements.length(),
              0,
            ) +
            1
          let stack = namespace_stacks.get_or_init(prefix, fn() { [] })
          decoder_binding_change(
            prefix,
            stack.last(),
            Some(uri),
            element_uris,
            attribute_uris,
          )
          stack.push(uri)
          pending_start_namespaces = true
          StartNamespace(prefix, uri)
        }
        0x0101 => {
          if chunk.end - ext != 8 {
            raise Invalid(
              ext, "namespace node payload must contain eight bytes",
            )
          }
          if pending_end_namespaces == 0 {
            raise Invalid(at, "namespace end does not follow its element end")
          }
          let prefix = decoder_prefix(
            decoder_optional_string(
              strings,
              decoder_u32(data, ext, chunk.end),
              ext,
            ),
          )
          let uri = decoder_string(
            strings,
            decoder_u32(data, ext + 4, chunk.end),
            ext + 4,
          )
          let key = (elements.length(), prefix)
          if declarations.get(key) != Some(uri) {
            raise Invalid(
              ext, "namespace end does not match an active declaration",
            )
          }
          declarations.remove(key)
          let stack = namespace_stacks[prefix]
          ignore(stack.pop())
          decoder_binding_change(
            prefix,
            Some(uri),
            stack.last(),
            element_uris,
            attribute_uris,
          )
          if stack.is_empty() {
            namespace_stacks.remove(prefix)
          }
          pending_end_namespaces = pending_end_namespaces - 1
          if pending_end_namespaces == 0 {
            namespace_counts.remove(elements.length())
          }
          EndNamespace(prefix, uri)
        }
        0x0102 => {
          decoder_require(data, ext, 20, chunk.end, "start-element extension")
          if root_closed {
            raise Invalid(at, "document contains more than one root element")
          }
          if elements.length() >= limits.max_depth {
            raise Invalid(at, "element nesting exceeds max_depth")
          }
          let namespace_uri = decoder_optional_string(
            strings,
            decoder_u32(data, ext, chunk.end),
            ext,
          )
          let name = decoder_string(
            strings,
            decoder_u32(data, ext + 4, chunk.end),
            ext + 4,
          )
          decoder_check_namespace(element_uris, namespace_uri, ext)
          let attribute_start = decoder_u16(data, ext + 8, chunk.end)
          let attribute_size = decoder_u16(data, ext + 10, chunk.end)
          let count = decoder_u16(data, ext + 12, chunk.end)
          if attribute_start < 20 || attribute_size < 20 {
            raise Invalid(
              ext + 8,
              "attribute start and stride must be at least twenty bytes",
            )
          }
          if count > limits.max_attributes {
            raise Invalid(ext + 12, "attribute count exceeds max_attributes")
          }
          for field = 14; field <= 18; field = field + 2 {
            if decoder_u16(data, ext + field, chunk.end) > count {
              raise Invalid(
                ext + field,
                "special attribute index exceeds attribute count",
              )
            }
          }
          decoder_require(
            data,
            ext,
            attribute_start,
            chunk.end,
            "attribute offset",
          )
          let attrs_at = ext + attribute_start
          if count > (chunk.end - attrs_at) / attribute_size {
            raise Invalid(attrs_at, "truncated attribute array")
          }
          if attrs_at + count * attribute_size != chunk.end {
            raise Invalid(
              attrs_at + count * attribute_size,
              "trailing bytes after attribute array",
            )
          }
          let attributes : Array[Attribute] = []
          let seen : Map[(String?, String), Bool] = Map([])
          for i = 0; i < count; i = i + 1 {
            let attr = attrs_at + i * attribute_size
            let namespace_uri = decoder_optional_string(
              strings,
              decoder_u32(data, attr, chunk.end),
              attr,
            )
            let name_index = decoder_u32(data, attr + 4, chunk.end)
            let name = decoder_string(strings, name_index, attr + 4)
            decoder_check_namespace(attribute_uris, namespace_uri, attr)
            let key = (namespace_uri, name)
            if seen.contains(key) {
              raise Invalid(attr, "duplicate attribute expanded name")
            }
            seen[key] = true
            let raw_value = decoder_optional_string(
              strings,
              decoder_u32(data, attr + 8, chunk.end),
              attr + 8,
            )
            let value = decoder_value(
              data,
              attr + 12,
              attr + attribute_size,
              strings,
            )
            let resource_id = if name_index <
              resource_ids.length().reinterpret_as_uint() &&
              resource_ids[name_index.reinterpret_as_int()] != 0U {
              Some(resource_ids[name_index.reinterpret_as_int()])
            } else {
              None
            }
            attributes.push({
              namespace_uri,
              name,
              resource_id,
              raw_value,
              value,
            })
          }
          if elements.is_empty() {
            root_seen = true
          }
          elements.push((namespace_uri, name))
          pending_start_namespaces = false
          StartElement(namespace_uri, name, attributes)
        }
        0x0103 => {
          if chunk.end - ext != 8 {
            raise Invalid(
              ext, "end-element node payload must contain eight bytes",
            )
          }
          let namespace_uri = decoder_optional_string(
            strings,
            decoder_u32(data, ext, chunk.end),
            ext,
          )
          let name = decoder_string(
            strings,
            decoder_u32(data, ext + 4, chunk.end),
            ext + 4,
          )
          match elements.pop() {
            Some((expected_uri, expected_name)) =>
              if expected_uri != namespace_uri || expected_name != name {
                raise Invalid(
                  ext, "end element does not match its start element",
                )
              }
            None =>
              raise Invalid(at, "end element has no matching start element")
          }
          pending_end_namespaces = namespace_counts.get_or_default(
            elements.length(),
            0,
          )
          if elements.is_empty() {
            root_closed = true
          }
          EndElement(namespace_uri, name)
        }
        0x0104 => {
          if elements.is_empty() {
            raise Invalid(at, "CDATA must be inside an element")
          }
          if chunk.end - ext != 12 {
            raise Invalid(ext, "CDATA node payload must contain twelve bytes")
          }
          let text = decoder_string(
            strings,
            decoder_u32(data, ext, chunk.end),
            ext,
          )
          Text(text, decoder_value(data, ext + 4, chunk.end, strings))
        }
        _ => raise Invalid(at, "unsupported binary XML node")
      }
      events.push({ offset: at, line_number, kind, })
    }
    at = chunk.end
  }
  if !pool_seen {
    raise Invalid(at, "document has no string pool")
  }
  if !root_seen {
    raise Invalid(at, "document has no root element")
  }
  if !elements.is_empty() {
    raise Invalid(at, "unclosed element at end of document")
  }
  if !declarations.is_empty() {
    raise Invalid(at, "unclosed namespace at end of document")
  }
  { strings, resource_ids, events, }
}
