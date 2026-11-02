---
name: MoonAXML
description: A dark, warm-toned workbench for inspecting binary XML.
colors:
  ground: "#24231f"
  plate: "#292823"
  ink: "#ece5d4"
  muted: "#b6ac98"
  faint: "#8e8573"
  rule: "#615743"
  soft-rule: "#443e32"
  accent: "#ce6857"
  accent-hover: "#df806f"
typography:
  display:
    fontFamily: "Alegreya, Georgia, serif"
    fontSize: "2.15rem"
    fontWeight: 500
    lineHeight: 1
    letterSpacing: "-0.035em"
  headline:
    fontFamily: "Alegreya, Georgia, serif"
    fontSize: "1.5rem"
    fontWeight: 400
    lineHeight: 1.15
  title:
    fontFamily: "Alegreya, Georgia, serif"
    fontSize: "1.25rem"
    fontWeight: 400
  label:
    fontFamily: 'Arial, "Noto Sans SC", "Microsoft YaHei", sans-serif'
    fontSize: "0.875rem"
  data:
    fontFamily: '"SFMono-Regular", Consolas, "Liberation Mono", monospace'
    fontSize: "0.875rem"
    lineHeight: 1.9
  metadata:
    fontFamily: '"SFMono-Regular", Consolas, "Liberation Mono", monospace'
    fontSize: "0.75rem"
    lineHeight: 1.6
  search:
    fontFamily: 'Arial, "Noto Sans SC", "Microsoft YaHei", sans-serif'
    fontSize: "1rem"
spacing:
  compact: "0.75rem"
  standard: "1rem"
  section: "1.5rem"
  folio-inline: "1.6rem"
components:
  button-primary:
    backgroundColor: "#b34e3e"
    textColor: "#fff4df"
    typography: "{typography.label}"
    padding: "0.65rem 1rem"
  button-primary-hover:
    backgroundColor: "#9e4134"
  button-primary-active:
    backgroundColor: "#a14638"
  button-text:
    textColor: "{colors.muted}"
    typography: "{typography.label}"
    padding: "0.4rem 0.2rem"
  folio:
    backgroundColor: "{colors.plate}"
    textColor: "{colors.ink}"
  tab-selected:
    textColor: "{colors.ink}"
  table-search:
    backgroundColor: "{colors.ground}"
    textColor: "{colors.ink}"
    typography: "{typography.search}"
    padding: "0.65rem 0.8rem"
---

# Design System: MoonAXML

[中文](DESIGN_zh.md)

## Overview

**Creative North Star: "Continuous Folio"**

MoonAXML uses a continuous, ruled folio: warm charcoal supports ivory content, serif headings mark changes in reading context, and compact interface controls leave most of the page to the inspected artifact. The XML-bracket and binary-block mark is the identity asset.

The system is flat and restrained. Color marks actions, selection, and diagnostics; spacing and sepia rules organize information. English and Chinese share the same controls and reading hierarchy.

**Key Characteristics:**

- Warm dark surfaces, ivory text, and sepia divisions.
- Alegreya branding and headings; system sans-serif controls and monospaced data.
- Square controls and one continuous result surface.
- Fixed reading sizes with explicit responsive adjustments.

This record describes the implemented browser workbench. Ground truth is [the stylesheet](playground/src/style.css), [the markup](playground/index.html), and [the controller](playground/src/main.ts). The reviewed search-extension captures are the desktop (1440 px), mobile (390 px), and user-width (723 px) views in `.impeccable/review/round2/`. Surface composition belongs to [the surface brief](.impeccable/surfaces/playground-index-html.md); product capabilities belong to [PRODUCT.md](PRODUCT.md). This document does not establish deployment status.

## Colors

The frontmatter contains the reusable palette. The interface has one scarlet accent family and warm neutrals.

### Primary

- **Scarlet accent** (`accent`): the selected-view underline, processing indicator, and source-selection border.
- **Light scarlet** (`accent-hover`): keyboard focus, source links, pressed text controls, and error headings.
- The primary file action uses its own darker scarlet background and warm light text; the exact default, hover, and active values live in the frontmatter component variants.

