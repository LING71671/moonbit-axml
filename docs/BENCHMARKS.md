# Bounded stress benchmarks

[中文](BENCHMARKS_zh.md) | [Acceptance](ACCEPTANCE.md) | [Project](../README.md)

## Reproduce

Use the pinned MoonBit toolchain, Python 3.10+, and Node.js 22. No Python packages, Android SDK, network access, or account credentials are required.

```sh
moon build src/cmd/axml --target js --deny-warn
moon build src/cmd/axml-native --target native --deny-warn
python scripts/benchmark.py --output _build/benchmarks/report.json
```

Run from the repository root. Select `--backend js` or `--backend native` to measure one host. `--js PATH` and `--native PATH` select different artifacts; disclose their build profile when comparing results. The native default ends in `.exe` on Linux as well as Windows, matching MoonBit's build output. To replace the committed snapshot intentionally, pass `--output evidence/benchmark.json`.

## Scenarios and correctness

The generator constructs AOSP binary XML chunk layouts independently of the MoonBit implementation. All generated files and temporary output remain under ignored `_build/benchmarks/`.

| Case | Workload | Required result |
| --- | --- | --- |
| `large_pool` | Exactly 100,000 UTF-8 string-pool entries, one root | Successful XML matching independent expected bytes |
| `max_depth` | Exactly 256 nested elements, 512 events | Successful XML at the default depth limit |
| `repeated_strings` | 2,048 attributes reference one escaped 4,096-unit string; 8,454,158 output bytes | Successful expanded XML, including escaping |
| `malformed_input` | Full 100,000-entry pool followed by an invalid final end-name index | Exit 1, empty stdout, exact failing byte offset and index diagnostic |

Each valid run checks output length and SHA-256 against independently constructed XML; malformed runs check the error. Input size, SHA-256, strings, UTF-16 units, depth, event count, artifact hashes, source hashes, versions, commands, and every measured run are included in the JSON report.

## Measurement method

The default is one discarded warmup and three measured fresh processes per backend/case. Warmups warm filesystem caches; they do not warm a persistent VM. Wall time includes child startup, input I/O, decoding, rendering, and writing to a temporary file. Fixture generation, Python parent memory, correctness checks, and descendants are excluded. Disk output avoids retaining captured XML in the parent during measurement.

On Windows, `GetProcessMemoryInfo.PeakWorkingSetSize` supplies child lifetime peak working-set bytes, including a final query after exit. On Linux/macOS, `wait4.ru_maxrss` supplies the child's high-water RSS (normalized to bytes). Unsupported platforms explicitly report unmeasured memory. A failed final Windows query is marked as polled-only; it cannot establish the full lifetime peak. RSS is process resident memory, not V8 heap size.

Each run has a 30-second timeout and a 1-GiB RSS watchdog. Windows polls every 5 ms; POSIX checks RSS at exit. These are watchdogs, not hard resource caps. Node additionally receives `--max-old-space-size=256`, limiting V8 old-space, not total RSS. `--timeout`, `--max-rss-mib`, `--repeats`, and `--warmup` are configurable within bounded ranges.

## Recorded Windows snapshot

[Raw evidence](../evidence/benchmark.json) records the debug builds on Windows x86-64, Python 3.13.14, and Node.js v22.22.1. All 24 measured runs passed correctness checks and supplied final lifetime peak counters. Times below are medians; memory is the largest peak among three measured runs.

| Case | JS seconds / peak MiB | Native seconds / peak MiB |
| --- | --- | --- |
| Large pool | 0.136794 / 71.5 | 0.104191 / 15.8 |
| Maximum depth | 0.093046 / 47.4 | 0.021781 / 9.4 |
| Repeated strings | 0.222790 / 70.4 | 0.172407 / 41.5 |
| Malformed input | 0.136351 / 71.7 | 0.104101 / 15.7 |

These are bounded regression observations on one host, not portable throughput, constant-memory, zero-copy, or hard worst-case guarantees. Startup and concurrent host activity materially affect short runs. The committed report identifies the source commit plus source/artifact hashes because measurement may precede the commit that adds the report.

Before span-preserving XML escaping was implemented, this 2,048-reference case exhausted the 256-MiB V8 heap in an exploratory JS debug run. The recorded snapshot reruns that workload successfully after the rendering fix. The default XML output limit still does not guarantee success under every externally imposed heap limit or on every input within that limit; larger-output performance requires separate measurement.
