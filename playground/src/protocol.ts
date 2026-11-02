export const MAX_INPUT_BYTES = 16 * 1024 * 1024;
export const ANALYSIS_TIMEOUT_MS = 10_000;
export type AnalysisStage = "decode" | "xml" | "manifest" | "intents";
export type MoonOption<T> = [T] | null;

/** Struct options are omitted/unboxed; enum tuple options use [value] or null. */
export function unwrapMoonOption<T>(value: T | MoonOption<T> | undefined): T | null {
  if (value === null || value === undefined) return null;
  return Array.isArray(value) ? value[0] as T : value;
}

export interface AnalysisError {
  stage: AnalysisStage;
  offset: number;
  message: string;
}

export type ViewResult<T> =
  | { ok: true; value: T }
  | { ok: false; error: AnalysisError };

export interface TypedValue {
  data_type: number;
  data: number;
  string_value?: string;
}

export interface Attribute {
  namespace_uri?: string;
  name: string;
  resource_id?: number;
  raw_value?: string;
  value: TypedValue;
}

export interface ManifestComponent {
  kind: string;
  name?: Attribute;
  exported?: Attribute;
  enabled?: Attribute;
  authorities?: Attribute;
  permission?: Attribute;
  attributes: Attribute[];
}

export interface ManifestInfo {
  package_name: string;
  version_code?: Attribute;
  version_code_major?: Attribute;
  version_name?: Attribute;
  sdk?: {
    min_sdk?: Attribute;
    target_sdk?: Attribute;
    max_sdk?: Attribute;
  };
  permissions: {
    kind: string;
    name?: Attribute;
    max_sdk?: Attribute;
    attributes: Attribute[];
  }[];
  application?: {
    name?: Attribute;
    label?: Attribute;
    debuggable?: Attribute;
    enabled?: Attribute;
    attributes: Attribute[];
  };
  components: ManifestComponent[];
}

export interface IntentFilter {
  component_kind: string;
  component_name?: Attribute;
  offset: number;
  line_number: number;
  attributes: Attribute[];
  actions: Attribute[];
  categories: Attribute[];
  data: Attribute[][];
}

export type ReferenceKind =
  | "Resource"
  | "ThemeAttribute"
  | "DynamicResource"
  | "DynamicThemeAttribute";

export interface ResourceUsage {
  offset: number;
  line_number: number;
  origin: "Text" | ["Attribute", MoonOption<string>, string];
  reference: [ReferenceKind, number];
}

export interface DocumentStats {
  strings: number;
  string_utf16_units: string;
  resource_ids: number;
  events: number;
  start_elements: number;
  attributes: string;
  text_events: number;
  namespace_declarations: number;
  max_depth: number;
}

export interface EventSummary {
  index: number;
  offset: number;
  line_number: number;
  kind: "StartNamespace" | "EndNamespace" | "StartElement" | "EndElement" | "Text";
  namespace_uri: string | null;
  name: string | null;
  attribute_count: number;
  text_utf16_units: number;
}

export interface AnalysisSuccess {
  schema_version: 1;
  ok: true;
  input_bytes: number;
  stats: DocumentStats;
  references: ResourceUsage[];
  events: { total: number; preview: EventSummary[]; limit: number; truncated: boolean };
  xml: ViewResult<string> & { limit_utf16_units: number };
  manifest: ViewResult<ManifestInfo>;
  intents: ViewResult<IntentFilter[]>;
}

export interface AnalysisFailure {
  schema_version: 1;
  ok: false;
  input_bytes: number;
  error: AnalysisError;
}

export type AnalysisReport = AnalysisSuccess | AnalysisFailure;
export interface WorkerRequest { type: "analyze"; taskId: number; buffer: ArrayBuffer }
export type WorkerResponse =
  | { type: "result"; taskId: number; report: AnalysisReport }
  | { type: "error"; taskId: number; message: string };

export interface SampleInfo {
  id: string;
  filename: string;
  label: string;
  valid: boolean;
  bytes: number;
  sha256: string;
}
export interface SampleIndex { schema_version: 1; samples: SampleInfo[] }

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function isError(value: unknown): value is AnalysisError {
  return isRecord(value) && ["decode", "xml", "manifest", "intents"].includes(String(value.stage))
    && typeof value.offset === "number" && Number.isInteger(value.offset)
    && typeof value.message === "string";
}

function isView(value: unknown): boolean {
  return isRecord(value) && (value.ok === true ? "value" in value : value.ok === false && isError(value.error));
}

/** Validate the fixed bridge envelope before delivering a worker result. */
export function isAnalysisReport(value: unknown): value is AnalysisReport {
  if (!isRecord(value) || value.schema_version !== 1 || typeof value.input_bytes !== "number"
    || !Number.isSafeInteger(value.input_bytes) || value.input_bytes < 0 || value.input_bytes > MAX_INPUT_BYTES) return false;
  if (value.ok === false) return isError(value.error);
  return value.ok === true && isRecord(value.stats) && Array.isArray(value.references)
    && isRecord(value.events) && Array.isArray(value.events.preview)
    && typeof value.events.total === "number" && typeof value.events.limit === "number"
    && typeof value.events.truncated === "boolean" && isView(value.xml)
    && isView(value.manifest) && isView(value.intents);
}

export function parseAnalysisReport(raw: string): AnalysisReport {
  const value: unknown = JSON.parse(raw);
  if (!isAnalysisReport(value)) throw new Error("The decoder returned an unsupported report envelope.");
  return value;
}