### Neutral

- **Charcoal ground** (`ground`) supports the outer workspace; **warm charcoal plate** (`plate`) carries the result folio.
- **Ivory ink** (`ink`) carries headings and primary information; **aged-paper muted** (`muted`) carries supporting labels and context.
- **Sepia rule** (`rule`) divides main regions; **soft sepia rule** (`soft-rule`) divides rows and internal regions.
- **Faint sepia** (`faint`) outlines the search fields, providing a visible control boundary against the ground (4.31:1 contrast).

**The Restrained Scarlet Rule.** Use scarlet for actionable controls, selected-view markers, source links, focus, and diagnostics; keep long-form result data neutral.

The sidecar's tonal ramps are synthesized preview metadata, not additional implemented palette tokens.

## Typography

Alegreya gives the brand and headings their printed character. Arial, with Noto Sans SC and Microsoft YaHei fallbacks, carries functional interface text. Data uses SFMono-Regular, Consolas, Liberation Mono, then monospace. CJK glyphs use the available fallback fonts.

### Hierarchy

- **Display:** the wordmark uses the display role; its AXML suffix is italic. It becomes smaller (1.75rem) on narrow screens.
- **Headline and title:** result headings use the headline role; content subheadings use the title role. Four-view selectors use Alegreya (1.3125rem desktop; 1.0625rem narrow).
- **Labels:** primary and text actions, sample selection, and header navigation use the label role. Supporting UI text generally stays at the smaller reading step (0.75rem).
- **Search:** native search fields use the system sans-serif stack at the search role (16px), retaining that reading size on narrow screens.
- **Data:** XML uses the data role, changing to 0.8125rem with line-height 1.85 on narrow screens. Tables use monospaced cells (0.8125rem); package identifiers use a larger mono step (1rem). Metadata uses tabular numerals where appropriate.

**The Fixed Reading Scale Rule.** Keep data and control sizes tied to their reading role. Change layout before reducing the type scale.

The build imports Alegreya Latin regular (400), medium (500), and regular italic (400) through `@fontsource/alegreya`, so font assets are served with the static application. Preserve [the bundled SIL OFL notice](playground/public/third-party/Alegreya-OFL.txt). There is no external font-service dependency in these imports.

## Layout

The centered workspace is capped at 92rem, with a desktop width of `min(100% - 7rem, 92rem)`. A masthead, input row, aligned view selectors, result heading, result body, and context rail share its edges. Four equal selector columns remain in one row at every supported width.

| Condition | Implemented adjustment |
| --- | --- |
| Above 100rem | Outer width becomes `min(100% - 10rem, 92rem)`. |
| At or below 68em | Side gutters become 1.75rem; file metadata can wrap; statistics use two columns. |
| At or below 45em | Side gutters become 1rem; the brand purpose is hidden; input controls fill a row; result actions move below the heading; context can wrap. |

Result content uses the folio-inline inset on desktop and the standard inset on narrow screens. Declaration rows use a label/value grid; the label column becomes 7rem on narrow screens. Statistics use three columns on desktop and two at narrower widths. Tables scroll inside their own width rather than stretching the page.

The result panel has a minimum height (27rem desktop; 24rem narrow). The XML reading area is bounded vertically (42rem maximum) and scrolls locally. XML wrapping is enabled initially; its line gutter is hidden in wrapped mode. Turning wrapping off restores the source-line gutter and horizontal scrolling. These are viewing choices, not edits to the decoded output.

## Elevation & Depth

The implemented system uses tonal layering and rules, with no box-shadow vocabulary. The result plate is only slightly lighter than the ground. Hover, selection, and the file-drop overlay convey state without lifting components.

**The Tonal Separation Rule.** Separate regions with the ground/plate relationship and one-pixel sepia rules; do not add raised card shadows.

State changes use short color transitions (160ms, ease-out). Loading rules and the processing dot pulse in place (1s, ease-in-out). The reduced-motion media query removes animations and transitions. There is no entrance choreography.

