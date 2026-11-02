import type { EventSummary, ResourceUsage } from "./protocol.ts";

/** Match literal substrings against protocol values, independent of UI language. */
function matches(query: string, values: readonly (string | number | null)[]): boolean {
  return values.some(value => value !== null && String(value).toLowerCase().includes(query));
}

export function hexValue(value: number): string {
  return `0x${(value >>> 0).toString(16).padStart(8, "0")}`;
}

export function filterEvents(events: readonly EventSummary[], input: string): EventSummary[] {
  const query = input.trim().toLowerCase();
  return events.filter(event => !query || matches(query, [
    event.name, event.namespace_uri, event.kind, event.offset, hexValue(event.offset),
  ]));
}

export function filterReferences(references: readonly ResourceUsage[], input: string): ResourceUsage[] {
  const query = input.trim().toLowerCase();
  return references.filter(usage => {
    if (!query) return true;
    const uri = usage.origin === "Text" ? null : usage.origin[1]?.[0] ?? null;
    const origin = usage.origin === "Text" ? ["Text"] : ["Attribute", uri, usage.origin[2],
      uri ? `{${uri}}${usage.origin[2]}` : usage.origin[2]];
    return matches(query, [usage.reference[0], usage.reference[1], hexValue(usage.reference[1]),
      usage.offset, hexValue(usage.offset), ...origin]);
  });
}

/** Find the original preview page; null means the source is outside that preview. */
export function sourceEventPage(events: readonly EventSummary[], offset: number, pageSize: number): number | null {
  const index = events.findIndex(event => event.offset === offset);
  return index < 0 ? null : Math.floor(index / pageSize);
}

/** Keep an old page usable when a result set becomes shorter or empty. */
export function clampPage(page: number, total: number, pageSize: number): number {
  return Math.max(0, Math.min(page, Math.max(0, Math.ceil(total / pageSize) - 1)));
}
