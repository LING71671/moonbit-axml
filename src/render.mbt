///|
/// Format an Android value without resolving resources or attribute enums.
pub fn TypedValue::text(self : TypedValue) -> String raise DecodeError {
  match self.data_type {
    0 => if self.data == 1U { "@empty" } else { "@null" }
    1 | 7 => "@0x" + render_hex(self.data, 8)
    2 | 8 => "?0x" + render_hex(self.data, 8)
    3 =>
      match self.string_value {
        Some(value) => value
        None => raise Invalid(-1, "string typed value has no decoded string")
      }
    4 => {
      let value = Float::reinterpret_from_uint(self.data)
      if value.is_nan() || value.is_inf() {
        raise Invalid(-1, "non-finite float cannot be rendered")
      }
      value.to_string()
    }
    5 | 6 => {
      let unit = (self.data & 15U).reinterpret_as_int()
      let magnitude = value_complex_magnitude(self.data)
      if self.data_type == 5 {
        if unit > 5 {
          raise Invalid(-1, "invalid dimension unit")
        }
        magnitude.to_string() + ["px", "dip", "sp", "pt", "in", "mm"][unit]
      } else {
        if unit > 1 {
          raise Invalid(-1, "invalid fraction unit")
        }
        (magnitude * 100.0).to_string() + ["%", "%p"][unit]
      }
    }
    0x11 => "0x" + self.data.to_string(radix=16)
    0x12 => if self.data == 0U { "false" } else { "true" }
    0x1c | 0x1d | 0x1e | 0x1f => "#" + render_hex(self.data, 8)
    code if code >= 0x10 && code <= 0x1f =>
      self.data.reinterpret_as_int().to_string()
    _ => raise Invalid(-1, "unsupported Android typed value")
  }
}

///|
fn render_hex(value : UInt32, width : Int32) -> String {
  let text = value.to_string(radix=16)
  let padding = StringBuilder()
  for index = text.length(); index < width; index = index + 1 {
    padding.write_string("0")
  }
  padding.write_string(text)
  padding.to_string()
}

///|
/// Raw symbolic resource names cannot be verified without resources.arsc.
fn render_attribute_text(
  attribute : Attribute,
  offset : Int32,
) -> String raise DecodeError {
  let typed = attribute.value.text() catch {
    Invalid(_, message) => raise Invalid(offset, message)
  }
  match attribute.raw_value {
    Some(raw) if raw == typed => raw
    _ => typed
  }
}

///|
fn render_name_start(code : Int32) -> Bool {
  code == 95 ||
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  (code >= 0xc0 && code <= 0xd6) ||
  (code >= 0xd8 && code <= 0xf6) ||
  (code >= 0xf8 && code <= 0x2ff) ||
  (code >= 0x370 && code <= 0x37d) ||
  (code >= 0x37f && code <= 0x1fff) ||
  (code >= 0x200c && code <= 0x200d) ||
  (code >= 0x2070 && code <= 0x218f) ||
  (code >= 0x2c00 && code <= 0x2fef) ||
  (code >= 0x3001 && code <= 0xd7ff) ||
  (code >= 0xf900 && code <= 0xfdcf) ||
  (code >= 0xfdf0 && code <= 0xfffd) ||
  (code >= 0x10000 && code <= 0xeffff)
}

///|
fn render_check_name(name : String, offset : Int32) -> Unit raise DecodeError {
  let mut first = true
  for char in name.iter() {
    let code = char.to_int()
    if !render_name_start(code) &&
      (
        first ||
        !(code == 45 ||
        code == 46 ||
        (code >= 48 && code <= 57) ||
        code == 0xb7 ||
        (code >= 0x300 && code <= 0x36f) ||
        (code >= 0x203f && code <= 0x2040))
      ) {
      raise Invalid(offset, "invalid XML local name or namespace prefix")
    }
    first = false
  }
  if first {
    raise Invalid(offset, "empty XML local name or namespace prefix")
  }
}

