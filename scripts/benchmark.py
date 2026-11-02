#!/usr/bin/env python3
"""Run bounded, independently generated AXML stress cases with real child RSS.

Build the debug JS/native CLIs first. Uses Python's standard library only.
Example: python scripts/benchmark.py --output evidence/benchmark.json
"""

from __future__ import annotations

import argparse
import ctypes
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import platform
import statistics
import struct
import subprocess
import tempfile
import time

from generate_fixtures import NO_INDEX, node, string_pool

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "_build" / "benchmarks"


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def element_start(attributes: bytes = b"") -> bytes:
    return node(0x102, struct.pack("<IIHHHHHH", NO_INDEX, 0, 20, 20, len(attributes) // 20, 0, 0, 0) + attributes)


def element_end(index: int = 0) -> bytes:
    return node(0x103, struct.pack("<II", NO_INDEX, index))


def make_cases() -> list[dict]:
    """Encode AOSP chunk layouts without the MoonBit decoder or renderer."""
    cases = []

    def add(name: str, strings: list[str], body: bytes, depth: int, events: int, xml: bytes | None, error_offset: int | None = None) -> None:
        payload = string_pool(strings, True) + body
        data = struct.pack("<HHI", 3, 8, len(payload) + 8) + payload
        path = BUILD / f"{name}.axml"
        path.write_bytes(data)
        cases.append({
            "name": name, "path": path.relative_to(ROOT).as_posix(),
            "input_bytes": len(data), "input_sha256": digest(data),
            "string_count": len(strings), "decoded_utf16_units": sum(len(s.encode("utf-16le")) // 2 for s in strings),
            "max_depth": depth, "event_count": events,
            "expected_exit_code": 0 if xml is not None else 1,
            "expected_stdout_bytes": len(xml) if xml is not None else 0,
            "expected_stdout_sha256": digest(xml or b""),
            "expected_error_offset": error_offset,
        })

    pool = ["root"] + [f"unused_{index:06d}" for index in range(99999)]
    add("large_pool", pool, element_start() + element_end(), 1, 2, b"<root></root>\n")
    add("max_depth", ["root"], element_start() * 256 + element_end() * 256, 256, 512, b"<root>" * 256 + b"</root>" * 256 + b"\n")
    value = "x&<>" + "y" * 4092
    attribute = struct.pack("<IIIHBBI", NO_INDEX, 1, 2, 8, 0, 3, 2)
    repeats = 2048
    child_xml = b'<root value="' + value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").encode() + b'"></root>'
    add("repeated_strings", ["root", "value", value], element_start() + (element_start(attribute) + element_end()) * repeats + element_end(), 2, 2 + 2 * repeats, b"<root>" + child_xml * repeats + b"</root>\n")
    # Invalid final name index forces full pool decoding before rejection.
    bad_body = element_start() + element_end(len(pool))
    bad_offset = 8 + len(string_pool(pool, True)) + len(bad_body) - 4
    add("malformed_input", pool, bad_body, 1, 2, None, bad_offset)
    return cases


class WindowsMemory:
    """Read the kernel's lifetime peak working-set counter from a child handle."""

    def __init__(self) -> None:
        from ctypes import wintypes

        class Counters(ctypes.Structure):
            _fields_ = [("cb", wintypes.DWORD), ("PageFaultCount", wintypes.DWORD)] + [(name, ctypes.c_size_t) for name in ["PeakWorkingSetSize", "WorkingSetSize", "QuotaPeakPagedPoolUsage", "QuotaPagedPoolUsage", "QuotaPeakNonPagedPoolUsage", "QuotaNonPagedPoolUsage", "PagefileUsage", "PeakPagefileUsage"]]

        self.counters = Counters
        self.query = ctypes.WinDLL("psapi", use_last_error=True).GetProcessMemoryInfo
        self.query.argtypes = [wintypes.HANDLE, ctypes.POINTER(Counters), wintypes.DWORD]
        self.query.restype = wintypes.BOOL

    def peak(self, process: subprocess.Popen) -> int | None:
        counters = self.counters()
        counters.cb = ctypes.sizeof(counters)
        if self.query(int(process._handle), ctypes.byref(counters), counters.cb):
            return counters.PeakWorkingSetSize or None
        return None


def measure(command: list[str], case: dict, timeout: float, max_rss: int) -> dict:
    windows = WindowsMemory() if os.name == "nt" else None
    peak = None
    final_peak_available = False
    memory_method = "not_measured"
    with tempfile.TemporaryFile(dir=BUILD) as stdout, tempfile.TemporaryFile(dir=BUILD) as stderr:
        started = time.perf_counter()
        process = subprocess.Popen(command + ["decode", case["path"]], cwd=ROOT, stdin=subprocess.DEVNULL, stdout=stdout, stderr=stderr)
        try:
            while True:
                if windows:
                    measured = windows.peak(process)
                    if measured is not None:
                        peak = max(peak or 0, measured)
                    finished = process.poll() is not None
                    if finished:
                        final = windows.peak(process)
                        if final is not None:
                            peak = max(peak or 0, final)
                            final_peak_available = True
                        memory_method = "GetProcessMemoryInfo.PeakWorkingSetSize" if final_peak_available else "GetProcessMemoryInfo.PeakWorkingSetSize (polled; final query unavailable)"
                elif hasattr(os, "wait4"):
                    pid, status, usage = os.wait4(process.pid, os.WNOHANG)
                    finished = pid != 0
                    if finished:
                        process.returncode = os.waitstatus_to_exitcode(status)
                        # macOS reports bytes; Linux/BSD report KiB.
                        peak = int(usage.ru_maxrss * (1 if platform.system() == "Darwin" else 1024))
                        final_peak_available = True
                        memory_method = "wait4.ru_maxrss"
                else:
                    finished = process.poll() is not None
                if time.perf_counter() - started > timeout:
                    raise RuntimeError(f"{case['name']}: exceeded {timeout:g}s watchdog")
                if peak is not None and peak > max_rss:
                    raise RuntimeError(f"{case['name']}: child exceeded {max_rss // (1024 * 1024)} MiB RSS watchdog")
                if stdout.tell() > 34 * 1024 * 1024 or stderr.tell() > 65536:
                    raise RuntimeError(f"{case['name']}: unexpected output volume")
                if finished:
                    break
                time.sleep(0.005)
        except BaseException:
            if process.returncode is None:
                process.kill()
                process.wait()
            raise
        elapsed = time.perf_counter() - started
        stdout.seek(0)
        actual_hash = hashlib.sha256()
        size = 0
        while block := stdout.read(65536):
            actual_hash.update(block)
            size += len(block)
        stderr.seek(0)
        diagnostic = stderr.read(65537)
        if process.returncode != case["expected_exit_code"]:
            raise RuntimeError(f"{case['name']}: exit {process.returncode}; {diagnostic.decode(errors='replace')}")
        if size != case["expected_stdout_bytes"] or actual_hash.hexdigest() != case["expected_stdout_sha256"]:
            raise RuntimeError(f"{case['name']}: decoded XML bytes differ from independent construction")
        if case["expected_error_offset"] is not None:
            expected = f"byte {case['expected_error_offset']}: string-pool index 100000 is out of bounds".encode()
            if expected not in diagnostic:
                raise RuntimeError(f"{case['name']}: wrong malformed-input diagnostic: {diagnostic!r}")
        elif diagnostic:
            raise RuntimeError(f"{case['name']}: unexpected stderr: {diagnostic!r}")
        return {"elapsed_seconds": round(elapsed, 6), "peak_rss_bytes": peak, "memory_method": memory_method, "final_peak_available": final_peak_available, "exit_code": process.returncode, "stdout_bytes": size}


def capture(*command: str) -> str:
    return subprocess.check_output(command, cwd=ROOT, text=True).strip()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--backend", choices=["all", "js", "native"], default="all")
    parser.add_argument("--repeats", type=int, default=3)
    parser.add_argument("--warmup", type=int, default=1)
    parser.add_argument("--timeout", type=float, default=30)
    parser.add_argument("--max-rss-mib", type=int, default=1024)
    parser.add_argument("--js", type=Path, default=ROOT / "_build/js/debug/build/cmd/axml/axml.js")
    parser.add_argument("--native", type=Path, default=ROOT / "_build/native/debug/build/cmd/axml-native/axml-native.exe")
    parser.add_argument("--output", type=Path, default=BUILD / "report.json")
    args = parser.parse_args()
    if not 1 <= args.repeats <= 20 or not 0 <= args.warmup <= 5 or not 0 < args.timeout <= 300 or not 16 <= args.max_rss_mib <= 4096:
        parser.error("require repeats 1..20, warmup 0..5, timeout (0, 300] seconds, RSS watchdog 16..4096 MiB")
    BUILD.mkdir(parents=True, exist_ok=True)
    backends = {}
    if args.backend in ["all", "js"]:
        if not args.js.is_file():
            parser.error("build the JS CLI first: moon build src/cmd/axml --target js --deny-warn")
        backends["js"] = ["node", "--max-old-space-size=256", os.path.relpath(args.js.resolve(), ROOT).replace(os.sep, "/")]
    if args.backend in ["all", "native"]:
        if not args.native.is_file():
            parser.error("build the native CLI first or pass --native: moon build src/cmd/axml-native --target native --deny-warn")
        backends["native"] = [str(args.native.resolve())]
    cases = make_cases()
    results = []
    for backend, command in backends.items():
        for case in cases:
            for _ in range(args.warmup):
                measure(command, case, args.timeout, args.max_rss_mib * 1024 * 1024)
            runs = [measure(command, case, args.timeout, args.max_rss_mib * 1024 * 1024) for _ in range(args.repeats)]
            seconds = [run["elapsed_seconds"] for run in runs]
            peaks = [run["peak_rss_bytes"] for run in runs if run["peak_rss_bytes"] is not None]
            result = {"backend": backend, "case": case["name"], "runs": runs, "elapsed_seconds": {"min": min(seconds), "median": round(statistics.median(seconds), 6), "max": max(seconds)}, "peak_rss_bytes_max": max(peaks) if len(peaks) == len(runs) else None}
            results.append(result)
            print(f"{backend:6} {case['name']:18} median={result['elapsed_seconds']['median']:.6f}s peak_rss={result['peak_rss_bytes_max']}", flush=True)
    source_paths = ["scripts/benchmark.py", "scripts/generate_fixtures.py", "moon.mod"] + [path.relative_to(ROOT).as_posix() for path in sorted((ROOT / "src").rglob("*")) if path.is_file() and (path.suffix == ".mbt" or path.name == "moon.pkg")]
    report = {
        "schema_version": 1,
        "measured_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "source_commit": capture("git", "rev-parse", "HEAD"),
        "tracked_changes_at_measurement": capture("git", "status", "--short", "--untracked-files=no").splitlines(),
        "source_sha256": {path: digest((ROOT / path).read_bytes()) for path in source_paths},
        "host": {"system": platform.system(), "release": platform.release(), "machine": platform.machine(), "python": platform.python_version(), "node": capture("node", "--version") if "js" in backends else None, "moon": capture("moon", "version", "--all")},
        "method": {"operation": "decode", "build_profile": "debug (unless overridden paths)", "warmup_runs_discarded_per_case": args.warmup, "measured_runs_per_case": args.repeats, "timeout_seconds_per_run": args.timeout, "rss_watchdog_bytes": args.max_rss_mib * 1024 * 1024, "poll_seconds": 0.005, "includes": "fresh child startup, input I/O, decoding, XML rendering, output to temporary file", "excludes": "fixture construction, parent Python memory, XML/hash verification, descendants", "note": "RSS watchdog is sampled, not a hard memory cap; POSIX checks RSS at process exit. Fresh-process warmups warm filesystem caches, not a persistent VM. No throughput or portable performance guarantee."},
        "backends": {name: {"command": [os.path.relpath(part, ROOT).replace(os.sep, "/") if os.path.isabs(part) else part for part in command], "artifact_sha256": digest((args.js if name == "js" else args.native).read_bytes())} for name, command in backends.items()},
        "cases": cases,
        "results": results,
        "all_correctness_checks_passed": True,
        "all_runs_have_final_peak_rss": all(run["final_peak_available"] for item in results for run in item["runs"]),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"Wrote {args.output}")


if __name__ == "__main__":
    main()
