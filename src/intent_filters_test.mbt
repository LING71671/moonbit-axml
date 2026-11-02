///|
fn intents_attribute(
  namespace_uri : String?,
  name : String,
  value : String,
) -> @axml.Attribute {
  {
    namespace_uri,
    name,
    resource_id: None,
    raw_value: Some(value),
    value: { data_type: 3, data: 0U, string_value: Some(value), },
  }
}

///|
fn intents_android(name : String, value : String) -> @axml.Attribute {
  intents_attribute(
    Some("http://schemas.android.com/apk/res/android"),
    name,
    value,
  )
}

///|
fn intents_event(kind : @axml.EventKind, offset~ : Int32 = 12) -> @axml.Event {
  { kind, offset, line_number: 42U, }
}

///|
fn intents_start(
  name : String,
  attributes~ : Array[@axml.Attribute] = [],
) -> @axml.Event {
  intents_event(@axml.StartElement(None, name, attributes))
}

///|
fn intents_end(name : String) -> @axml.Event {
  intents_event(@axml.EndElement(None, name))
}

///|
fn intents_document(body : Array[@axml.Event]) -> @axml.Document {
  let events = [
    intents_event(
      @axml.StartNamespace(
        Some("android"),
        "http://schemas.android.com/apk/res/android",
      ),
    ),
    intents_event(@axml.StartNamespace(Some("ext"), "urn:extension")),
    intents_start("manifest", attributes=[
      intents_attribute(None, "package", "example.app"),
    ]),
    intents_start("application"),
  ]
  events.append(body)
  events.append([
    intents_end("application"),
    intents_end("manifest"),
    intents_event(@axml.EndNamespace(Some("ext"), "urn:extension")),
    intents_event(
      @axml.EndNamespace(
        Some("android"),
        "http://schemas.android.com/apk/res/android",
      ),
    ),
  ])
  { strings: [], resource_ids: [], events, }
}

///|
test "intent filters preserve locations component names and filter attributes" {
  let component_name = intents_android("name", ".MainActivity")
  let priority = intents_android("priority", "12")
  let document = intents_document([
    intents_start("activity", attributes=[component_name]),
    intents_event(
      @axml.StartElement(None, "intent-filter", [priority]),
      offset=88,
    ),
    intents_end("intent-filter"),
    intents_end("activity"),
  ])
  let filters = @axml.inspect_intent_filters(document)
  assert_eq(filters.length(), 1)
  assert_eq(filters[0].component_kind, "activity")
  assert_eq(filters[0].component_name, Some(component_name))
  assert_eq(filters[0].offset, 88)
  assert_eq(filters[0].line_number, 42U)
  assert_eq(filters[0].attributes, [priority])
  assert_eq(filters[0].actions, [])
  assert_eq(filters[0].categories, [])
  assert_eq(filters[0].data, [])
}

///|
test "intent filters retain all supported component kinds and declaration order" {
  let body : Array[@axml.Event] = []
  for kind in ["activity", "activity-alias", "service", "receiver"] {
    body.append([
      intents_start(kind),
      intents_start("intent-filter"),
      intents_end("intent-filter"),
      intents_start("intent-filter"),
      intents_end("intent-filter"),
      intents_end(kind),
    ])
  }
  let filters = @axml.inspect_intent_filters(intents_document(body))
  assert_eq(filters.map(fn(filter) { filter.component_kind }), [
    "activity", "activity", "activity-alias", "activity-alias", "service", "service",
    "receiver", "receiver",
  ])
  assert_eq(filters[0].component_name, None)
}

///|
test "intent action and category arrays preserve order duplicates and typed references" {
  let first = intents_android("name", "android.intent.action.VIEW")
  let second = intents_android("name", "android.intent.action.SEND")
  let reference : @axml.Attribute = {
    ..intents_android("name", "raw.symbolic.text"),
    value: { data_type: 1, data: 0x7f010001U, string_value: None, },
  }
  let category = intents_android("name", "android.intent.category.BROWSABLE")
  let document = intents_document([
    intents_start("service", attributes=[reference]),
    intents_start("intent-filter"),
    intents_start("action", attributes=[first]),
    intents_end("action"),
    intents_start("category", attributes=[category]),
    intents_end("category"),
    intents_start("action", attributes=[second]),
    intents_end("action"),
    intents_start("action", attributes=[first]),
    intents_end("action"),
    intents_start("category", attributes=[reference]),
    intents_end("category"),
    intents_end("intent-filter"),
    intents_end("service"),
  ])
  let filter = @axml.inspect_intent_filters(document)[0]
  assert_eq(filter.actions, [first, second, first])
  assert_eq(filter.categories, [category, reference])
  assert_eq(filter.component_name, Some(reference))
  assert_true(filter.has_action("android.intent.action.VIEW"))
  assert_true(filter.has_category("android.intent.category.BROWSABLE"))
  assert_false(filter.has_category("raw.symbolic.text"))
  assert_false(filter.has_action("android.intent.action.view"))
  assert_false(filter.has_action(""))
}

///|
test "intent data declarations retain empty records raw values and namespace attributes" {
  let scheme = intents_android("scheme", "https")
  let mime_type = intents_android("mimeType", "image/*")
  let extension = intents_attribute(Some("urn:extension"), "host", "other")
  let document = intents_document([
    intents_start("receiver"),
    intents_start("intent-filter"),
    intents_start("data", attributes=[scheme, extension]),
    intents_end("data"),
    intents_start("data"),
    intents_end("data"),
    intents_start("data", attributes=[mime_type]),
    intents_end("data"),
    intents_end("intent-filter"),
    intents_end("receiver"),
  ])
  let filter = @axml.inspect_intent_filters(document)[0]
  assert_eq(filter.data, [[scheme, extension], [], [mime_type]])
}