## Shapes

Controls, result regions, tables, and dividers use square geometry. One-pixel borders and rules supply structure; the selected-view marker is a short two-pixel underline. The small lock and folder symbols are inline SVG; the brand is [the dedicated SVG mark](playground/public/brand/moonaxml.svg). There are no shipping raster illustrations in this workbench.

## Components

### File controls and actions

The native sample selector sits inside a ruled rectangular control. The primary file action is a filled scarlet rectangle with an inline folder icon; both controls have a minimum height (2.75rem). Text actions are muted at rest and ivory on hover. Pressed wrap control text uses light scarlet. Disabled buttons reduce opacity (0.4).

Interactive controls receive a light-scarlet outline on keyboard focus (2px, offset 4px). The skip link becomes visible when focused. Loading and error states remain explicit text, with live status announcements.

### Registered view navigation

XML, Manifest, Structure, and References share the same input. Separators align the four equal columns. The selected tab combines ivory text and the scarlet underline. Tabs use selected state, controlled panels, and roving focus; Left/Right, Home, and End move between views.

### Local table search

Structure and References each use a visibly labeled native search field, a clear text action, and a polite matched/available count. The field has a square one-pixel faint-sepia border, ground background, ivory text, muted placeholder, and light-scarlet caret. Keyboard focus uses a two-pixel light-scarlet outline with a three-pixel offset. Fields and clear actions are at least 44px high, rising to 48px at or below 45em; summaries stack on narrow screens.

Filtering trims and lowercases a literal substring against raw names, kinds, namespace URIs, reference origins, and decimal or hexadecimal IDs/offsets as applicable. It retains the input node while updating result rows and defers filtering during IME composition. Native input behavior handles Enter. Queries persist across tabs and language changes and reset for a new file or sample. Clear restores the available rows and returns focus to the field. Zero matches use concise factual text.

Structure searches only the original preview of up to 1,000 events. Following a source action clears its query and locates the original preview page. Copy and download ignore both queries; Structure JSON still contains only that bounded event preview. Table pages remain 50 rows, and narrow tables scroll locally.

### Result folio and data rows

The folio combines a serif heading, a concise context line, actions, a data surface, and a bottom context rail. XML is monochrome, selectable text. Manifest declarations use paired fields, ruled lists, and native expandable raw-value details. Statistics and table rows use tabular numerals and fine internal rules.

The reference/source action is an underlined light-scarlet control. It selects the corresponding original byte offset, opens Structure, selects the matching event-preview page, and displays the original event when it is available. Selection is also described in the context rail.

### Diagnostics and bounded previews

Diagnostics use a scarlet serif heading, the stage and source location, and a concise recovery action. Stage-specific failure preserves other available views. Empty results use compact factual text.

The UI labels the local-input budget (16 MiB), watchdog (10 seconds when triggered), XML preview limit (100,000 UTF-16 units), and declaration previews (50 entries per category when truncated). Table navigation displays 50 preview rows per page. Copy and download operate on the complete available view output, not the visible XML/declaration slice.

Local files go to a cancellable module worker using the compiled pure MoonBit bridge. The app fetches its own samples and static assets; it does not upload selected file contents or filenames. These constraints govern diagnostic wording and input affordances; they are implementation facts, not conclusions drawn from screenshots.

## Do's and Don'ts

### Do:

- **Do** preserve the warm dark palette, the XML-bracket mark, and the serif/sans/mono role split.
- **Do** keep source values readable with wrapping or a bounded local scroll area.
- **Do** give each action a visible keyboard-focus treatment and an accurate state.
- **Do** keep bilingual labels concise and allow long filenames and values to wrap.

### Don't:

- **Don't** apply scarlet to entire result sheets or add decorative surface effects.
- **Don't** replace the continuous folio with nested cards or rounded promotional chips.
- **Don't** imply resource resolution, Android defaults, uploads, or a security verdict.
- **Don't** introduce decorative onboarding, invented evidence, or unverified deployment claims.
