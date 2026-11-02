#!/usr/bin/env node
// Node is the test host only; the compiled ESM executes without Node globals.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import * as vm from "node:vm";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const args = process.argv.slice(2);
assert(args.length === 0 || (args.length === 2 && args[0] === "--artifact"), "expected optional --artifact PATH");
const artifact = resolve(root, args[1] ?? "_build/js/release/build/browser/browser.js");
assert.equal(typeof vm.SourceTextModule, "function", "run Node with --experimental-vm-modules");
const source = await readFile(artifact, "utf8");
assert(!/\brequire\s*\(|\bprocess\b|\bBuffer\b|["']node:/.test(source), "browser artifact contains a Node dependency");
const sandbox = vm.createContext({});
assert.equal(vm.runInContext("typeof process + ':' + typeof require + ':' + typeof Buffer", sandbox), "undefined:undefined:undefined");
const compiled = new vm.SourceTextModule(source, { context: sandbox, identifier: "axml-browser" });
assert.deepEqual(compiled.dependencySpecifiers, [], "browser artifact must be self-contained");
await compiled.link(() => { throw new Error("unexpected browser import"); });
await compiled.evaluate();
const analyze = (bytes) => JSON.parse(compiled.namespace.analyze_bytes(bytes));
const fixture = async (name) => new Uint8Array(await readFile(resolve(root, "fixtures/valid", `${name}.axml`)));
const checkError = (value, stage) => {
  assert.equal(value.stage, stage);
  assert(Number.isInteger(value.offset) && value.offset >= 0);
  assert.equal(typeof value.message, "string");
  assert(value.message.length > 0);
};
const menuBytes = await fixture("menu");
const menu = analyze(menuBytes);
assert.equal(menu.schema_version, 1);
assert.equal(menu.ok, true);
assert.equal(menu.input_bytes, 644);
assert.equal(menu.xml.ok, true);
assert.equal(menu.xml.limit_utf16_units, 2 * 1024 * 1024);
assert.match(menu.xml.value, /^<menu /);
assert.equal(menu.manifest.ok, false);
assert.equal(menu.intents.ok, false);
checkError(menu.manifest.error, "manifest");
checkError(menu.intents.error, "intents");
assert.deepEqual(menu.stats, { strings: 11, string_utf16_units: "108", resource_ids: 6, events: 8,
  start_elements: 3, attributes: "8", text_events: 0, namespace_declarations: 1, max_depth: 2 });
assert.deepEqual(menu.references.map(({ reference }) => reference), [
  ["Resource", 0x01080033], ["Resource", 0x7f010000], ["Resource", 0x7f010001], ["Resource", 0x7f030000],
]);
assert.deepEqual(menu.events.preview.map(({ index }) => index), Array.from({ length: 8 }, (_, index) => index));
assert.deepEqual(menu.events.preview[0], { index: 0, offset: 256, line_number: 2,
  kind: "StartNamespace", namespace_uri: "http://schemas.android.com/apk/res/android", name: "android",
  attribute_count: 0, text_utf16_units: 0 });
assert.deepEqual(menu.events.preview[2], { index: 2, offset: 316, line_number: 3,
  kind: "StartElement", namespace_uri: null, name: "item", attribute_count: 4, text_utf16_units: 0 });

const basic = analyze(await fixture("manifest_basic"));
assert.equal(basic.ok, true);
assert.equal(basic.xml.ok, true);
assert.equal(basic.manifest.ok, true);
assert.equal(basic.manifest.value.package_name, "org.example.axml.basic");
assert.equal(basic.intents.ok, true);
assert.equal(basic.intents.value.length, 1);
assert.equal(basic.intents.value[0].component_kind, "activity");
const references = analyze(await fixture("manifest_references"));
assert.equal(references.manifest.ok, true);
assert(references.references.length >= 3);
assert(references.references.every(({ offset, line_number }) => offset >= 0 && line_number > 0));
const unicode = analyze(await fixture("synthetic_utf8"));
assert(unicode.xml.value.includes("𠀀"));
const textEvent = unicode.events.preview.find(({ kind }) => kind === "Text");
assert.equal(textEvent.text_utf16_units, 13);
assert.equal(textEvent.name, null);
assert.equal(textEvent.namespace_uri, null);

const padded = new Uint8Array(menuBytes.length + 17).fill(0xaa);
padded.set(menuBytes, 9);
const sliced = padded.subarray(9, 9 + menuBytes.length);
assert(sliced.byteOffset > 0);
assert.deepEqual(analyze(sliced), menu, "Uint8Array byteOffset/length must be respected");
assert.deepEqual(padded.subarray(0, 9), new Uint8Array(9).fill(0xaa), "input must remain unchanged");

let invalidCount = 0;
const manifest = JSON.parse(await readFile(resolve(root, "fixtures/manifest.json"), "utf8"));
for (const item of manifest.fixtures.filter(({ valid }) => !valid)) {
  const report = analyze(new Uint8Array(await readFile(resolve(root, item.path))));
  assert.equal(report.ok, false);
  assert.equal(report.schema_version, 1);
  checkError(report.error, "decode");
  assert.equal(report.xml, undefined, "decode failure must not produce partial views");
  invalidCount++;
}
assert.deepEqual(analyze(menuBytes), menu, "prior failures must not affect the next result");

// Independent small AOSP chunk builder for preview and XML budget boundaries.
const join = (...parts) => {
  const bytes = new Uint8Array(parts.reduce((size, part) => size + part.length, 0));
  let offset = 0;
  for (const part of parts) { bytes.set(part, offset); offset += part.length; }
  return bytes;
};
const u16 = (value) => Uint8Array.of(value & 255, (value >>> 8) & 255);
const u32 = (value) => join(u16(value), u16(value >>> 16));
const chunk = (kind, header, payload) => join(u16(kind), u16(header), u32(8 + payload.length), payload);
const length = (size) => size < 128 ? Uint8Array.of(size) : Uint8Array.of((size >>> 8) | 128, size & 255);
const node = (kind, payload) => chunk(kind, 16, join(u32(1), u32(0xffffffff), payload));
const repeatedDocument = (count, value) => {
  const strings = ["root", "item", "value", value];
  const entries = strings.map((text) => { const utf8 = new TextEncoder().encode(text); return join(length(text.length), length(utf8.length), utf8, Uint8Array.of(0)); });
  const offsets = []; let offset = 0;
  for (const entry of entries) { offsets.push(u32(offset)); offset += entry.length; }
  const text = join(...entries, new Uint8Array((4 - offset % 4) % 4));
  const pool = chunk(1, 28, join(u32(4), u32(0), u32(0x100), u32(44), u32(0), ...offsets, text));
  const start = (name, attributes = []) => node(0x102, join(u32(0xffffffff), u32(name), u16(20), u16(20), u16(attributes.length), u16(0), u16(0), u16(0), ...attributes));
  const end = (name) => node(0x103, join(u32(0xffffffff), u32(name)));
  const attribute = join(u32(0xffffffff), u32(2), u32(3), u16(8), Uint8Array.of(0, 3), u32(3));
  return chunk(3, 8, join(pool, start(0), ...Array.from({ length: count }, () => join(start(1, [attribute]), end(1))), end(0)));
};
const exact = analyze(repeatedDocument(499, "x"));
assert.equal(exact.events.total, 1000);
assert.equal(exact.events.preview.length, 1000);
assert.equal(exact.events.truncated, false);
const large = analyze(repeatedDocument(600, "x".repeat(4096)));
assert.equal(large.ok, true);
assert.equal(large.xml.ok, false);
checkError(large.xml.error, "xml");
assert.match(large.xml.error.message, /configured limit/);
assert.equal(large.xml.limit_utf16_units, 2097152);
assert.equal(large.events.total, 1202);
assert.equal(large.events.preview.length, 1000);
assert.equal(large.events.truncated, true);
assert.equal(large.events.limit, 1000);
assert.equal(large.stats.attributes, "600");
assert.equal(JSON.stringify(large.events).includes("x".repeat(4096)), false, "event summaries must not repeat string payloads");
assert.equal(large.manifest.ok, false);
assert.equal(large.intents.ok, false);
const invalidXml = analyze(repeatedDocument(1, "\u0001"));
assert.equal(invalidXml.ok, true, "binary success is distinct from XML rendering success");
assert.equal(invalidXml.xml.ok, false);
checkError(invalidXml.xml.error, "xml");
assert.match(invalidXml.xml.error.message, /forbidden by XML/);
assert.equal(invalidXml.stats.attributes, "1");
const oversized = analyze(new Uint8Array(16 * 1024 * 1024 + 1));
assert.equal(oversized.ok, false);
checkError(oversized.error, "decode");
assert.equal(oversized.error.offset, 0);
assert.match(oversized.error.message, /max_input_bytes/);
console.log(`PASS: browser ESM sandbox; menu/basic/references/unicode; sliced Uint8Array; ${invalidCount} malformed fixtures; 1000-event boundary; XML preview limit; no Node dependencies.`);
