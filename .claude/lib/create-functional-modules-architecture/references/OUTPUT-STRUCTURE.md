# Output Structure (deterministic)

This document is the canonical structure for the functional-modules markdown / PDF the skill produces. Every output document **must** follow this shape, in this order, with these section names. The aim is a deterministic, consistent deliverable that doesn't drift between runs.

## 1. YAML front matter (required)

```yaml
---
title: "<System Name> — Functional Modules"
subtitle: "Module-by-module catalogue of <SystemShort>'s functional surface"
---
```

The `--` between title and subject is an em-dash (`—`, U+2014), not a hyphen-minus. Do not include `author:` here — the build pipeline injects "Scrumconnect" automatically.

## 2. Lead paragraph + intent bullets

Two short paragraphs, in order:

1. One sentence: "This document catalogues `<SystemShort>`'s functional modules — what each does, who uses it, and how the modules fit together."
2. Bulleted list with **two** entries:
   - **Module** — definition (a first-class part of the application's functional surface, with its own H3 below).
   - **Sub-module / Cross-cutting** — definition (described in the source documents but presented under a parent module or in the closing `## Cross-cutting NFRs` section).
3. One paragraph naming the source documents and flagging the closed `Status` vocabulary used in the per-module tables (`Implemented`, `Partial`, `Discovery required`, `Out of scope`).

## 3. `## At a Glance` (required)

Single compact summary table with **all** modules in one place. Columns (in this order, no extras):

| `#` | `Module` | `Primary Users` | `Purpose` | `Status` |

Rules:

- One row per module (Module classification only — Sub-modules and Cross-cutting do **not** appear in this table). Number them 1..N **in narrative order**: top-level navigation order first (Home → primary functional ribbons → Reports / Admin), then back-office last.
- The `Module` cell is a plain module name in **bold** (e.g. `**Manage Judges**`); aliases / variants are not shown in this table.
- **Separator-dash widths are load-bearing.** Pandoc's pipe-table reader allocates `<col style="width:X%">` from the relative count of `---` characters in the header separator row. The mandatory pattern is `4 / 26 / 18 / 36 / 16` (dashes per column), which gives:
  - `#` → 4%
  - `Module` → 26%
  - `Primary Users` → 18%
  - `Purpose` → **36%** (the largest share, so its cells wrap to ≤ 2 lines)
  - `Status` → 16%
  Copy the separator row verbatim from the template; do *not* normalise the dashes for visual alignment in the source — the lopsided-looking dash counts are intentional.
- Cells must be **terse — aim for 1–8 words per cell** so the whole table fits on a single page. Drop redundant qualifiers ("module", "ribbon"), prefer short user labels ("RSU; Court" over "Regional Support Unit users; Court (Full Access) users"), and let the per-module *Attribute / Detail* table carry the full description.
- A short paragraph above the table explains that each row corresponds to a numbered detail section.

## 4. `## Module overview` (required)

Exactly one Mermaid `flowchart LR` block, pre-rendered to PNG by the build pipeline.

Required structural conventions:

- **Three subgraphs** grouping modules by domain — typical groupings are `Operational` (planning / scheduling / activity), `Finance` (payments / reconciliation), `Admin & MI` (admin / reporting). Adapt the names to the source domains; cap at three subgraphs.
- Each subgraph uses `direction TB` so nodes stack vertically.
- **All containers are plain rectangles (ArchiMate style)** — `M["1. Module<br/>name"]`. Do not use cylinders, circles, or any other special Mermaid shape. The hub-vs-domain distinction is conveyed by the subgraph clustering, not by shape variation.
- Each module node label is **prefixed with its number** from the At-a-Glance table: `["1. Home"]`.
- Solid arrows for explicit cross-module flows the source documents call out (e.g. *Vacancies → Fee-paid Bookings → Payments*); **dashed arrows** (`-.->`) for `Discovery required` or `Out of scope` modules.
- Edge labels short (≤ 4 words), multi-line via `<br/>` — never `\n`.

## 5. `## Modules` H2

Then a single H2 section heading:

```markdown
---

## Modules

These are the first-class functional modules of <SystemShort>. Each section below mirrors the row above in the *At a Glance* table and provides the full Capabilities list, Attribute / Detail summary and Sources for that module.
```

## 6. Numbered module detail entries

For **every** Module-classified row in the At-a-Glance table, in numerical order, repeat:

```markdown
### N. <Module>

<Lead paragraph: 1–2 sentences. Explain what this module does and who uses it. Name the module in **bold** on first reference.>

**Capabilities**

- <capability 1 — ≤ 1 line>
- <capability 2 — ≤ 1 line>
- ...

| Attribute | Detail |
|-----|--------------------|
| **Module ID** | <stable short ID, e.g. `MJ`, `JIT`, `PAY`, or CapitalCase if no prefix exists> |
| **Primary users** | <semicolon-separated user roles> |
| **Trigger / entry points** | <how users reach the module — top-level tab, sub-menu, deep-link from another module> |
| **Inputs** | <data the module consumes; cross-reference inbound dependencies in `data-dependencies.md` where they exist> |
| **Outputs** | <data the module produces; cross-reference outbound dependencies similarly> |
| **Business rules** | <semicolon-separated non-trivial rules from the source> |
| **Cross-module dependencies** | <named links to other modules in this document; or "None" if the module is standalone> |
| **NFRs** | <module-specific NFRs — performance budgets, audit, role-based access; or "Cross-cutting only" if module-specific NFRs aren't documented> |
| **Status** | <one of `Implemented` / `Partial` / `Discovery required` / `Out of scope`> |

**Key user actions** *(optional — omit for purely back-office or read-only modules)*

- **WHEN** <user action> **THEN** <system response>
- **WHEN** <user action> **THEN** <system response>

> Sources: *<Doc name>* (section reference); *<Doc name>* (section reference).
```

The nine `Attribute / Detail` rows are **mandatory** in the order shown. If a value is genuinely unknown, write `Unknown` rather than dropping the row.

The **`Status` cell uses a closed vocabulary** — the value must be **exactly** one of these strings, matched verbatim (no paraphrases):

| Value | When to use it |
|----|----|
| `Implemented` | The module's documented capabilities are live in the application as described. |
| `Partial` | Some documented capabilities are live; others are stated but not yet implemented (e.g. discovery items). |
| `Discovery required` | The source documents explicitly mark the module as "not supported — Discovery required" or equivalent. |
| `Out of scope` | The source documents name the module but explicitly exclude it from the as-is system. |

The Phase 2d cross-check (item 5) rejects any non-conforming `Status` string before authoring proceeds.

**Separator-dash widths are load-bearing here too.** Use the exact pattern `|-----|--------------------|` (5 dashes / 20 dashes) so pandoc allocates the columns at **20% / 80%** — narrow Attribute label, wide Detail. Don't normalise the dashes to look symmetrical; the lopsided count is intentional.

## 7. (Optional) `## Cross-cutting NFRs`

Include this section **only** when the source documents describe NFRs that apply across every module (e.g. authentication, audit, role-based access, accessibility, performance budgets). Format as a bulleted list, one short bullet per NFR, with a `> Sources:` blockquote at the end.

```markdown
---

## Cross-cutting NFRs

- **Authentication** — All modules require an authenticated session (...).
- **Audit** — All create/update/delete actions are auditable with user, timestamp and before/after values.
- **Accessibility** — All UI complies with HMCTS accessibility standards (keyboard navigation, ARIA labels).

> Sources: *JI Functional and Non-Functional Requirements* (Home NFR-04, Manage Judges NFR-03).
```

If the source documents describe no system-wide NFRs distinct from per-module ones, omit this section entirely.

## 8. `## Summary`

Three to five bullet points. Topics, in order of preference:

- How many modules are `Implemented` vs `Partial` vs `Discovery required` vs `Out of scope`.
- The most operationally critical end-to-end flow — describe it using **module names**, not row numbers (e.g. *"Manage Judges → Court Itinerary → Sittings → Reports"*).
- Any notable gaps or *Discovery required* modules.

## 9. (Optional) `## Appendix`

Include this section **only** when a structural decision in the document genuinely needs explaining for the reader (e.g. why a sub-module is presented under a parent rather than as its own H3, or why a module mentioned in the source documents was deliberately ruled out of the catalogue).

Each appendix item is a single short bullet — a fact and its justification, sourced where possible. The body prose of the document never carries this reasoning; it lives here, where readers who want it can find it and others can skip it.

If there is nothing structurally non-obvious to record, omit the section entirely — don't add an empty placeholder.

## 10. `## Source Documents`

```markdown
This analysis is based **only** on the following documents in `<input-folder-name>/` (top-level files; subfolders not consulted):

- `Document 1.docx`
- `Document 2.doc`
- ...

Plain-text extractions of these documents were produced alongside the input folder at `<input-folder>/output-functional-modules/extracted-text/` and used as the basis of analysis without loading the binary documents into memory.
```

This list must exactly match the files actually present at the top level of the input folder when the skill ran. Don't list documents that weren't read.

---

# Phase 2 artefact shapes

## `module-aliases.json`

Two top-level keys, mirroring the data-dependency skill's `system-aliases.json`:

```json
{
  "canonical_to_aliases": {
    "<canonical name>": ["<alias 1>", "<alias 2>", "..."],
    ...
  },
  "aliases_to_canonical": {
    "<alias 1>": "<canonical name>",
    "<alias 2>": "<canonical name>",
    ...
  }
}
```

Every alias listed under `canonical_to_aliases` MUST round-trip through `aliases_to_canonical`. Every canonical name in `canonical_to_aliases` corresponds to one row in `module-enumeration.md`.

## `module-enumeration.md`

Header section followed by a five-column table:

```markdown
# Module Enumeration — <System Name>

| Canonical name | Aliases | Classification | Status | Citation |
|----|----|----|----|----|
| Home | Home Ribbon; Home page | Module | Implemented | *<Doc>* §<ref> |
| Manage Judges | Judges; Judges Ribbon | Module | Implemented | *<Doc>* §<ref> |
| Forward Look | Judges Forward Look | Sub-module | Implemented | *<Doc>* §<ref> |
| Tribunal Support | — | Ruled out | Discovery required | *<Doc>* §<ref> — listed but explicitly out of scope |
```

Aliases are semicolon-separated. `Classification` is one of `Module`, `Sub-module`, `Cross-cutting`, `Ruled out`. `Status` uses the closed vocabulary.

## `module-phase-2d-checks.md`

The seven fixed checklist items in `SKILL.md`. Each item marked ✅ with a one-line justification or ❌ with the resolution action. Authoring is gated on every item being ✅.

---

# Numbering, anchors and cross-references

Pandoc-generated heading IDs **strip leading numbers** when emitting HTML anchors. So `### 7. Reports` becomes anchor `#reports`, not `#7-reports`. When you write cross-references, use the no-number form:

```markdown
✅ [Manage Judges](#manage-judges)
❌ [2](#2-manage-judges)
```

The link **text** uses the module *name*, not its row number — see the prose-style rules below.

# Prose style — what NOT to write in the document

The document's prose explains *what* the modules do and *what* their attributes are. It never explains *why* the document is structured the way it is. Two patterns to avoid in body prose:

## No skill-internal reasoning

Do not leak the skill's authoring conventions into the prose. Phrases like *"per the OUTPUT-STRUCTURE convention"* or *"as the structure dictates"* are noise to the reader — they care about the modules, not about how we organised the document.

If a particular structural decision *genuinely* requires explanation, put a one-line note in the optional `## Appendix` section. Don't pollute body prose with it.

## No numeric module references in prose

Tables (the `#` column in *At a Glance*) and diagrams (the `1. Home` style node labels) use numbers — that's their job. **Body prose uses names.** When referring to another module in prose, link the *name*, not the number:

```markdown
✅ "the [Payments module](#payments) consumes confirmed bookings from the [Fee-paid Bookings module](#fee-paid-and-other-bookings)"
❌ "Module 8 consumes confirmed bookings from Module 7"
```

# Style enforcement

The output is rendered with the **shared** house stylesheet (`.claude/lib/create-data-dependency-architecture/assets/doc-style.css`) and Mermaid theme (`.claude/lib/create-data-dependency-architecture/assets/mermaid-config.json`). Authors should never bake colour, font or border choices into the document — the stylesheet handles all visual concerns. If a one-off override seems necessary, raise it as a stylesheet change so every doc benefits (this affects both the data-dependency skill and this one).