///|
fn render_escape(
  text : String,
  attribute : Bool,
  offset : Int32,
) -> String raise DecodeError {
  let output = StringBuilder()
  let mut cursor = 0
  let mut span_start = 0
  for char in text.iter() {
    let code = char.to_int()
    if !(code == 9 ||
      code == 10 ||
      code == 13 ||
      (code >= 0x20 && code <= 0xd7ff) ||
      (code >= 0xe000 && code <= 0xfffd) ||
      (code >= 0x10000 && code <= 0x10ffff)) {
      raise Invalid(offset, "character is forbidden by XML 1.0")
    }
    let replacement = match char {
      '&' => Some("&amp;")
      '<' => Some("&lt;")
      '>' => Some("&gt;")
      '"' if attribute => Some("&quot;")
      '\r' => Some("&#13;")
      '\n' if attribute => Some("&#10;")
      '\t' if attribute => Some("&#9;")
      _ => None
    }
    if replacement is Some(replacement) {
      // Keep ordinary spans intact: JS StringBuilder appends create rope nodes,
      // so writing each unchanged character retains excessive intermediate data.
      output.write_view(text[span_start:cursor])
      output.write_string(replacement)
      span_start = cursor + 1
    }
    // String slices use UTF-16 units; iter() yields Unicode scalar values.
    cursor = cursor + (if code > 0xffff { 2 } else { 1 })
  }
  if span_start == 0 {
    // Validation still ran, but an unchanged pool entry needs no allocation.
    text
  } else {
    output.write_view(text[span_start:])
    output.to_string()
  }
}

///|
priv struct RenderBinding {
  prefix : String
  uri : String
  depth : Int32
  explicit : Bool
  mut used : Bool
}

///|
priv struct RenderElement {
  uri : String?
  name : String
  qualified : String
  declarations : Array[RenderBinding]
  pretty_children : Bool
  mut has_children : Bool
}

///|
/// Index effective bindings by prefix and URI. Swap-removal keeps namespace
/// shadowing and arbitrary namespace-end order linear in the event count.
priv struct RenderNamespaces {
  stacks : Map[String, Array[RenderBinding]]
  prefixes : Map[String, Array[String]]
  positions : Map[(String, String), Int32]
  mut serial : Int32
}

///|
priv struct RenderOutput {
  builder : StringBuilder
  limit : Int32
  mut size : Int32
  mut offset : Int32
}

///|
fn RenderOutput::write_string(
  self : RenderOutput,
  value : String,
) -> Unit raise DecodeError {
  if value.length() > self.limit - self.size {
    raise Invalid(self.offset, "XML output exceeds configured limit")
  }
  self.size = self.size + value.length()
  self.builder.write_string(value)
}

///|
fn RenderOutput::write_indent(
  self : RenderOutput,
  depth : Int32,
) -> Unit raise DecodeError {
  let remaining = self.limit - self.size
  // Check before multiplication or writing: custom depth limits must not cause
  // an overflowing length or allocate an indentation string outside the budget.
  if remaining < 1 || depth > (remaining - 1) / 2 {
    raise Invalid(self.offset, "XML output exceeds configured limit")
  }
  self.size = self.size + 1 + depth * 2
  self.builder.write_string("\n")
  for index = 0; index < depth; index = index + 1 {
    self.builder.write_string("  ")
  }
}

///|
/// Text events originate from AXML CDATA chunks, including empty/whitespace
/// events. A look-ahead pass prevents inserting whitespace before later text.
fn render_text_parents(
  document : Document,
  max_depth : Int32,
) -> Map[Int32, Bool] raise DecodeError {
  let text_parents : Map[Int32, Bool] = Map([])
  let starts : Array[Int32] = []
  for index = 0; index < document.events.length(); index = index + 1 {
    let event = document.events[index]
    match event.kind {
      StartElement(_, _, _) => {
        if starts.length() >= max_depth {
          raise Invalid(event.offset, "pretty XML nesting exceeds max_depth")
        }
        starts.push(index)
      }
      EndElement(_, _) => starts.pop() |> ignore
      Text(_, _) =>
        match starts.last() {
          Some(start) => text_parents[start] = true
          None => ()
        }
      _ => ()
    }
  }
  text_parents
}

