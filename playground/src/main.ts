import "./style.css";
import "@fontsource/alegreya/latin-400.css";
import "@fontsource/alegreya/latin-500.css";
import "@fontsource/alegreya/latin-400-italic.css";
import { AnalysisClientError, createAnalysisClient } from "./analysis-client.ts";
import type { AnalysisError, AnalysisReport, AnalysisSuccess, Attribute, EventSummary, ResourceUsage, SampleIndex, SampleInfo } from "./protocol.ts";
import { text, type Language, type TextKey } from "./i18n.ts";

type View = "xml" | "manifest" | "structure" | "references";
const views: View[] = ["xml", "manifest", "structure", "references"];
const client = createAnalysisClient();
const $ = <T extends HTMLElement>(id: string): T => {
  const element = document.getElementById(id);
  if (!element) throw new Error(`Missing interface element: ${id}`);
  return element as T;
};
const panels = Object.fromEntries(views.map(view => [view, $(`panel-${view}`)])) as Record<View, HTMLElement>;
const fileInput = $<HTMLInputElement>("file");
const sampleSelect = $<HTMLSelectElement>("sample");
let language: Language = "en";
try { if (localStorage.getItem("moonaxml-language") === "zh") language = "zh"; } catch { /* Language persistence is optional. */ }
let activeView: View = "xml";
let report: AnalysisReport | null = null;
let loading = false;
let currentName = "";
let currentSize = 0;
let serial = 0;
let requestController: AbortController | null = null;
let problem: TextKey | null = null;
let wasCancelled = false;
let samples: SampleInfo[] = [];
let selectedOffset: number | null = null;
let eventPage = 0;
let referencePage = 0;
let wrapLines = true;
const pageSize = 50;
const manifestPreviewLimit = 50;
const xmlPreviewLimit = 100_000;
const t = (key: TextKey): string => text(language, key);
const number = (value: number | string): string => typeof value === "number" ? value.toLocaleString(language === "zh" ? "zh-CN" : "en-US") : value;
const hex = (value: number): string => `0x${(value >>> 0).toString(16).padStart(8, "0")}`;
function present<T>(value: T | [T] | null | undefined): T | undefined { return Array.isArray(value) ? value[0] as T : value ?? undefined; }
function element<K extends keyof HTMLElementTagNameMap>(tag: K, content?: string, className?: string): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag);
  if (content !== undefined) node.textContent = content;
  if (className) node.className = className;
  return node;
}
function announce(message: string): void { $("announcement").textContent = message; }
function details(value: unknown, title = t("original")): HTMLDetailsElement {
  const node = element("details", undefined, "data-detail");
  const content = element("pre");
  let populated = false;
  node.append(element("summary", title), content);
  node.addEventListener("toggle", () => {
    if (node.open && !populated) { content.textContent = JSON.stringify(value, null, 2); populated = true; }
  });
  return node;
}
function attributeValue(attribute: Attribute | undefined): string {
  if (!attribute) return t("notDeclared");
  const value = attribute.value;
  if (value.data_type === 3) return present(value.string_value) ?? t("notDeclared");
  if (value.data_type === 0x12) return value.data === 0 ? "false" : "true";
  if (value.data_type === 0x10 || value.data_type === 0x11) return String(value.data | 0);
  if ([1, 7].includes(value.data_type)) return `@${hex(value.data)}`;
  if ([2, 8].includes(value.data_type)) return `?${hex(value.data)}`;
  return present(attribute.raw_value) ?? `${hex(value.data)} · type 0x${value.data_type.toString(16)}`;
}
function field(list: HTMLElement, label: string, attribute: Attribute | undefined): void {
  const row = element("div", undefined, "field-row");
  const value = element("dd", attributeValue(attribute));
  if (attribute) value.append(details(attribute));
  row.append(element("dt", label), value);
  list.append(row);
}
function empty(container: HTMLElement, message: TextKey): void { container.append(element("div", t(message), "empty-result")); }
function diagnostic(container: HTMLElement, error: AnalysisError): void {
  const block = element("div", undefined, "diagnostic");
  const titles: Record<AnalysisError["stage"], TextKey> = { decode: "decodeError", xml: "xmlError", manifest: "manifestError", intents: "intentsError" };
  block.append(element("h3", t(titles[error.stage])));
  if (error.stage === "manifest" && error.message.includes("requires an unqualified manifest root")) block.append(element("p", t("notManifest")));
  block.append(element("p", error.message));
  block.append(element("p", `${error.stage} · ${t("offset")} ${error.offset >= 0 ? `${number(error.offset)} / ${hex(error.offset)}` : "—"}`, "diagnostic-location"));
  block.append(element("p", t("recovery"), "recovery"));
  container.append(block);
}
function sampleLabel(sample: SampleInfo): string {
  const keys: Record<string, TextKey> = { basic: "sampleBasic", unicode: "sampleUnicode", references: "sampleReferences", menu: "sampleMenu", utf16: "sampleUtf16", truncated: "sampleTruncated" };
  return keys[sample.id] ? t(keys[sample.id]!) : sample.label;
}
function renderLanguage(): void {
  document.documentElement.lang = language === "zh" ? "zh-CN" : "en";
  for (const node of document.querySelectorAll<HTMLElement>("[data-i18n]")) node.textContent = t(node.dataset.i18n as TextKey);
  $("language").textContent = language === "en" ? "中文" : "EN";
  $("language").setAttribute("aria-label", language === "en" ? "Switch to Chinese" : "切换到英文");
  sampleSelect.setAttribute("aria-label", language === "en" ? "Choose a sample" : "选择样例");
  $("views").setAttribute("aria-label", language === "en" ? "Result views" : "结果视图");
  for (const option of sampleSelect.options) { const sample = samples.find(item => item.id === option.value); if (sample) option.textContent = sampleLabel(sample); }
}
function renderState(): void {
  $("filename").textContent = currentName || t("noFile");
  $("file-size").textContent = currentName ? `${number(currentSize)} ${t("bytes")}` : "";
  const state = $("state");
  state.textContent = loading ? t("loading") : problem || report?.ok === false ? t("error") : wasCancelled ? t("cancelled") : report?.ok ? t("decoded") : "";
  state.dataset.state = loading ? "loading" : problem || report?.ok === false ? "error" : "ready";
  $("cancel").hidden = !loading;
  $("results").setAttribute("aria-busy", String(loading));
}
function output(): { text: string; extension: string } | null {
  if (!report?.ok || loading) return null;
  if (activeView === "xml") return report.xml.ok ? { text: report.xml.value, extension: "xml" } : null;
  if (activeView === "manifest") return report.manifest.ok ? { text: JSON.stringify({ manifest: report.manifest.value, intent_filters: report.intents }, null, 2), extension: "manifest.json" } : null;
  if (activeView === "structure") return { text: JSON.stringify({ stats: report.stats, events: report.events }, null, 2), extension: "structure.json" };
  return { text: JSON.stringify(report.references, null, 2), extension: "references.json" };
}
function renderToolbar(): void {
  const title: Record<View, TextKey> = { xml: "xmlTitle", manifest: "manifestTitle", structure: "structureTitle", references: "referencesTitle" };
  const subtitle: Record<View, TextKey> = { xml: "xmlSubtitle", manifest: "manifestSubtitle", structure: "structureSubtitle", references: "referencesSubtitle" };
  $("view-title").textContent = t(title[activeView]);
  $("view-subtitle").textContent = t(subtitle[activeView]);
  $("wrap").hidden = activeView !== "xml";
  $("wrap").setAttribute("aria-pressed", String(wrapLines));
  const available = !loading && report?.ok === true &&
    (activeView === "xml" ? report.xml.ok : activeView === "manifest" ? report.manifest.ok : true);
  $<HTMLButtonElement>("copy").disabled = !available;
  $<HTMLButtonElement>("download").disabled = !available;
  $("download").textContent = t(activeView === "xml" ? "downloadXml" : "downloadJson");
  if (selectedOffset !== null) {
    const selected = report?.ok ? report.events.preview.find(event => event.offset === selectedOffset) : null;
    $("context").textContent = selected ? `${t("selection")} · ${t("offset")} ${selected.offset} / ${hex(selected.offset)} · ${t("sourceLine")} ${selected.line_number}` : `${t("offset")} ${selectedOffset} · ${t("eventOutside")}`;
  } else $("context").textContent = report?.ok ? `${number(report.stats.events)} ${t("eventCount")} · ${report.stats.attributes} ${t("attributeCount")} · ${t("sourceLocation")}` : t("ready");
}
function switchView(view: View, focus = false): void {
  activeView = view;
  for (const name of views) {
    panels[name].hidden = name !== view;
    const tab = $<HTMLButtonElement>(`tab-${name}`);
    tab.setAttribute("aria-selected", String(name === view));
    tab.tabIndex = name === view ? 0 : -1;
  }
  renderToolbar();
  if (focus) $(`tab-${view}`).focus();
}
function renderXml(data: AnalysisSuccess): void {
  const container = panels.xml;
  if (!data.xml.ok) return diagnostic(container, data.xml.error);
  const preview = data.xml.value.slice(0, xmlPreviewLimit);
  const sheet = element("div", undefined, `code-sheet${wrapLines ? " wrap" : ""}`);
  const gutter = element("pre", Array.from({ length: preview.split("\n").length }, (_, index) => String(index + 1)).join("\n"), "code-gutter");
  gutter.setAttribute("aria-hidden", "true");
  const code = element("pre", preview, "code-text");
  code.setAttribute("aria-label", "XML");
  sheet.append(gutter, code);
  container.append(sheet);
  if (data.xml.value.length > xmlPreviewLimit) container.append(element("p", t("previewXml"), "preview-note"));
}
function renderManifest(data: AnalysisSuccess): void {
  if (!data.manifest.ok) return diagnostic(panels.manifest, data.manifest.error);
  const manifest = data.manifest.value;
  const sheet = element("div", undefined, "content-sheet");
  sheet.append(element("p", manifest.package_name, "package-name"));
  const fields = element("dl", undefined, "field-list");
  field(fields, t("versionName"), present(manifest.version_name));
  field(fields, t("versionCode"), present(manifest.version_code));
  if (present(manifest.version_code_major)) field(fields, t("versionCodeMajor"), present(manifest.version_code_major));
  const sdk = present(manifest.sdk);
  field(fields, t("minSdk"), sdk ? present(sdk.min_sdk) : undefined);
  field(fields, t("targetSdk"), sdk ? present(sdk.target_sdk) : undefined);
  if (sdk && present(sdk.max_sdk)) field(fields, t("maxSdk"), present(sdk.max_sdk));
  sheet.append(fields);
  const application = present(manifest.application);
  if (application) { sheet.append(element("h3", t("application")), details(application.attributes)); }
  sheet.append(element("h3", `${t("permissions")} · ${manifest.permissions.length}`));
  declarationPreviewNotice(sheet, manifest.permissions.length);
  if (!manifest.permissions.length) sheet.append(element("p", t("noPermissions"), "data-detail"));
  for (const permission of manifest.permissions.slice(0, manifestPreviewLimit)) {
    const row = element("div", undefined, "declaration");
    row.append(element("p", attributeValue(present(permission.name)), "declaration-title"), details(permission.attributes));
    sheet.append(row);
  }
  sheet.append(element("h3", `${t("components")} · ${manifest.components.length}`));
  declarationPreviewNotice(sheet, manifest.components.length);
  if (!manifest.components.length) sheet.append(element("p", t("noComponents"), "data-detail"));
  for (const component of manifest.components.slice(0, manifestPreviewLimit)) {
    const row = element("div", undefined, "declaration");
    const title = element("p", undefined, "declaration-title");
    title.append(element("span", component.kind), element("strong", attributeValue(present(component.name))));
    row.append(title, details(component.attributes));
    sheet.append(row);
  }
  sheet.append(element("h3", `${t("intentFilters")}${data.intents.ok ? ` · ${data.intents.value.length}` : ""}`));
  if (data.intents.ok) declarationPreviewNotice(sheet, data.intents.value.length);
  if (!data.intents.ok) diagnostic(sheet, data.intents.error);
  else if (!data.intents.value.length) sheet.append(element("p", t("noIntents"), "data-detail"));
  else for (const filter of data.intents.value.slice(0, manifestPreviewLimit)) {
    const row = element("div", undefined, "declaration");
    const title = element("p", undefined, "declaration-title");
    title.append(element("span", filter.component_kind), element("strong", attributeValue(present(filter.component_name))));
    row.append(title, sourceLink(filter.offset, filter.line_number), details(filter, t("declarations")));
    sheet.append(row);
  }
  panels.manifest.append(sheet);
}
function declarationPreviewNotice(container: HTMLElement, total: number): void {
  if (total > manifestPreviewLimit) container.append(element("p", `${t("previewDeclarations")} (${number(manifestPreviewLimit)} / ${number(total)})`, "preview-note"));
}
function sourceLink(offset: number, line: number): HTMLButtonElement {
  const link = element("button", `${number(offset)} · ${t("sourceLine")} ${number(line)}`, "source-link");
  link.type = "button";
  link.addEventListener("click", () => {
    if (!report?.ok) return;
    selectedOffset = offset;
    const index = report.events.preview.findIndex(event => event.offset === offset);
    if (index >= 0) eventPage = Math.floor(index / pageSize);
    panels.structure.replaceChildren();
    renderStructure(report);
    switchView("structure");
    const row = panels.structure.querySelector<HTMLElement>("tr.selected button");
    if (row) { row.focus(); row.scrollIntoView({ block: "nearest" }); }
    else panels.structure.focus();
  });
  return link;
}
function pager(container: HTMLElement, page: number, total: number, update: (page: number) => void): void {
  if (total <= pageSize) return;
  const nav = element("div", undefined, "pagination");
  nav.append(element("span", `${number(page * pageSize + 1)}${t("to")}${number(Math.min((page + 1) * pageSize, total))} ${t("of")} ${number(total)}`));
  for (const [label, target, disabled] of [[t("previous"), page - 1, page === 0], [t("next"), page + 1, (page + 1) * pageSize >= total]] as const) {
    const button = element("button", label, "text-button");
    button.type = "button";
    button.disabled = disabled;
    button.addEventListener("click", () => update(target));
    nav.append(button);
  }
  container.append(nav);
}
function eventName(event: EventSummary): string { return event.name ?? (event.kind === "Text" ? `${event.text_utf16_units} ${t("units")}` : "—"); }
function table(headers: string[]): { wrap: HTMLElement; body: HTMLTableSectionElement } {
  const wrap = element("div", undefined, "table-scroll");
  const grid = element("table");
  const header = element("thead"); const row = element("tr");
  for (const title of headers) { const cell = element("th", title); cell.scope = "col"; row.append(cell); }
  header.append(row); const body = element("tbody"); grid.append(header, body); wrap.append(grid);
  return { wrap, body };
}
function renderStructure(data: AnalysisSuccess): void {
  const container = panels.structure;
  const stats = element("div", undefined, "stats-grid");
  for (const key of ["strings", "resource_ids", "events", "start_elements", "attributes", "max_depth", "string_utf16_units", "text_events", "namespace_declarations"] as const) {
    const row = element("div", undefined, "stat-row"); row.append(element("span", t(key)), element("strong", number(data.stats[key]))); stats.append(row);
  }
  container.append(stats);
  if (data.events.truncated) container.append(element("p", `${t("previewEvents")} (${number(data.events.preview.length)} / ${number(data.events.total)})`, "preview-note"));
  if (!data.events.preview.length) return empty(container, "noEvents");
  const grid = table([t("event"), t("kind"), t("name"), t("offset")]);
  for (const event of data.events.preview.slice(eventPage * pageSize, (eventPage + 1) * pageSize)) {
    const row = element("tr"); row.classList.toggle("selected", event.offset === selectedOffset);
    row.append(element("td", number(event.index)), element("td", event.kind), element("td", eventName(event)));
    const source = element("td"); source.append(sourceLink(event.offset, event.line_number)); row.append(source); grid.body.append(row);
  }
  container.append(grid.wrap);
  pager(container, eventPage, data.events.preview.length, page => { eventPage = page; container.replaceChildren(); renderStructure(data); });
  const selected = data.events.preview.find(event => event.offset === selectedOffset);
  if (selected) {
    const block = element("div", undefined, "event-detail");
    block.append(element("p", t("selectedEvent"), "data-detail"), element("pre", JSON.stringify(selected, null, 2)));
    container.append(block);
  }
}
function referenceOrigin(usage: ResourceUsage): string {
  if (usage.origin === "Text") return t("text");
  const uri = present(usage.origin[1]);
  return uri ? `{${uri}}${usage.origin[2]}` : usage.origin[2];
}
function renderReferences(data: AnalysisSuccess): void {
  const container = panels.references;
  if (!data.references.length) return empty(container, "noReferences");
  const grid = table([t("reference"), t("kind"), t("origin"), t("offset")]);
  for (const usage of data.references.slice(referencePage * pageSize, (referencePage + 1) * pageSize)) {
    const row = element("tr");
    row.append(element("td", hex(usage.reference[1])), element("td", usage.reference[0]), element("td", referenceOrigin(usage)));
    const source = element("td"); source.append(sourceLink(usage.offset, usage.line_number)); row.append(source); grid.body.append(row);
  }
  container.append(grid.wrap);
  pager(container, referencePage, data.references.length, page => { referencePage = page; container.replaceChildren(); renderReferences(data); });
}
function render(): void {
  renderLanguage(); renderState();
  for (const panel of Object.values(panels)) panel.replaceChildren();
  if (loading) for (const panel of Object.values(panels)) {
    const skeleton = element("div", undefined, "loading-sheet"); skeleton.setAttribute("aria-hidden", "true");
    for (let index = 0; index < 3; index++) skeleton.append(element("div", undefined, "loading-rule")); panel.append(skeleton);
  } else if (problem) for (const panel of Object.values(panels)) { const block = element("div", undefined, "diagnostic"); block.append(element("h3", t("decodeError")), element("p", t(problem)), element("p", t("recovery"), "recovery")); panel.append(block); }
  else if (report?.ok === false) for (const panel of Object.values(panels)) diagnostic(panel, report.error);
  else if (report?.ok) { renderXml(report); renderManifest(report); renderStructure(report); renderReferences(report); }
  else for (const panel of Object.values(panels)) panel.append(element("div", wasCancelled ? t("cancelled") : t("ready"), "empty-result"));
  switchView(activeView);
}
function begin(name: string, size: number): number {
  serial += 1; requestController?.abort(); requestController = null; client.cancel();
  currentName = name; currentSize = size; loading = true; report = null; problem = null; wasCancelled = false;
  selectedOffset = null; eventPage = 0; referencePage = 0;
  render(); return serial;
}
function clientProblem(error: unknown): TextKey {
  if (!(error instanceof AnalysisClientError)) return "unknownError";
  const keys: Partial<Record<AnalysisClientError["code"], TextKey>> = { "file-too-large": "fileTooLarge", "read-failed": "readFailed", timeout: "timeout", "worker-failed": "workerFailed", "protocol-error": "protocolError" };
  return keys[error.code] ?? "unknownError";
}
async function analyze(file: File, request: number): Promise<void> {
  try { const result = await client.analyze(file); if (serial !== request) return; report = result; }
  catch (error) { if (serial !== request) return; if (error instanceof AnalysisClientError && error.code === "cancelled") wasCancelled = true; else problem = clientProblem(error); }
  if (serial !== request) return;
  loading = false; render(); announce(report?.ok ? t("decoded") : wasCancelled ? t("cancelled") : t("error"));
}
async function loadSample(id: string): Promise<void> {
  const sample = samples.find(item => item.id === id); if (!sample) return;
  const request = begin(sample.filename, sample.bytes);
  requestController = new AbortController();
  try {
    const response = await fetch(`${import.meta.env.BASE_URL}samples/${encodeURIComponent(sample.filename)}`, { signal: requestController.signal });
    if (!response.ok) throw new Error("Sample unavailable");
    const buffer = await response.arrayBuffer();
    if (serial !== request) return;
    requestController = null;
    await analyze(new File([buffer], sample.filename), request);
  } catch { if (serial === request) { loading = false; problem = "sampleFailed"; render(); } }
}
$("open-file").addEventListener("click", () => fileInput.click());
fileInput.addEventListener("change", () => { const file = fileInput.files?.[0]; if (!file) return; sampleSelect.value = ""; void analyze(file, begin(file.name, file.size)); fileInput.value = ""; });
sampleSelect.addEventListener("change", () => { if (sampleSelect.value) void loadSample(sampleSelect.value); });
$("cancel").addEventListener("click", () => { serial += 1; requestController?.abort(); requestController = null; client.cancel(); loading = false; report = null; problem = null; wasCancelled = true; render(); announce(t("cancelled")); });
$("language").addEventListener("click", () => { language = language === "en" ? "zh" : "en"; try { localStorage.setItem("moonaxml-language", language); } catch { /* Optional preference. */ } render(); });
for (const view of views) $(`tab-${view}`).addEventListener("click", () => switchView(view));
$("views").addEventListener("keydown", event => {
  if (!(event.target instanceof HTMLButtonElement) || !["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return;
  event.preventDefault();
  const index = views.indexOf(activeView); const target = event.key === "Home" ? 0 : event.key === "End" ? views.length - 1 : (index + (event.key === "ArrowRight" ? 1 : -1) + views.length) % views.length;
  switchView(views[target]!, true);
});
$("wrap").addEventListener("click", () => { wrapLines = !wrapLines; panels.xml.querySelector(".code-sheet")?.classList.toggle("wrap", wrapLines); renderToolbar(); });
$("copy").addEventListener("click", () => {
  const value = output(); if (!value) return;
  const failed = (): void => { announce(t("copyFailed")); $("context").textContent = t("copyFailed"); };
  if (!navigator.clipboard) return failed();
  void navigator.clipboard.writeText(value.text).then(() => { announce(t("copied")); $("copy").textContent = t("copied"); setTimeout(() => { $("copy").textContent = t("copy"); }, 1800); }).catch(failed);
});
$("download").addEventListener("click", () => {
  const value = output(); if (!value) return;
  const url = URL.createObjectURL(new Blob([value.text], { type: value.extension === "xml" ? "application/xml;charset=utf-8" : "application/json;charset=utf-8" }));
  const link = element("a"); link.href = url; link.download = `${currentName.replace(/\.(axml|xml)$/i, "") || "document"}.${value.extension}`; link.click(); setTimeout(() => URL.revokeObjectURL(url), 1000);
});
let dragDepth = 0;
document.addEventListener("dragenter", event => { if (!event.dataTransfer?.types.includes("Files")) return; event.preventDefault(); dragDepth++; $("drop-overlay").hidden = false; });
document.addEventListener("dragover", event => { if (event.dataTransfer?.types.includes("Files")) { event.preventDefault(); event.dataTransfer.dropEffect = "copy"; } });
document.addEventListener("dragleave", () => { dragDepth = Math.max(0, dragDepth - 1); if (!dragDepth) $("drop-overlay").hidden = true; });
document.addEventListener("drop", event => { event.preventDefault(); dragDepth = 0; $("drop-overlay").hidden = true; const file = event.dataTransfer?.files[0]; if (file) { sampleSelect.value = ""; void analyze(file, begin(file.name, file.size)); } });
window.addEventListener("pagehide", event => {
  serial++; requestController?.abort();
  if (!event.persisted) { client.dispose(); return; }
  client.cancel();
  if (loading) { loading = false; report = null; problem = null; wasCancelled = true; render(); }
});
render();
void fetch(`${import.meta.env.BASE_URL}samples/index.json`).then(async response => {
  if (!response.ok) throw new Error("Sample index unavailable");
  const index = await response.json() as SampleIndex; samples = index.samples;
  sampleSelect.replaceChildren(new Option(language === "en" ? "Local file" : "本机文件", ""));
  for (const sample of samples) sampleSelect.add(new Option(sampleLabel(sample), sample.id));
  if (serial === 0) { sampleSelect.value = "basic"; await loadSample("basic"); }
}).catch(() => { sampleSelect.replaceChildren(new Option(t("sampleFailed"), "")); sampleSelect.disabled = true; });