///|
test "intent inspection excludes providers wrappers and nested filter children" {
  let hidden = intents_android("name", "hidden")
  let document = intents_document([
    intents_start("provider"),
    intents_start("intent-filter"),
    intents_end("intent-filter"),
    intents_end("provider"),
    intents_start("wrapper"),
    intents_start("activity"),
    intents_start("intent-filter"),
    intents_end("intent-filter"),
    intents_end("activity"),
    intents_end("wrapper"),
    intents_start("activity"),
    intents_start("wrapper"),
    intents_start("intent-filter"),
    intents_end("intent-filter"),
    intents_end("wrapper"),
    intents_start("intent-filter"),
    intents_start("wrapper"),
    intents_start("action", attributes=[hidden]),
    intents_end("action"),
    intents_end("wrapper"),
    intents_end("intent-filter"),
    intents_end("activity"),
  ])
  let filters = @axml.inspect_intent_filters(document)
  assert_eq(filters.length(), 1)
  assert_eq(filters[0].actions, [])
}

///|
test "intent namespaces cannot masquerade as components filters or children" {
  let extension = Some("urn:extension")
  let hidden = intents_android("name", "hidden")
  let document = intents_document([
    intents_event(@axml.StartElement(extension, "activity", [])),
    intents_start("intent-filter"),
    intents_end("intent-filter"),
    intents_event(@axml.EndElement(extension, "activity")),
    intents_start("activity"),
    intents_event(@axml.StartElement(extension, "intent-filter", [])),
    intents_start("action", attributes=[hidden]),
    intents_end("action"),
    intents_event(@axml.EndElement(extension, "intent-filter")),
    intents_start("intent-filter"),
    intents_event(@axml.StartElement(extension, "action", [hidden])),
    intents_event(@axml.EndElement(extension, "action")),
    intents_start("action", attributes=[
      intents_attribute(None, "name", "plain"),
    ]),
    intents_end("action"),
    intents_start("category"),
    intents_end("category"),
    intents_event(@axml.StartElement(extension, "data", [hidden])),
    intents_event(@axml.EndElement(extension, "data")),
    intents_end("intent-filter"),
    intents_end("activity"),
  ])
  let filters = @axml.inspect_intent_filters(document)
  assert_eq(filters.length(), 1)
  assert_eq(filters[0].actions, [])
  assert_eq(filters[0].categories, [])
  assert_eq(filters[0].data, [])
}

///|
test "intent namespaced application and application-level filters remain outside scope" {
  let document = intents_document([
    intents_start("intent-filter"),
    intents_end("intent-filter"),
  ])
  assert_eq(@axml.inspect_intent_filters(document), [])
  let document = intents_document([])
  let events = document.events
  events[3] = intents_event(
    @axml.StartElement(Some("urn:extension"), "application", []),
  )
  events[4] = intents_event(
    @axml.EndElement(Some("urn:extension"), "application"),
  )
  events.insert(4, intents_start("activity"))
  events.insert(5, intents_start("intent-filter"))
  events.insert(6, intents_end("intent-filter"))
  events.insert(7, intents_end("activity"))
  assert_eq(@axml.inspect_intent_filters(document), [])
}

///|
test "intent filters outside application and after closed components are ignored" {
  let document = intents_document([
    intents_start("activity"),
    intents_end("activity"),
    intents_start("intent-filter"),
    intents_end("intent-filter"),
  ])
  document.events.insert(3, intents_start("intent-filter"))
  document.events.insert(4, intents_end("intent-filter"))
  assert_eq(@axml.inspect_intent_filters(document), [])
}

///|
test "intent filters keep separate declaration arrays for sibling filters" {
  let first = intents_android("name", "first")
  let second = intents_android("name", "second")
  let document = intents_document([
    intents_start("activity"),
    intents_start("intent-filter"),
    intents_start("action", attributes=[first]),
    intents_end("action"),
    intents_end("intent-filter"),
    intents_start("intent-filter"),
    intents_start("action", attributes=[second]),
    intents_end("action"),
    intents_end("intent-filter"),
    intents_end("activity"),
    intents_start("service"),
    intents_start("action", attributes=[second]),
    intents_end("action"),
    intents_end("service"),
  ])
  let filters = @axml.inspect_intent_filters(document)
  assert_eq(filters[0].actions, [first])
  assert_eq(filters[1].actions, [second])
  assert_false(filters[0].has_action("second"))
}

///|
test "intent inspection validates manually constructed manifest documents" {
  let document = intents_document([
    intents_start("activity"),
    intents_start("intent-filter"),
    intents_end("activity"),
    intents_end("intent-filter"),
  ])
  let rejected = try {
    @axml.inspect_intent_filters(document) |> ignore
    false
  } catch {
    @axml.DecodeError::Invalid(_, _) => true
  }
  assert_true(rejected)
  let document = intents_document([])
  document.events[2] = intents_start("manifest")
  let rejected = try {
    @axml.inspect_intent_filters(document) |> ignore
    false
  } catch {
    @axml.DecodeError::Invalid(_, message) =>
      message == "manifest has no package attribute"
  }
  assert_true(rejected)
}