///|
fn render_normal_uri(uri : String?) -> String? {
  match uri {
    Some("") => None
    _ => uri
  }
}

///|
fn render_binding(
  bindings : RenderNamespaces,
  prefix : String,
) -> RenderBinding? {
  match bindings.stacks.get(prefix) {
    Some(stack) => stack.last()
    None => None
  }
}

///|
fn render_effective_remove(
  bindings : RenderNamespaces,
  binding : RenderBinding,
) -> Unit {
  let prefixes = bindings.prefixes[binding.uri]
  let index = bindings.positions[(binding.uri, binding.prefix)]
  match prefixes.pop() {
    Some(last) if index < prefixes.length() => {
      prefixes[index] = last
      bindings.positions[(binding.uri, last)] = index
    }
    _ => ()
  }
  bindings.positions.remove((binding.uri, binding.prefix))
  if prefixes.is_empty() {
    bindings.prefixes.remove(binding.uri)
  }
}

///|
fn render_effective_add(
  bindings : RenderNamespaces,
  binding : RenderBinding,
) -> Unit {
  let prefixes = bindings.prefixes.get_or_init(binding.uri, fn() { [] })
  bindings.positions[(binding.uri, binding.prefix)] = prefixes.length()
  prefixes.push(binding.prefix)
}

///|
fn render_push_binding(
  bindings : RenderNamespaces,
  binding : RenderBinding,
) -> Unit {
  let stack = bindings.stacks.get_or_init(binding.prefix, fn() { [] })
  if stack.last() is Some(previous) {
    render_effective_remove(bindings, previous)
  }
  stack.push(binding)
  render_effective_add(bindings, binding)
}

///|
fn render_pop_binding(
  bindings : RenderNamespaces,
  binding : RenderBinding,
) -> Unit {
  let stack = bindings.stacks[binding.prefix]
  render_effective_remove(bindings, binding)
  stack.pop() |> ignore
  match stack.last() {
    Some(previous) => render_effective_add(bindings, previous)
    None => bindings.stacks.remove(binding.prefix)
  }
}

