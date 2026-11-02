import test from "node:test";
import assert from "node:assert/strict";
import { clampPage, filterEvents, filterReferences, hexValue, sourceEventPage } from "../src/table-filter.ts";
import type { EventSummary, ResourceUsage } from "../src/protocol.ts";

function event(index: number, name = "item"): EventSummary {
  return { index, name, offset: 256 + index * 32, line_number: index + 1, kind: "StartElement",
    namespace_uri: "http://schemas.android.com/apk/res/android", attribute_count: 1, text_utf16_units: 0 };
}

test("event search is literal, case-insensitive, and keeps Unicode names and original order", () => {
  const events = [event(9, "Main.Activity"), event(3, "月亮"), event(7, "main.receiver")];
  const original = structuredClone(events);
  assert.deepEqual(filterEvents(events, "  MAIN.  "), [events[0], events[2]]);
  assert.deepEqual(filterEvents(events, "月亮"), [events[1]]);
  assert.deepEqual(filterEvents(events, ".*"), []);
  assert.deepEqual(filterEvents(events, "   "), events);
  assert.deepEqual(events, original);
});

test("event search covers protocol kind namespace and decimal or uppercase hex byte offsets", () => {
  const events = [event(0), { ...event(1), kind: "Text" as const, name: null, namespace_uri: null }];
  assert.deepEqual(filterEvents(events, "startelement"), [events[0]]);
  assert.deepEqual(filterEvents(events, "schemas.android"), [events[0]]);
  assert.deepEqual(filterEvents(events, "256"), [events[0]]);
  assert.deepEqual(filterEvents(events, "0X00000120"), [events[1]]);
  assert.deepEqual(filterEvents(events, "text"), [events[1]]);
});

test("reference search covers typed kinds unsigned IDs and both forms of source offset", () => {
  const references: ResourceUsage[] = [
    { offset: 1024, line_number: 1, origin: ["Attribute", null, "label"], reference: ["Resource", 0xff010002] },
    { offset: 2048, line_number: 2, origin: "Text", reference: ["DynamicThemeAttribute", 0x01010003] },
  ];
  const original = structuredClone(references);
  assert.equal(hexValue(0xff010002), "0xff010002");
  for (const query of ["0XFF010002", "4278255618", "1024", "0X00000400"]) {
    assert.deepEqual(filterReferences(references, query), [references[0]]);
  }
  assert.deepEqual(filterReferences(references, "dynamictheme"), [references[1]]);
  assert.deepEqual(filterReferences(references, "text"), [references[1]]);
  assert.deepEqual(filterReferences(references, "  "), references);
  assert.deepEqual(references, original);
});

test("reference search handles namespaced unqualified and text origins without flattening tuples", () => {
  const references: ResourceUsage[] = [
    { offset: 10, line_number: 1, origin: ["Attribute", ["urn:Example:安卓"], "Theme.Color"], reference: ["ThemeAttribute", 1] },
    { offset: 20, line_number: 2, origin: ["Attribute", null, "label"], reference: ["Resource", 2] },
    { offset: 30, line_number: 3, origin: "Text", reference: ["Resource", 3] },
  ];
  assert.deepEqual(filterReferences(references, "URN:EXAMPLE"), [references[0]]);
  assert.deepEqual(filterReferences(references, "安卓"), [references[0]]);
  assert.deepEqual(filterReferences(references, "theme.color"), [references[0]]);
  assert.deepEqual(filterReferences(references, "{urn:example:安卓}theme.color"), [references[0]]);
  assert.deepEqual(filterReferences(references, "LABEL"), [references[1]]);
  assert.deepEqual(filterReferences(references, "attribute"), [references[0], references[1]]);
  assert.deepEqual(filterReferences(references, "theme.*"), []);
});

test("source jumps use original preview positions across page boundaries and stay bounded", () => {
  const preview = Array.from({ length: 1000 }, (_, index) => event(index, index >= 50 ? "target" : "other"));
  const filtered = filterEvents(preview, "target");
  assert.equal(filtered.length, 950);
  assert.equal(filtered[0]?.index, 50);
  assert.equal(sourceEventPage(preview, preview[49]!.offset, 50), 0);
  assert.equal(sourceEventPage(preview, preview[50]!.offset, 50), 1);
  assert.equal(sourceEventPage(preview, preview[999]!.offset, 50), 19);
  assert.equal(sourceEventPage(preview, event(1000).offset, 50), null);
  assert.equal(filterEvents(preview, "missing").length, 0);
  assert.equal(preview.length, 1000);
});

test("pagination clamps shrinking and empty result sets without creating a negative page", () => {
  assert.equal(clampPage(1, 100, 50), 1);
  assert.equal(clampPage(3, 51, 50), 1);
  assert.equal(clampPage(3, 50, 50), 0);
  assert.equal(clampPage(3, 0, 50), 0);
  assert.equal(clampPage(-1, 100, 50), 0);
});
