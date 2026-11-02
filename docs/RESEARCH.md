# AXML topic recheck

[中文](RESEARCH_zh.md) | [Project](../README.md) | [Machine evidence](../evidence/recheck.json)

Latest review: **2026-11-02, UTC+8**; initial review: **2026-11-01**. Decision: recommend local initiation of a complete AXML reader/library plus offline CLI. This review does not constitute contest acceptance.

## Repeat check: 2026-11-02

The [Mooncakes modules endpoint](https://mooncakes.io/api/v0/modules) returned **3,520 records**, up from 3,518 in the initial review. Case-insensitive metadata searches for `axml`, `resxml`, `arsc`, and `aapt` returned no matches. The five `android` matches describe JNI, accessory transport, WASI hosting, app scaffolding, or UI integration. The binary-XML and APK matches remain Apple plist, Windows EVTX/BINXML, and Alpine packages. This is metadata discovery, not an exhaustive source audit.

Fresh GitHub code searches returned zero matches for `RES_XML_TYPE` and `RES_STRING_POOL_TYPE` with `language:MoonBit`, and for `ResXMLTree`, `RES_XML_START_ELEMENT_TYPE`, `AXMLParser`, `AXMLPrinter`, and `binary_xml` with `extension:mbt`. The broader `AXML` query returned 27 hits, inspected as RAxML/PDF identifiers, Base64 content, or legacy non-MoonBit XML. Five AndroidManifest hits belong to app builders or text-manifest templates, not binary decoders. Public issue/PR title-and-body searches for AXML with MoonBit found no matching proposal; broad comment matches were unrelated. These searches do not cover private submissions or every development branch.

Fresh web queries covered the project name, AndroidManifest, binary XML, format constants, English/Chinese aliases, and indexed Gitee/GitLink results. Additional related projects were inspected: [xml-mbt](https://github.com/moonbit-community/xml-mbt) explicitly consumes XML text through `Reader::from_string`; [thy1016/moonxml](https://www.gitlink.org.cn/thy7/mbt.xml) parses and serializes text XML. Neither README describes Android binary chunk decoding. [androguard/axml-parser](https://github.com/androguard/axml-parser) already provides overlapping AXML/ARSC and CLI functionality in Rust with optional Python bindings; the potential gap is specifically a MoonBit implementation.

Evidence: [registry queries](../evidence/registry-recheck-2026-11-02.json), [GitHub queries and source inspections](../evidence/github-recheck-2026-11-02.json), and [web queries and inspected sources](../evidence/web-recheck-2026-11-02.json). Preserve the initial evidence rather than replacing its dated results. No equivalent MoonBit Android AXML library or CLI was located in these checks. Private work, unindexed repositories, non-default branches, and private submissions remain outside the evidence.

## Initial review method: 2026-11-01

The Mooncakes public modules endpoint was refreshed to 3,518 records. The full metadata snapshot was searched across name, description, keywords and repository using AXML, APK, Android, XML, plist and related terms. Metadata does not prove source-level capability or cover all unpublished work.

GitHub connector repository search included `MoonBit axml`, `android language:MoonBit`, and `"binary xml" language:MoonBit`. Code search included `AXML language:MoonBit`, `"RES_XML_TYPE" language:MoonBit`, `"RES_STRING_POOL_TYPE" language:MoonBit`, `"AndroidManifest" language:MoonBit` and `"binary xml" language:MoonBit`. The AXML-specific constant queries returned no indexed matches. The broad AXML query matched RAxML biology code and PdfMetadataXml substrings, not Android decoding.

Web aliases included `MoonBit AXML AndroidManifest binary XML`, `MoonBit "binary XML" Android`, and `MoonBit AXML parser`. Detailed recorded queries and results are in the machine evidence. Search covers public/indexed content; private repositories, new unindexed projects and non-default branches remain unknown.

## Existing projects inspected

| Existing project / inspected source | Actual functionality | Why it does not close this gap |
| --- | --- | --- |
| [moonbitstack/moonxml README](https://github.com/moonbitstack/moonxml/blob/master/README.md) | XML 1.0 text and HTML trees, selectors, XPath | Does not describe Android ResXMLTree chunks/string pools |
| [MoonPlist README](https://github.com/Han-Wentao/moonplist/blob/codex/moonplist/README.md) | Apple bplist00 and plist XML | A separate binary format/object model |
| [MoonEvtx README](https://github.com/kekeshuo/moonevtx/blob/main/README.md) | Microsoft EVTX/BINXML | Different file headers, token stream and event model |
| [linuxpkg README](https://github.com/pxgt/linuxpkg/blob/main/README.md) | Linux package building, including Alpine .apk | Alpine .apk is unrelated to Android .apk |
| [still.fail APK tool source](https://github.com/AFK-surf/still.fail/blob/main/apps/mbui/mbui/tools/apk/main.mbt) | Calls SDK aapt2 and handles source/AAR text manifests | A build orchestrator, not an in-process binary manifest reader |

No equivalent was located in the reviewed public scope. A parser that only recognizes a file header is not a sufficient deliverable; the meaningful gap is reusable typed decoding plus real manifest workflows.

## Upstream maturity and reproducible references

| Reference | Revision / license | Role |
| --- | --- | --- |
| [AOSP ResourceTypes.h](https://github.com/aosp-mirror/platform_frameworks_base/blob/d67e90e8a8301a87726420a1071fca8e52172bd4/libs/androidfw/include/androidfw/ResourceTypes.h) | d67e90e8a8301a87726420a1071fca8e52172bd4; Apache-2.0 | Canonical chunk types, string pools, attributes and typed values |
| [Java apk-parser](https://github.com/hsiafan/apk-parser/tree/4d5a08e4d28fa2fce7fa356394c62c5e51a192e2) | 4d5a08e4d28fa2fce7fa356394c62c5e51a192e2; BSD-2-Clause | Mature established API; 1,284 stars on review; archived, so not sole format authority |
| [androguard/axml-parser](https://github.com/androguard/axml-parser/tree/93d008a7ce337fb9bafb708bc8ce93ecdc25f80b) | 93d008a7ce337fb9bafb708bc8ce93ecdc25f80b; Apache-2.0 | Reference decoding and tests/AXML fixtures |
| [Official APK Analyzer](https://developer.android.com/studio/debug/apk-analyzer) | Official Android documentation | Real task: reconstruct and inspect the final merged binary manifest |

The reviewed Rust test file has tests for UTF-8, namespaces, CDATA/text, malformed string-pool headers, null bytes and nonterminated strings. Some upstream fixtures intentionally target permissive repair. The MVP must record whether it supports each file, rejects it clearly, or differs by documented policy; do not promise identical repair behavior.

## Test-corpus plan

Generate owned fixture sources with a pinned aapt2: a minimal app manifest, multilingual strings, namespace/attribute variations and compiled menu XML. Save binary SHA-256, source XML, aapt2 reference dump, semantic expected records, reference revision and reproduction command.

Use the pinned androguard corpus as an additional differential source only after recording each fixture's provenance and redistribution status. Avoid redistributing arbitrary APKs just because they appear in a test directory. Synthetic malformed input should cover truncation, count/offset overflow, invalid string indices, broken UTF-16 pairs and unbalanced events.

The review has not downloaded fixture binaries, built aapt2, run or passed implementation tests, or benchmarked MoonBit code. Repository metadata was checked live; source revisions above are reproducibility references, not claims that every upstream code path is validated.

## Application and acceptance gates

Before applying, repeat duplicate discovery and document the proposed scope and unresolved resource-ID limitation. Before acceptance, demonstrate the three workflows against reference data; publish only after actual CI evidence exists. Application approval and rewards remain the organizer's decision.