///|
fn render_lookup_prefix(
  bindings : RenderNamespaces,
  uri : String,
  attribute : Bool,
) -> String? {
  if uri == "http://www.w3.org/XML/1998/namespace" {
    return Some("xml")
  }
  match bindings.prefixes.get(uri) {
    Some(prefixes) if !prefixes.is_empty() => {
      let prefix = prefixes[prefixes.length() - 1]
      if !attribute || prefix != "" {
        Some(prefix)
      } else if prefixes.length() > 1 {
        Some(prefixes[0])
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn render_qualified(
  bindings : RenderNamespaces,
  declarations : Array[RenderBinding],
  uri : String?,
  name : String,
  attribute : Bool,
  depth : Int32,
  offset : Int32,
) -> String raise DecodeError {
  render_check_name(name, offset)
  match render_normal_uri(uri) {
    None => {
      if !attribute {
        match render_binding(bindings, "") {
          Some(current) if current.uri != "" => {
            if current.depth == depth {
              raise Invalid(
                offset, "namespace-less element conflicts with its default namespace",
              )
            }
            let binding = {
              prefix: "",
              uri: "",
              depth,
              explicit: false,
              used: true,
            }
            render_push_binding(bindings, binding)
            declarations.push(binding)
          }
          _ => ()
        }
      } else if name == "xmlns" {
        raise Invalid(
          offset, "xmlns must be a namespace event, not an attribute",
        )
      }
      name
    }
    Some(namespace_uri) => {
      if namespace_uri == "http://www.w3.org/2000/xmlns/" {
        raise Invalid(offset, "reserved xmlns namespace")
      }
      match render_lookup_prefix(bindings, namespace_uri, attribute) {
        Some("") => name
        Some(prefix) => prefix + ":" + name
        None => {
          // Attribute names never inherit the default namespace. Give an
          // otherwise unbound expanded name an explicit, local prefix.
          let mut prefix = "ns" + bindings.serial.to_string()
          while render_binding(bindings, prefix) is Some(_) {
            bindings.serial = bindings.serial + 1
            prefix = "ns" + bindings.serial.to_string()
          }
          bindings.serial = bindings.serial + 1
          let binding = {
            prefix,
            uri: namespace_uri,
            depth,
            explicit: false,
            used: true,
          }
          render_push_binding(bindings, binding)
          declarations.push(binding)
          prefix + ":" + name
        }
      }
    }
  }
}

///|
/// Render a namespace-aware document as XML 1.0. The output limit also bounds
/// repeated references to long string-pool entries; it counts UTF-16 units.
pub fn to_xml(
  document : Document,
  max_output_chars~ : Int32 = 32 * 1024 * 1024,
) -> String raise DecodeError {
  render_xml(document, max_output_chars, false, 256)
}

///|
/// Render XML with two-space indentation and LF line endings between elements.
/// Subtrees containing direct text, including whitespace/empty CDATA events,
/// and xml:space="preserve" subtrees retain compact rendering throughout.
/// Added indentation counts toward the UTF-16 output budget. Depth is checked
/// before formatting even for manually constructed documents.
pub fn to_xml_pretty(
  document : Document,
  max_output_chars~ : Int32 = 32 * 1024 * 1024,
  max_depth~ : Int32 = 256,
) -> String raise DecodeError {
  if max_depth <= 0 {
    raise Invalid(0, "pretty XML depth limit must be positive")
  }
  render_xml(document, max_output_chars, true, max_depth)
}

///|
fn render_xml(
  document : Document,
  max_output_chars : Int32,
  pretty : Bool,
  max_depth : Int32,
) -> String raise DecodeError {
  if max_output_chars <= 0 {
    raise Invalid(0, "XML output limit must be positive")
  }
  let text_parents = if pretty {
    render_text_parents(document, max_depth)
  } else {
    Map([])
  }
  let output : RenderOutput = {
    builder: StringBuilder(),
    limit: max_output_chars,
    size: 0,
    offset: 0,
  }
  let bindings : RenderNamespaces = {
    stacks: Map([]),
    prefixes: Map([]),
    positions: Map([]),
    serial: 0,
  }
  let elements : Array[RenderElement] = []
  let pending : Array[RenderBinding] = []
  let mut roots = 0
  let mut closing = 0
  for event_index = 0
      event_index < document.events.length()
      event_index = event_index + 1 {
    let event = document.events[event_index]
    output.offset = event.offset
    let depth = elements.length()
    match event.kind {
      StartNamespace(prefix, uri) => {
        if closing > 0 {
          raise Invalid(
            event.offset,
            "namespace scope must close before another declaration",
          )
        }
        let prefix = prefix.unwrap_or("")
        if prefix != "" {
          render_check_name(prefix, event.offset)
        }
        if prefix == "xmlns" ||
          uri == "http://www.w3.org/2000/xmlns/" ||
          (prefix == "xml" && uri != "http://www.w3.org/XML/1998/namespace") ||
          (prefix != "xml" && uri == "http://www.w3.org/XML/1998/namespace") ||
          (prefix != "" && uri == "") {
          raise Invalid(event.offset, "invalid reserved namespace binding")
        }
        match render_binding(bindings, prefix) {
          Some(binding) if binding.depth == depth =>
            raise Invalid(
              event.offset,
              "namespace scope is not closed or has a duplicate prefix",
            )
          _ => ()
        }
        let binding = { prefix, uri, depth, explicit: true, used: false, }
        render_push_binding(bindings, binding)
        pending.push(binding)
      }
      EndNamespace(prefix, uri) => {
        if !pending.is_empty() || closing == 0 {
          raise Invalid(event.offset, "namespace ended before its element")
        }
        match render_binding(bindings, prefix.unwrap_or("")) {
          Some(binding) => {
            if !binding.explicit ||
              !binding.used ||
              binding.depth != depth ||
              binding.uri != uri {
              raise Invalid(
                event.offset,
                "namespace end does not match its scope",
              )
            }
            render_pop_binding(bindings, binding)
            closing = closing - 1
          }
          None =>
            raise Invalid(event.offset, "namespace end has no matching start")
        }
      }
      StartElement(uri, name, attributes) => {
        if depth == 0 {
          roots = roots + 1
          if roots > 1 {
            raise Invalid(event.offset, "XML requires one root element")
          }
        }
        if closing > 0 {
          raise Invalid(
            event.offset,
            "namespace end is missing before a sibling element",
          )
        }
        let declarations : Array[RenderBinding] = []
        for binding in pending {
          binding.used = true
          declarations.push(binding)
        }
        pending.clear()
        let qualified = render_qualified(
          bindings,
          declarations,
          uri,
          name,
          false,
          depth,
          event.offset,
        )
        let rendered_attributes : Array[String] = []
        let mut attribute_size = 0
        let mut preserve_space = false
        let seen_attributes : Map[(String?, String), Bool] = Map([])
        for attribute in attributes {
          let key = (render_normal_uri(attribute.namespace_uri), attribute.name)
          if seen_attributes.contains(key) {
            raise Invalid(event.offset, "duplicate expanded attribute name")
          }
          seen_attributes[key] = true
          let attr_name = render_qualified(
            bindings,
            declarations,
            attribute.namespace_uri,
            attribute.name,
            true,
            depth,
            event.offset,
          )
          let text = render_attribute_text(attribute, event.offset)
          if attribute.namespace_uri ==
            Some("http://www.w3.org/XML/1998/namespace") &&
            attribute.name == "space" &&
            text == "preserve" {
            preserve_space = true
          }
          let value = render_escape(text, true, event.offset)
          let rendered = " " + attr_name + "=\"" + value + "\""
          if rendered.length() > max_output_chars - attribute_size {
            raise Invalid(event.offset, "XML output exceeds configured limit")
          }
          attribute_size = attribute_size + rendered.length()
          rendered_attributes.push(rendered)
        }
        let parent_pretty = match elements.last() {
          Some(parent) => {
            parent.has_children = true
            if parent.pretty_children {
              output.write_indent(depth)
            }
            parent.pretty_children
          }
          None => true
        }
        output.write_string("<" + qualified)
        for binding in declarations {
          let suffix = if binding.prefix == "" {
            ""
          } else {
            ":" + binding.prefix
          }
          output.write_string(
            " xmlns" +
            suffix +
            "=\"" +
            render_escape(binding.uri, true, event.offset) +
            "\"",
          )
        }
        for attribute in rendered_attributes {
          output.write_string(attribute)
        }
        output.write_string(">")
        elements.push({
          uri: render_normal_uri(uri),
          name,
          qualified,
          declarations,
          pretty_children: pretty &&
          parent_pretty &&
          !text_parents.contains(event_index) &&
          !preserve_space,
          has_children: false,
        })
      }
      EndElement(uri, name) => {
        if !pending.is_empty() || closing > 0 {
          raise Invalid(event.offset, "unused namespace declaration")
        }
        match elements.pop() {
          Some(element) => {
            if element.uri != render_normal_uri(uri) || element.name != name {
              raise Invalid(event.offset, "mismatched end element")
            }
            if element.pretty_children && element.has_children {
              output.write_indent(elements.length())
            }
            output.write_string("</" + element.qualified + ">")
            for binding in element.declarations {
              if binding.explicit {
                closing = closing + 1
              } else {
                render_pop_binding(bindings, binding)
              }
            }
          }
          None =>
            raise Invalid(event.offset, "end element has no matching start")
        }
      }
      Text(text, _) => {
        if !pending.is_empty() || closing > 0 {
          raise Invalid(
            event.offset,
            "text between namespace declaration and element",
          )
        }
        if depth == 0 {
          for char in text.iter() {
            if char != ' ' && char != '\t' && char != '\n' && char != '\r' {
              raise Invalid(event.offset, "text outside root element")
            }
          }
        }
        output.write_string(render_escape(text, false, event.offset))
      }
    }
  }
  if roots != 1 ||
    !elements.is_empty() ||
    !bindings.stacks.is_empty() ||
    !pending.is_empty() {
    raise Invalid(0, "incomplete XML document or namespace scope")
  }
  output.builder.to_string()
}
