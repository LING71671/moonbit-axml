import test from "node:test";
import assert from "node:assert/strict";
import { setImmediate } from "node:timers/promises";
import { createAnalysisClient } from "../src/analysis-client.ts";
import type { AnalysisInput, AnalysisWorker } from "../src/analysis-client.ts";
import { MAX_INPUT_BYTES } from "../src/protocol.ts";
import type { AnalysisReport, WorkerRequest } from "../src/protocol.ts";

const failure = (bytes = 4): AnalysisReport => ({
  schema_version: 1, ok: false, input_bytes: bytes,
  error: { stage: "decode", offset: 0, message: "Invalid test input." },
});
const file = (size = 4): AnalysisInput => ({ size, arrayBuffer: async () => new ArrayBuffer(size) });

class FakeWorker implements AnalysisWorker {
  onmessage: AnalysisWorker["onmessage"] = null;
  onerror: AnalysisWorker["onerror"] = null;
  onmessageerror: AnalysisWorker["onmessageerror"] = null;
  requests: WorkerRequest[] = [];
  terminated = false;
  postMessage(message: WorkerRequest, transfer: Transferable[]) {
    this.requests.push(structuredClone(message, { transfer }));
  }
  terminate() { this.terminated = true; }
  result(report = failure()) {
    this.onmessage?.(new MessageEvent("message", {
      data: { type: "result", taskId: this.requests[0]!.taskId, report },
    }));
  }
}

function fixture(failStartup = false) {
  const workers: FakeWorker[] = [];
  const timers = new Map<number, () => void>();
  let timerId = 0;
  const client = createAnalysisClient({
    createWorker: () => {
      if (failStartup) throw new Error("Workers are unavailable.");
      const worker = new FakeWorker(); workers.push(worker); return worker;
    },
    setTimer: (callback, delay) => { assert.equal(delay, 10_000); timers.set(++timerId, callback); return timerId; },
    clearTimer: (id) => { timers.delete(id as number); },
  });
  return { client, workers, timers, timeout: () => { for (const callback of [...timers.values()]) callback(); } };
}

test("oversized input is rejected before reading or creating a worker", async () => {
  const { client, workers, timers } = fixture();
  let reads = 0;
  await assert.rejects(client.analyze({ size: MAX_INPUT_BYTES + 1,
    arrayBuffer: async () => { reads++; return new ArrayBuffer(0); } }), { code: "file-too-large" });
  assert.equal(reads, 0);
  assert.equal(workers.length, 0);
  assert.equal(timers.size, 0);
});

test("input is transferred and decode failures are delivered as reports with cleanup", async () => {
  const { client, workers, timers } = fixture();
  const buffer = new ArrayBuffer(4);
  const promise = client.analyze({ size: 4, arrayBuffer: async () => buffer });
  await setImmediate();
  assert.equal(buffer.byteLength, 0);
  assert.equal(workers[0]!.requests[0]!.buffer.byteLength, 4);
  workers[0]!.result();
  assert.deepEqual(await promise, failure());
  assert.equal(workers[0]!.terminated, true);
  assert.equal(workers[0]!.onmessage, null);
  assert.equal(timers.size, 0);
});

test("new selection terminates the old worker and ignores queued stale results", async () => {
  const { client, workers } = fixture();
  const first = client.analyze(file());
  const cancelled = assert.rejects(first, { name: "AbortError", code: "cancelled" });
  await setImmediate();
  const staleHandler = workers[0]!.onmessage!;
  const firstId = workers[0]!.requests[0]!.taskId;
  const second = client.analyze(file());
  await cancelled;
  await setImmediate();
  assert.equal(workers[0]!.terminated, true);
  let settled = false;
  void second.then(() => { settled = true; });
  staleHandler(new MessageEvent("message", { data: { type: "result", taskId: firstId, report: failure() } }));
  await setImmediate();
  assert.equal(settled, false);
  workers[1]!.result();
  assert.deepEqual(await second, failure());
});

test("superseded slow file reads cannot start a worker after the newer request", async () => {
  const { client, workers } = fixture();
  let finishRead!: (buffer: ArrayBuffer) => void;
  const first = client.analyze({ size: 4, arrayBuffer: () => new Promise((resolve) => { finishRead = resolve; }) });
  const cancelled = assert.rejects(first, { code: "cancelled" });
  await setImmediate();
  const second = client.analyze(file());
  await cancelled;
  await setImmediate();
  finishRead(new ArrayBuffer(4));
  await setImmediate();
  assert.equal(workers.length, 1);
  workers[0]!.result();
  await second;
});

test("cancel and dispose settle pending work and dispose prevents reuse", async () => {
  const { client, workers, timers } = fixture();
  const first = client.analyze(file());
  const cancelled = assert.rejects(first, { code: "cancelled" });
  await setImmediate();
  client.cancel();
  await cancelled;
  assert.equal(workers[0]!.terminated, true);
  const second = client.analyze(file());
  const disposed = assert.rejects(second, { code: "cancelled" });
  await setImmediate();
  client.dispose();
  await disposed;
  assert.equal(workers[1]!.terminated, true);
  await assert.rejects(client.analyze(file()), { code: "disposed" });
  assert.equal(timers.size, 0);
});

test("wall-clock timeout also bounds file reads and discards their late completion", async () => {
  const { client, workers, timeout, timers } = fixture();
  let finishRead!: (buffer: ArrayBuffer) => void;
  const promise = client.analyze({ size: 4, arrayBuffer: () => new Promise((resolve) => { finishRead = resolve; }) });
  const rejected = assert.rejects(promise, { code: "timeout" });
  await setImmediate();
  timeout();
  await rejected;
  finishRead(new ArrayBuffer(4));
  await setImmediate();
  assert.equal(workers.length, 0);
  assert.equal(timers.size, 0);
});

test("wall-clock timeout terminates a busy worker and clears its handlers", async () => {
  const { client, workers, timeout } = fixture();
  const promise = client.analyze(file());
  const rejected = assert.rejects(promise, { code: "timeout" });
  await setImmediate();
  timeout();
  await rejected;
  assert.equal(workers[0]!.terminated, true);
  assert.equal(workers[0]!.onmessage, null);
});

test("malformed worker envelopes and worker errors reject and release resources", async () => {
  for (const mode of ["protocol", "crash", "startup"] as const) {
    const { client, workers, timers } = fixture(mode === "startup");
    const promise = client.analyze(file());
    const rejected = assert.rejects(promise, { code: mode === "protocol" ? "protocol-error" : "worker-failed" });
    await setImmediate();
    if (mode === "protocol") workers[0]!.onmessage?.(new MessageEvent("message", {
      data: { type: "result", taskId: workers[0]!.requests[0]!.taskId, report: { ok: true } },
    }));
    else if (mode === "crash") workers[0]!.onerror?.({ message: "Worker crashed.", preventDefault() {} } as ErrorEvent);
    await rejected;
    if (mode !== "startup") assert.equal(workers[0]!.terminated, true);
    else assert.equal(workers.length, 0);
    assert.equal(timers.size, 0);
  }
});

test("read failures and size changes never deliver unverified buffers to a worker", async () => {
  for (const arrayBuffer of [async () => { throw new Error("Read failed."); }, async () => new ArrayBuffer(5)]) {
    const { client, workers } = fixture();
    await assert.rejects(client.analyze({ size: 4, arrayBuffer }), { code: "read-failed" });
    assert.equal(workers.length, 0);
  }
});
