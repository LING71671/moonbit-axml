# Candidate portfolio: four retained, Sonic deferred

[简体中文](PORTFOLIO_zh.md)

Corrected on 2026-11-02: **Sonic is deferred due to [core overlap with MoonMel](https://github.com/1zhouhaoran1/MoonMel/blob/b49eb6d239ae148a9782f4495332090bc1ee727c/src/features/effects/effects.mbt#L110); its previous duplication-clearance assessment is withdrawn.** Five folders remain, representing four retained candidates and one deferred research proposal. The other four were not re-audited in this pass; see each README for actual implementation status.

| Suggested order | Project | Budget (8-hour person-days) | State |
| --- | --- | --- | --- |
| 1 | [Android binary XML](../../moonbit-axml/README.md) | 7–10 | Prior candidate retained; progress in README |
| 2 | [Beanstalkd job queue client](../../moonbit-beanstalkd/README.md) | 6–9 | Prior candidate retained; progress in README |
| — | [Sonic pitch-preserving speed processing](../../moonbit-sonic/README.md) | Excluded from active budget | Deferred: core overlap; independent value unproven |
| 4 | [Standard EDN reader and writer](../../moonbit-edn/README.md) | 8–10 | Prior candidate retained; progress in README |
| 5 | [Android sparse image toolkit](../../moonbit-android-sparse/README.md) | 7–10 | Prior candidate retained; progress in README |

Excluding deferred Sonic, the four original budgets total **28–39 person-days (224–312 hours)**, before rework and without subtracting subsequent completed work. This is not a new remaining-effort estimate. See individual README and acceptance records for current progress.

## Original gates for retained candidates (Sonic withdrawn)

1. A mature implementation or authoritative standard exists, with identifiable users.
2. Public research did not locate a MoonBit implementation equivalent to the proposed scope; related libraries were compared by actual functionality.
3. The result must be a reusable library with executable scenarios and interoperability checks, beyond a few matching rules or header parsing.
4. Scope, error semantics, and completion criteria can be checked against a reference implementation or corpus.
5. Each project must provide independent value; this assessment is withdrawn for Sonic; the portfolio is not a split submission.

These are research judgments, not organizer approval of value, eligibility, or payments. The five registrants must describe actual contributions and collaboration accurately. Identities, repository owners, and registration details are not configured.

## Excluded directions

| Direction | Reason and evidence |
| --- | --- |
| Avro schema evolution | [MoonAvro](https://github.com/ppyj663/MoonAvro), absent from this registry snapshot, already implements writer-to-reader resolution. |
| Memcached Meta | An [existing client](https://github.com/lexchb/moonbit-memcached) makes this an extension rather than an entirely missing client. |
| Compressed NPZ | The [existing NPY/NPZ library](https://github.com/ShunjunGu/moon-npy) leaves a narrow DEFLATE addition that is thin as a separate project. |
| EditorConfig, gettext, URI Template, semver ranges | Existing MoonBit implementations were located; these are not restored as new-project candidates. |
| Binary logcat | A real use case, but narrower in the original selection. |

## Research limits and event dates

Research covered 3518 public Mooncakes module records, GitHub repositories/code, and web searches using aliases. See this project's RESEARCH documents and evidence files for queries, related implementations, and sources. Public search cannot rule out private work, unindexed branches, or unpublished in-progress projects. The defensible statement is that no equivalent implementation was located within the recorded search scope and date.

The [official website](https://moonbitlang.github.io/Hackathon2026/) and its [source](https://github.com/moonbitlang/Hackathon2026/blob/main/src/App.tsx) still show the October round and October 31 deadline in this review. November-specific dates and terms remain unverified.

Applicants must understand their proposals. These AI-assisted research notes must not be represented as manually authored application text. Before publication, repeat duplication checks, confirm licenses and authorship, and establish public development history under the updated round rules.


## Corrective discovery method

Full metadata matching is not a full source audit. MoonMel appeared in the old audio matches, but its feature-extraction summary led to the effects API being missed. Inspect every relevant package tree, public API and implementation, including aliases such as `time_stretch`, `timeStretch` and `phase_vocoder`. Zero indexed search hits cannot replace API inspection.
