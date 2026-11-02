import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { mkdtemp } from "node:fs/promises";
import path from "node:path";
import { moonBuildInvocation, ROOT } from "../scripts/prepare.mjs";
import { analyzeBuffer, handleAnalysisRequest } from "../src/worker.ts";
import { unwrapMoonOption } from "../src/protocol.ts";
import type { SampleIndex } from "../src/protocol.ts";

const samplesDir = new URL("../public/samples/", import.meta.url);
async function sample(filename: string): Promise<ArrayBuffer> {
  const bytes = await readFile(new URL(filename, samplesDir));
  return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
}

test("public Windows builds do not require the maintainer's registry identity", async () => {
  const userProfile = await mkdtemp(path.join(ROOT, "_build/contributor-profile-"));
  const invocation = await moonBuildInvocation({ platform: "win32", userProfile, override: "" });
  assert.equal(invocation.command, "moon");
  assert.deepEqual(invocation.args, ["build", "src/browser", "--target", "js", "--release", "--deny-warn"]);
});

test("prepare pipeline copies six actual owned fixtures with their recorded SHA-256", async () => {
  const index: SampleIndex = JSON.parse(await readFile(new URL("index.json", samplesDir), "utf8"));
  assert.equal(index.schema_version, 1);
  assert.equal(index.samples.length, 6);
  for (const record of index.samples) {
    const bytes = await readFile(new URL(record.filename, samplesDir));
    assert.equal(bytes.length, record.bytes);
    assert.equal(createHash("sha256").update(bytes).digest("hex"), record.sha256);
  }
  const declarations = await readFile(fileURLToPath(new URL("../src/generated/browser.d.ts", import.meta.url)), "utf8");
  assert.match(declarations, /analyze_bytes/);
});

test("actual compiled MoonBit bridge handles manifests resources Unicode and malformed input", async () => {
  const basic = analyzeBuffer(await sample("manifest_basic.axml"));
  assert.equal(basic.ok, true);
  if (!basic.ok) return;
  assert.equal(basic.manifest.ok, true);
  if (basic.manifest.ok) {
    assert.equal(basic.manifest.value.package_name, "org.example.axml.basic");
    assert.equal(basic.manifest.value.components.length, 4);
    assert.equal(typeof unwrapMoonOption(basic.manifest.value.version_name)?.value.data_type, "number");
  }
  assert.equal(basic.xml.ok, true);
  assert.equal(typeof basic.stats.attributes, "string");
  assert.equal(basic.events.preview.length, basic.events.total);
  const menu = analyzeBuffer(await sample("menu.axml"));
  assert.equal(menu.ok, true);
  if (menu.ok) {
    assert.equal(menu.references.length, 4);
    assert.equal(menu.manifest.ok, false);
    assert.equal(menu.xml.ok, true);
  }
  const utf16 = analyzeBuffer(await sample("synthetic_utf16.axml"));
  assert.equal(utf16.ok && utf16.xml.ok, true);
  if (utf16.ok && utf16.xml.ok) assert.match(utf16.xml.value, /月亮/);
  const invalid = handleAnalysisRequest({ type: "analyze", taskId: 7, buffer: await sample("truncated_header.axml") });
  assert.equal(invalid.type, "result");
  if (invalid.type === "result") {
    assert.equal(invalid.taskId, 7);
    assert.equal(invalid.report.ok, false);
    if (!invalid.report.ok) assert.equal(invalid.report.error.stage, "decode");
  }
});
