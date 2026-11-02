///|
fn browser_error(stage : String, offset : Int32, message : String) -> Json {
  { "stage": stage, "offset": offset, "message": message }
}

///|
fn browser_failure(stage : String, offset : Int32, message : String) -> Json {
  { "ok": false, "error": browser_error(stage, offset, message) }
}

///|
fn browser_success(value : Json) -> Json {
  { "ok": true, "value": value }
}

///|
fn browser_event_summary(event : @axml.Event, index : Int32) -> Json {
  let (kind, namespace_uri, name, attribute_count, text_utf16_units) = match
    event.kind {
    @axml.StartNamespace(prefix, uri) =>
      ("StartNamespace", Some(uri), prefix, 0, 0)
    @axml.EndNamespace(prefix, uri) => ("EndNamespace", Some(uri), prefix, 0, 0)
    @axml.StartElement(uri, name, attributes) =>
      ("StartElement", uri, Some(name), attributes.length(), 0)
    @axml.EndElement(uri, name) => ("EndElement", uri, Some(name), 0, 0)
    @axml.Text(text, _) => ("Text", None, None, 0, text.length())
  }
  {
    "index": index,
    "offset": event.offset,
    "line_number": Json(event.line_number),
    "kind": kind,
    "namespace_uri": match namespace_uri {
      Some(uri) => Json(uri)
      None => Json::null()
    },
    "name": match name {
      Some(name) => Json(name)
      None => Json::null()
    },
    "attribute_count": attribute_count,
    "text_utf16_units": text_utf16_units,
  }
}

///|
/// Browser/Worker boundary: Bytes maps directly to JavaScript Uint8Array.
/// Decode once and return a JSON envelope with independently reported views.
/// No filesystem, network, Node.js globals, or document state is retained.
#export_name("analyze_bytes")
pub fn analyze_bytes(data : Bytes) -> String {
  let document = @axml.decode(data) catch {
    @axml.Invalid(offset, message) => {
      let response : Json = {
        "schema_version": 1,
        "ok": false,
        "input_bytes": data.length(),
        "error": browser_error("decode", offset, message),
      }
      return response.stringify()
    }
  }
  let xml_limit = 2 * 1024 * 1024
  let xml : Map[String, Json] = { "limit_utf16_units": Json(xml_limit) }
  try {
    xml["value"] = Json(@axml.to_xml(document, max_output_chars=xml_limit))
    xml["ok"] = Json(true)
  } catch {
    @axml.Invalid(offset, message) => {
      xml["ok"] = Json(false)
      xml["error"] = browser_error("xml", offset, message)
    }
  }
  let manifest = browser_success(@axml.inspect_manifest(document).to_json()) catch {
    @axml.Invalid(offset, message) =>
      browser_failure("manifest", offset, message)
  }
  let intents = browser_success(Json(@axml.inspect_intent_filters(document))) catch {
    @axml.Invalid(offset, message) =>
      browser_failure("intents", offset, message)
  }
  let event_limit = 1000
  let preview_count = if document.events.length() < event_limit {
    document.events.length()
  } else {
    event_limit
  }
  let events : Json = {
    "total": document.events.length(),
    "preview": Json(
      Array::makei(preview_count, fn(index) {
        browser_event_summary(document.events[index], index)
      }),
    ),
    "truncated": document.events.length() > event_limit,
    "limit": event_limit,
  }
  let response : Json = {
    "schema_version": 1,
    "ok": true,
    "input_bytes": data.length(),
    "stats": document.stats().to_json(),
    "references": Json(document.resource_references()),
    "events": events,
    "xml": Json(xml),
    "manifest": manifest,
    "intents": intents,
  }
  response.stringify()
}
