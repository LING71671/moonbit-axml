import {
  ANALYSIS_TIMEOUT_MS,
  MAX_INPUT_BYTES,
  isAnalysisReport,
} from "./protocol.ts";
import type { AnalysisReport, WorkerRequest } from "./protocol.ts";

export type AnalysisClientErrorCode =
  | "file-too-large" | "read-failed" | "worker-failed" | "timeout"
  | "cancelled" | "disposed" | "protocol-error";

export class AnalysisClientError extends Error {
  readonly code: AnalysisClientErrorCode;
  constructor(code: AnalysisClientErrorCode, message: string) {
    super(message);
    this.code = code;
    this.name = code === "cancelled" ? "AbortError" : "AnalysisClientError";
  }
}

export interface AnalysisInput {
  readonly name?: string;
  readonly size: number;
  arrayBuffer(): Promise<ArrayBuffer>;
}

export interface AnalysisWorker {
  onmessage: ((event: MessageEvent<unknown>) => void) | null;
  onerror: ((event: ErrorEvent) => void) | null;
  onmessageerror: ((event: MessageEvent<unknown>) => void) | null;
  postMessage(message: WorkerRequest, transfer: Transferable[]): void;
  terminate(): void;
}

export interface AnalysisClientOptions {
  createWorker?: () => AnalysisWorker;
  timeoutMs?: number;
  maxBytes?: number;
  setTimer?: (callback: () => void, delay: number) => unknown;
  clearTimer?: (handle: unknown) => void;
}

export interface AnalysisClient {
  analyze(input: AnalysisInput): Promise<AnalysisReport>;
  cancel(): void;
  dispose(): void;
}

interface Task {
  id: number;
  worker?: AnalysisWorker;
  timer?: unknown;
  resolve: (report: AnalysisReport) => void;
  reject: (error: AnalysisClientError) => void;
}

function browserWorker(): AnalysisWorker {
  // Keep new URL directly inside new Worker so Vite bundles the module worker.
  return new Worker(new URL("./worker.ts", import.meta.url), { type: "module" });
}

export function createAnalysisClient(options: AnalysisClientOptions = {}): AnalysisClient {
  const createWorker = options.createWorker ?? browserWorker;
  const timeoutMs = options.timeoutMs ?? ANALYSIS_TIMEOUT_MS;
  const maxBytes = options.maxBytes ?? MAX_INPUT_BYTES;
  const setTimer = options.setTimer ?? ((callback, delay) => globalThis.setTimeout(callback, delay));
  const clearTimer = options.clearTimer ?? ((handle) => globalThis.clearTimeout(handle as ReturnType<typeof setTimeout>));
  if (!Number.isFinite(timeoutMs) || timeoutMs <= 0 || timeoutMs > ANALYSIS_TIMEOUT_MS
    || !Number.isSafeInteger(maxBytes) || maxBytes < 0 || maxBytes > MAX_INPUT_BYTES) {
    throw new RangeError("Analysis limits must stay within 16 MiB and 10 seconds.");
  }
  let active: Task | undefined;
  let sequence = 0;
  let disposed = false;

  function finish(task: Task, outcome: AnalysisReport | AnalysisClientError): void {
    if (active !== task) return;
    active = undefined;
    clearTimer(task.timer);
    if (task.worker) {
      task.worker.onmessage = null;
      task.worker.onerror = null;
      task.worker.onmessageerror = null;
      task.worker.terminate();
    }
    if (outcome instanceof AnalysisClientError) task.reject(outcome);
    else task.resolve(outcome);
  }

  function cancel(): void {
    if (active) finish(active, new AnalysisClientError("cancelled", "Analysis cancelled."));
  }

  return {
    analyze(input) {
      if (disposed) return Promise.reject(new AnalysisClientError("disposed", "The analysis client has been disposed."));
      cancel();
      if (!Number.isSafeInteger(input.size) || input.size < 0) {
        return Promise.reject(new AnalysisClientError("read-failed", "The input has an invalid file size."));
      }
      if (input.size > maxBytes) {
        return Promise.reject(new AnalysisClientError("file-too-large", "The input exceeds the 16 MiB limit."));
      }
      return new Promise<AnalysisReport>((resolve, reject) => {
        const task: Task = { id: ++sequence, resolve, reject };
        active = task;
        task.timer = setTimer(() => finish(task,
          new AnalysisClientError("timeout", "Analysis exceeded the 10-second time limit.")), timeoutMs);
        // Read asynchronously after returning the promise; a new selection can
        // cancel even when a File-like object is slow or throws synchronously.
        void Promise.resolve().then(() => {
          if (active !== task) return undefined;
          return input.arrayBuffer();
        }).then((buffer) => {
          if (active !== task || buffer === undefined) return;
          if (!(buffer instanceof ArrayBuffer) || buffer.byteLength !== input.size || buffer.byteLength > maxBytes) {
            finish(task, new AnalysisClientError("read-failed", "The input size changed while reading."));
            return;
          }
          let worker: AnalysisWorker;
          try {
            worker = createWorker();
          } catch (error) {
            finish(task, new AnalysisClientError("worker-failed",
              error instanceof Error ? error.message : "The analysis worker could not start."));
            return;
          }
          task.worker = worker;
          worker.onmessage = (event) => {
            if (active !== task) return;
            const message = event.data;
            if (typeof message !== "object" || message === null) {
              finish(task, new AnalysisClientError("protocol-error", "The worker returned an invalid message."));
              return;
            }
            const response = message as Record<string, unknown>;
            if (response.taskId !== task.id) return;
            if (response.type === "result" && isAnalysisReport(response.report)) {
              if (response.report.input_bytes !== input.size) {
                finish(task, new AnalysisClientError("protocol-error", "The report does not match this input."));
              } else finish(task, response.report);
            } else if (response.type === "error" && typeof response.message === "string") {
              finish(task, new AnalysisClientError("worker-failed", response.message));
            } else finish(task, new AnalysisClientError("protocol-error", "The worker returned an unsupported report."));
          };
          worker.onerror = (event) => {
            event.preventDefault();
            finish(task, new AnalysisClientError("worker-failed", event.message || "The analysis worker failed."));
          };
          worker.onmessageerror = () => finish(task,
            new AnalysisClientError("protocol-error", "The worker result could not be transferred."));
          worker.postMessage({ type: "analyze", taskId: task.id, buffer }, [buffer]);
        }).catch((error: unknown) => {
          finish(task, new AnalysisClientError(task.worker ? "worker-failed" : "read-failed",
            error instanceof Error ? error.message : "The input could not be analyzed."));
        });
      });
    },
    cancel,
    dispose() {
      cancel();
      disposed = true;
    },
  };
}
