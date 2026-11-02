import { analyze_bytes } from "./generated/browser.js";
import { MAX_INPUT_BYTES, parseAnalysisReport } from "./protocol.ts";
import type { AnalysisReport, WorkerResponse } from "./protocol.ts";

export function analyzeBuffer(buffer: ArrayBuffer): AnalysisReport {
  if (buffer.byteLength > MAX_INPUT_BYTES) throw new Error("The input exceeds the 16 MiB limit.");
  return parseAnalysisReport(analyze_bytes(new Uint8Array(buffer)));
}

export function handleAnalysisRequest(value: unknown): WorkerResponse {
  const request = typeof value === "object" && value !== null ? value as Record<string, unknown> : {};
  const taskId = typeof request.taskId === "number" && Number.isSafeInteger(request.taskId) ? request.taskId : 0;
  try {
    if (request.type !== "analyze" || taskId < 1 || !(request.buffer instanceof ArrayBuffer)) {
      throw new Error("The analysis worker received an invalid request.");
    }
    return { type: "result", taskId, report: analyzeBuffer(request.buffer) };
  } catch (error) {
    return { type: "error", taskId, message: error instanceof Error ? error.message : "The decoder failed." };
  }
}

const scope = globalThis as unknown as {
  postMessage?: (message: WorkerResponse) => void;
  onmessage: ((event: MessageEvent<unknown>) => void) | null;
};
if (typeof scope.postMessage === "function" && typeof document === "undefined") {
  scope.onmessage = (event) => scope.postMessage!(handleAnalysisRequest(event.data));
}
