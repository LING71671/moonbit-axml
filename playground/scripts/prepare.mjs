import { createHash } from "node:crypto";
import { copyFile, mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath, pathToFileURL } from "node:url";

export const ROOT = path.resolve(fileURLToPath(new URL("../../", import.meta.url)));
export const ARTIFACT = path.join(ROOT, "_build/js/release/build/browser/browser.js");
export const SAMPLES = [
  ["basic", "fixtures/valid/manifest_basic.axml", "Basic manifest"],
  ["unicode", "fixtures/valid/manifest_unicode.axml", "Unicode manifest"],
  ["references", "fixtures/valid/manifest_references.axml", "Resource references"],
  ["menu", "fixtures/valid/menu.axml", "Menu XML"],
  ["utf16", "fixtures/valid/synthetic_utf16.axml", "UTF-16 string pool"],
  ["truncated", "fixtures/invalid/truncated_header.axml", "Truncated header"],
];

/** Builds are public operations; the maintainer profile is optional. */
export async function moonBuildInvocation({
  platform = process.platform,
  userProfile = process.env.USERPROFILE,
  override = process.env.MOONBIT,
} = {}) {
  const args = ["build", "src/browser", "--target", "js", "--release", "--deny-warn"];
  if (override) return { command: override, args };
  if (platform === "win32" && userProfile) {
    try {
      const credentialPath = path.join(userProfile, ".moon/profiles/LING71671/credentials.json");
      const username = JSON.parse(await readFile(credentialPath, "utf8")).username;
      if (username === "LING71671") {
        return { command: "pwsh", args: ["-NoProfile", "-File", path.join(ROOT, "scripts/moon.ps1"), ...args] };
      }
    } catch {
      // A contributor's absent/different profile must not prevent compilation.
    }
  }
  return { command: "moon", args };
}

/** Rebuild the actual MoonBit export and copy only owned, hash-verified samples. */
export async function prepareBrowser({
  build = true,
  artifact = ARTIFACT,
  generatedDir = path.join(ROOT, "playground/src/generated"),
  samplesDir = path.join(ROOT, "playground/public/samples"),
} = {}) {
  if (build) {
    const { command, args } = await moonBuildInvocation();
    const result = spawnSync(command, args, { cwd: ROOT, stdio: "inherit" });
    if (result.error) throw result.error;
    if (result.status !== 0) throw new Error(`MoonBit browser build failed (${result.status}).`);
  }
  await mkdir(generatedDir, { recursive: true });
  await mkdir(samplesDir, { recursive: true });
  for (const filename of ["browser.js", "browser.d.ts", "moonbit.d.ts"]) {
    await copyFile(path.join(path.dirname(artifact), filename), path.join(generatedDir, filename));
  }
  const manifest = JSON.parse(await readFile(path.join(ROOT, "fixtures/manifest.json"), "utf8"));
  const samples = [];
  for (const [id, source, label] of SAMPLES) {
    const entry = manifest.fixtures.find((fixture) => fixture.path === source);
    if (!entry || entry.license !== "Apache-2.0") throw new Error(`Unapproved fixture: ${source}`);
    const bytes = await readFile(path.join(ROOT, source));
    const sha256 = createHash("sha256").update(bytes).digest("hex");
    if (sha256 !== entry.sha256 || bytes.length !== entry.bytes) throw new Error(`Fixture integrity failed: ${source}`);
    const filename = path.basename(source);
    await writeFile(path.join(samplesDir, filename), bytes);
    samples.push({ id, filename, label, valid: entry.valid, bytes: bytes.length, sha256 });
  }
  const index = { schema_version: 1, samples };
  await writeFile(path.join(samplesDir, "index.json"), `${JSON.stringify(index, null, 2)}\n`);
  return index;
}

if (process.argv[1] && pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url) {
  const index = await prepareBrowser();
  console.log(`Prepared MoonBit ESM and ${index.samples.length} owned fixtures.`);
}
