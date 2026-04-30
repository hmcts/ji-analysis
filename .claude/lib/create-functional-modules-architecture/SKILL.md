---
name: create-functional-modules-architecture
description: Use when the user asks to produce a module-organised functional architecture document for a system from a folder of source binary documents (.docx, .doc, .pdf, .md, .txt). The skill distils the binaries to plain text, identifies the application's functional modules, writes a deterministic Markdown document with a top-level "At a Glance" module table, a single Mermaid `Module overview` diagram, and a per-module section (lead paragraph + Capabilities bullets + Attribute / Detail table + Key user actions + Sources blockquote), then renders the Markdown to a styled PDF using the same house typography and Mermaid theme as the sibling `create-data-dependency-architecture` skill. Triggered by phrases like "build a functional modules document", "what modules does this system have", "describe the application module by module", "create a module architecture PDF".
---

# Skill — create-functional-modules-architecture

This skill turns a folder of source documents about a system into a styled PDF cataloguing the system's functional modules, with one detail section per module covering purpose, capabilities, user actions, business rules, data interactions, NFRs and source citations.

The output is **deterministic** in both content shape and visual style:

- Content shape is fixed by [`references/OUTPUT-STRUCTURE.md`](references/OUTPUT-STRUCTURE.md) — the same sections, in the same order, with the same `Attribute / Detail` table under every module.
- Visual style is the **same house style** as the sibling `create-data-dependency-architecture` skill: `assets/doc-style.css` (typography, headings, tables, captions, page setup) and `assets/mermaid-config.json` (Mermaid theme + fonts), reused by **path indirection** rather than duplicated. There are no per-skill style copies.
- The hard-won pipeline settings are documented in [`references/LESSONS-LEARNED.md`](references/LESSONS-LEARNED.md) — read that file before "fixing" anything; most rules are non-obvious and load-bearing.

## When to use

Use when the user gives you a folder of source documents and asks for:

- "the modules in `<system>`"
- "what `<system>` does, module by module"
- "build a functional architecture / modules / capabilities doc"
- "describe each module of `<system>` in one document"

Do **not** use this skill for:

- *Data dependencies* — that's `create-data-dependency-architecture` (sibling skill; same input folder, different output).
- *General C4 architecture* — that's `docs-to-c4`.
- *Code-level structure* — use the code-review-graph skills.
- *One-off prose summaries* — this skill produces a specific, formal artefact.

## Inputs

The user normally supplies:

1. **Path to a folder of source documents** — top-level files only; subfolders are intentionally ignored. Supported types: `.docx`, `.doc`, `.pdf`, `.md`, `.markdown`, `.txt`. Anything else is skipped with a warning.
2. *(Optional)* **System name** — full name and a short form (e.g. *Judicial Itineraries* / *JI*). If not given, derive it from the documents' titles or file names.
3. *(Optional)* **Output path** for the markdown — defaults to `<input-folder>/output-functional-modules/functional-modules.md`. Outputs always sit **alongside the input data**, never inside the project running the tooling.

## External tools required on PATH

These must already be on the host PATH before the skill runs — they are *not* installed by the venv bootstrap:

- `python3` (3.10+ for type-hint syntax in `md_to_pdf.py`, and to bootstrap the venv)
- `pandoc` (Markdown → HTML)
- `mmdc` (Mermaid CLI — `npm install -g @mermaid-js/mermaid-cli`)
- `textutil` *(macOS built-in — used by `distil-binary-data.sh` for `.doc` extraction)*
- `pdftotext` *(part of `poppler` — used by `distil-binary-data.sh` for `.pdf` source documents)*

If any are missing, surface it to the user immediately rather than producing partial output.

### Python dependencies — installed automatically into a venv

`weasyprint` (the WeasyPrint PDF engine) and any other Python package the build pipeline needs are **not** host requirements. They are listed in `.claude/lib/create-data-dependency-architecture/scripts/python/requirements.txt` and are installed into a per-skill virtual environment at `.claude/lib/create-data-dependency-architecture/scripts/python/.venv/` by `build-pdf.sh` on first run (and refreshed whenever `requirements.txt` is newer than the install marker). The venv's `bin/` is prepended to `PATH` for the duration of the build so pandoc finds the venv-installed `weasyprint`.

**Don't ask the user to install `weasyprint` system-wide** — it is purely a venv concern. If a Python dependency is missing, fix it in `requirements.txt`, not by asking the user to brew/pip install it on the host.

## Shared assets and scripts (path indirection)

This skill **reuses** the data-dependency skill's shared files rather than duplicating them. The following files live in the sibling skill and are invoked from this skill by absolute path:

| Shared file | Lives at | Used in phase |
|----|----|----|
| `distil-binary-data.sh` | `.claude/lib/create-data-dependency-architecture/scripts/distil-binary-data.sh` | Phase 1 |
| `build-pdf.sh` | `.claude/lib/create-data-dependency-architecture/scripts/build-pdf.sh` | Phase 4 |
| `md_to_pdf.py` (+ `requirements.txt`, `.venv/`) | `.claude/lib/create-data-dependency-architecture/scripts/python/` | Phase 4 |
| `doc-style.css` | `.claude/lib/create-data-dependency-architecture/assets/doc-style.css` | Phase 4 |
| `mermaid-config.json` | `.claude/lib/create-data-dependency-architecture/assets/mermaid-config.json` | Phase 4 |

Skill-local files in `.claude/lib/create-functional-modules-architecture/`:

- `scripts/find-modules.sh` — Phase 2a discovery floor (module-keyword scan)
- `templates/functional-modules.template.md` — output skeleton
- `references/OUTPUT-STRUCTURE.md`, `references/STYLE-GUIDE.md`, `references/LESSONS-LEARNED.md`

If the path indirection ever breaks (the data-skill scripts move or are renamed), this skill stops working until the paths are updated. That trade-off is intentional — see `references/LESSONS-LEARNED.md` LESSON F1.

## Pipeline

Run these phases in order. Do not skip phases; do not parallelise (each phase needs the previous one's output).

### Phase 1 — Distil binaries to plain text

Run the shared distiller:

```bash
.claude/lib/create-data-dependency-architecture/scripts/distil-binary-data.sh <input-folder>
```

Note the **second positional argument** — the distiller's default output is the data-skill's `<input-folder>/output/extracted-text/`; this skill explicitly redirects to its own dedicated `output-functional-modules/` tree so the two skills' outputs never mix. Each skill keeps its own extracted-text cache; re-running the distiller is cheap and idempotent. The full command for Phase 1 is:

```bash
.claude/lib/create-data-dependency-architecture/scripts/distil-binary-data.sh \
  <input-folder> \
  <input-folder>/output-functional-modules/extracted-text
```

The script ignores subfolders (top-level only — `find -maxdepth 1`), so the input folder's existing `output/` and `output-functional-modules/` subdirectories are skipped automatically on re-runs. It chooses the right tool per file type (pandoc for `.docx`, textutil for `.doc`, pdftotext for `.pdf`, copy for already-textual files).

Capture the list of files actually distilled — you'll need it for the `## Source Documents` section of the output.

### Phase 2 — Identify functional modules from the distilled text

Read each `.txt` file in `<input-folder>/output-functional-modules/extracted-text/`. **Do not** read the binaries directly — that wastes context and produces lower-quality reads.

This phase has four sub-steps and produces four on-disk artefacts that gate Phase 3. Authoring `functional-modules.md` is **not allowed** until all four exist:

| Artefact | Phase | Purpose |
|----|----|----|
| `output-functional-modules/module-candidates.txt` | 2a (script) | Discovery floor: deterministic keyword hits across the extracted text. |
| `output-functional-modules/module-enumeration.md` | 2a | Every named module, with canonical name / aliases / classification / status / citation. |
| `output-functional-modules/module-aliases.json` | 2a | Pinned canonical-to-aliases map so re-runs collapse aliases the same way. |
| `output-functional-modules/module-phase-2d-checks.md` | 2d | Closed seven-item checklist; every item ✅ before authoring. |

#### Phase 2a — Enumerate every named module

**Step 1 — Run the keyword scan.** Before reading anything yourself, run:

```bash
.claude/lib/create-functional-modules-architecture/scripts/find-modules.sh <input-folder>
```

This writes `<input-folder>/output-functional-modules/module-candidates.txt` — every line in the extracted text matching one of the canonical module-introduction patterns (numbered headings, `Ribbon`, `Module`, `Screen`, `Capability`, `Domain`, `Functional Requirement` / `Non-Functional Requirement` table headers, ribbon-action verbs `Manage|View|Report|Admin|Configure|Maintain`). The script is the **discovery floor**: anything it finds is a candidate module you must reconcile in Phase 2d. It is not the ceiling — your Phase 2a enumeration must also pick up modules the script can't keyword-match.

**Step 2 — Enumerate every named module.** Build a flat list of every module / ribbon / screen group that the source documents describe as a coherent unit of functionality. For each source document, walk through at least these places and capture every named module:

1. Top-level table-of-contents entries (`Manage Judges`, `Court Itinerary`, `Reports`).
2. Sections titled "Capabilities", "Major Capabilities", "Functional Areas", "User Groups", "Modules" or similar.
3. Tabbed UI ribbons or navigation menus (e.g. *Home, Manage Judges, Court Itinerary, …*).
4. Functional-requirement table headers grouping requirements by ribbon / screen.
5. Glossary entries naming a sub-module or screen group.
6. Every line in `output-functional-modules/module-candidates.txt` — extract the named module from each match.

**Step 3 — Pin the alias map.** Resolve aliases **before** classifying — if two names refer to the same module (*Manage Judges* ≡ *Judges Ribbon* ≡ *Judges page*; *Payments* ≡ *Payment Schedule*), record them as one entry with all aliases listed. Splitting them produces an inflated count; missing the equivalence produces a duplicate.

Write the resolution to `<input-folder>/output-functional-modules/module-aliases.json` with two top-level keys:

```json
{
  "canonical_to_aliases": {
    "Manage Judges": ["Judges", "Judges Ribbon", "Manage Judges page"],
    "Payments": ["Payments and Payment Reconciliation", "Payment Schedule"]
  },
  "aliases_to_canonical": {
    "Judges": "Manage Judges",
    "Judges Ribbon": "Manage Judges",
    "Manage Judges page": "Manage Judges",
    "Payments and Payment Reconciliation": "Payments",
    "Payment Schedule": "Payments"
  }
}
```

Every alias listed under `canonical_to_aliases` must round-trip through `aliases_to_canonical`. The catalogue and enumeration use the canonical name as the primary identifier; aliases live in dedicated cells.

**Step 4 — Write the enumeration.** Save `<input-folder>/output-functional-modules/module-enumeration.md` with one row per canonical module. Required columns: `Canonical name`, `Aliases`, `Classification`, `Status`, `Citation`.

```markdown
# Module Enumeration — <System Name>

| Canonical name | Aliases | Classification | Status | Citation |
|----|----|----|----|----|
| Home | Home Ribbon; Home page | Module | Implemented | *JI Functional and Non-Functional Requirements* §4.1a |
| Manage Judges | Judges; Judges Ribbon | Module | Implemented | *JI Functional and Non-Functional Requirements* §4.2a |
| Tribunal Support | — | Sub-module (ruled out) | Discovery required | *JI Functional and Non-Functional Requirements* §5.1 (Assumption 5) |
```

Include every named module, even ones being ruled out — ruling-out is recorded with a one-line justification in the `Citation` column, never by omission.

#### Phase 2b — Classify each enumerated module

For each module in the enumerated list, choose exactly one classification:

- **Module** — the module is a first-class part of the application's functional surface and warrants its own detail section in the catalogue.
- **Sub-module** — the docs describe it but it sits inside another module's detail section (e.g. *Forward Look* under *Judge Itinerary*). It is **not** given its own H3 in the catalogue; it is mentioned in the parent module's Capabilities or Key user actions.
- **Cross-cutting** — the named functionality applies across every module (e.g. authentication, audit logging, email notifications). These appear in the closing `## Cross-cutting NFRs` section, not as a module H3.
- **Ruled out** — the source documents name the area but explicitly exclude it from the as-is system, OR the named entity is an external system rather than a module of the application. Document the ruling-out with a one-line justification rooted in the source. Ruled-out entries stay in `module-enumeration.md`; they do **not** appear in the catalogue.

The **`Status` cell uses a closed vocabulary.** Every `Status` value — both in `module-enumeration.md` and in the per-section `Attribute / Detail` tables — must be **exactly** one of:

| Value | When to use it |
|----|----|
| `Implemented` | The module's documented capabilities are live in the application as described. |
| `Partial` | Some documented capabilities are live; others are stated but not yet implemented. |
| `Discovery required` | The source documents explicitly mark the module as "not supported — Discovery required" or equivalent. |
| `Out of scope` | The source documents name the module but explicitly exclude it from the as-is system. |

No paraphrases. The Phase 2d cross-check rejects any non-conforming string before authoring.

#### Phase 2c — Capture per-module facts

For each module that survives classification (`Module` or `Sub-module`), capture from the source text (not invented):

- **Module ID** — a stable short identifier, derived from a requirements-ID prefix where the source provides one (e.g. `MJ` for Manage Judges, `JIT` for Judge Itinerary, `PAY` for Payments). If no prefix exists, use the canonical name in CapitalCase (e.g. `Reports`).
- **Primary users** — the user roles that interact with this module (e.g. *RSU; Court (Full Access)*).
- **Trigger / entry points** — how a user reaches the module (top-level tab, sub-menu, deep-link from another module).
- **Capabilities** — a bulleted list of named capabilities the module provides, each ≤ 1 line, terse.
- **Inputs** — data the module consumes (with cross-references to inbound dependencies in the data-dependency catalogue where they exist).
- **Outputs** — data the module produces (with cross-references to outbound dependencies similarly).
- **Business rules** — the non-trivial rules described in the source (e.g. *Cancelled bookings are excluded from payment*).
- **Cross-module dependencies** — explicit references to other modules this one depends on or feeds.
- **NFRs** — module-specific NFRs (performance budgets, audit, role-based access).
- **Status** — closed vocabulary.
- **Key user actions** — optional bulleted list of the primary user actions, each in `WHEN <X> THEN <Y>` form where the source supports it. Omit entirely for purely back-office or read-only modules.
- **Source citations** — exact document name + section reference for each fact.

If a value cannot be found in the source documents, write "Unknown" rather than inventing.

#### Phase 2d — Cross-check before authoring

Write the cross-check to `<input-folder>/output-functional-modules/module-phase-2d-checks.md`. The seven items below are **fixed across every run** — copy them verbatim, in this order. For each item, mark ✅ followed by a one-line justification or pointer, or ❌ followed by the resolution action you took. Authoring (Phase 3) is **gated on every item being ✅** — do not start authoring until the file shows seven ✅s.

```markdown
# Phase 2d Cross-check — <System Name>

- [ ] 1. Every module in `module-enumeration.md` is either in the catalogue with a per-section entry (Module or Sub-module), or marked "ruled out" with a one-line justification (Ruled out / Cross-cutting), and Sub-modules appear under the parent's H3 not as their own H3.
- [ ] 2. Every line in `module-candidates.txt` is accounted for: either it maps to a catalogue module (or a Sub-module mention), or the line is dismissed with a one-line justification (e.g. "candidate matched a glossary cross-reference, not a module heading").
- [ ] 3. Aliases from `module-aliases.json` are collapsed: no module appears under two different names in the catalogue. Every alias round-trips through `aliases_to_canonical`.
- [ ] 4. No catalogue entry is an external system or an internal user role — those belong in the data-dependency catalogue or are ruled-out here.
- [ ] 5. Every catalogue entry's `Status` value is exactly one of `Implemented`, `Partial`, `Discovery required`, `Out of scope`.
- [ ] 6. Every catalogue entry has all nine mandatory `Attribute / Detail` rows: `Module ID`, `Primary users`, `Trigger / entry points`, `Inputs`, `Outputs`, `Business rules`, `Cross-module dependencies`, `NFRs`, `Status`.
- [ ] 7. The authored markdown has exactly one Mermaid `flowchart` block (the `## Module overview`), and every catalogue entry has a `> Sources:` blockquote pointing at a real section / requirement ID in the source documents.
```

If any check fails, return to Phase 2a/b/c and fix — don't paper over the gap in Phase 3.

### Phase 3 — Author the markdown

**Gate.** Do not author `functional-modules.md` until **all four** Phase 2 artefacts exist and `module-phase-2d-checks.md` has every item marked ✅:

- `<input-folder>/output-functional-modules/module-candidates.txt`
- `<input-folder>/output-functional-modules/module-enumeration.md`
- `<input-folder>/output-functional-modules/module-aliases.json`
- `<input-folder>/output-functional-modules/module-phase-2d-checks.md` — every item ✅

If any artefact is missing or any check is ❌, return to the appropriate sub-phase. Authoring without the gate is the failure mode this gating exists to prevent.

Use [`templates/functional-modules.template.md`](templates/functional-modules.template.md) as the skeleton; fill it in following [`references/OUTPUT-STRUCTURE.md`](references/OUTPUT-STRUCTURE.md) **exactly**. Don't deviate from the structure.

Critical rules (full list in [`references/LESSONS-LEARNED.md`](references/LESSONS-LEARNED.md)):

- YAML front matter with `title:` and `subtitle:` — no leading H1 in the body.
- One single `## At a Glance` table near the top with **all** modules in one place. Number them in narrative order (top-level navigation order, then back-office / cross-cutting last). Five columns only: `#`, `Module`, `Primary Users`, `Purpose`, `Status`. Separator-dash widths `4 / 26 / 18 / 36 / 16` (counted as `-` runs in the header).
- One `## Module overview` Mermaid `flowchart LR` block — exactly one diagram in the document. Three subgraphs grouping modules by domain (e.g. `Operational`, `Finance`, `Admin & MI`). All nodes are plain rectangles (`X["1. Module<br/>name"]`). Use `<br/>` for line breaks, never `\n`. Dashed arrows (`-.->`) for `Discovery required` or `Out of scope` cross-module flows.
- A single `## Modules` H2 followed by one `### N. <Module>` H3 per module, in the same numerical order as the *At a Glance* table.
- Each numbered module section has, in order:
  1. A 1–2 sentence lead paragraph stating purpose and primary user.
  2. **Capabilities** — bulleted list (each ≤ 1 line).
  3. A compact `Attribute | Detail` table with the **nine mandatory rows** in fixed order.
  4. *(Optional)* **Key user actions** — bulleted `WHEN <X> THEN <Y>` items.
  5. A `> Sources:` blockquote.
- Cross-references use the no-number heading anchor form (pandoc strips leading numbers — `[Manage Judges](#manage-judges)`, *not* `#2-manage-judges`). The link **text** is the module *name*, not its row number.
- **Prose mentions other modules by name, not by number.** Numbers belong in the *At a Glance* table and in diagram node labels only.
- **Don't narrate the skill's authoring conventions in the document body.** Phrases like *"per the OUTPUT-STRUCTURE convention"* or *"as the structure dictates"* are noise. Structural notes belong in `## Appendix`, if anywhere.
- Closing sections in order: optional `## Cross-cutting NFRs`, then `## Summary`, optional `## Appendix`, then `## Source Documents`.

Save the markdown to the user-supplied output path (default `<input-folder>/output-functional-modules/functional-modules.md`). The PDF in Phase 4 will land next to it (`<input-folder>/output-functional-modules/functional-modules.pdf`) along with the build-artefact `<stem>.assets/` sibling.

### Phase 4 — Render the PDF

Run the **shared** PDF builder:

```bash
.claude/lib/create-data-dependency-architecture/scripts/build-pdf.sh <input-folder>/output-functional-modules/functional-modules.md
```

The wrapper invokes the shared `md_to_pdf.py` which:

1. Parses YAML front matter for title / subtitle (or strips a leading `# H1` if no YAML title is present).
2. Pre-renders each ` ```mermaid ` block to a PNG via `mmdc --configFile=assets/mermaid-config.json` (this is what makes the diagram colours and fonts deterministic).
3. Substitutes each block with a Markdown image reference into a working copy of the markdown.
4. Runs `pandoc --wrap=none --pdf-engine=weasyprint --css=assets/doc-style.css` against the working copy.
5. Writes `<input>.pdf` next to the source markdown, plus a sibling `<input>.assets/` folder containing the rendered Mermaid PNGs and the rewritten build markdown (kept for inspection).

`--wrap=none` is mandatory. Don't remove it.

### Phase 5 — Verify and report

After the build succeeds:

1. Run `pdfinfo <output.pdf> | grep -E 'Pages|File size'` to confirm a real PDF was produced.
2. Briefly tell the user what was produced, where, and the page count. Don't post a summary of the document content unless asked — the PDF is the deliverable.

If pandoc emits any "No anchor #..." errors, find the matching `[label](#wrong-id)` link in the markdown and correct it (typical cause: the link includes a leading number that pandoc strips from the heading id).

## Anti-patterns to avoid

- **Don't** write one diagram per module. The document has **exactly one** Mermaid diagram (the top-of-document *Module overview*). The per-module `Attribute / Detail` table is what carries each module's detail.
- **Don't** invent capabilities. Every entry must trace to a specific section of one of the input documents.
- **Don't** skip the per-module nine-row `Attribute / Detail` table even if the module feels small — it's the document's load-bearing pattern.
- **Don't** add custom colour `classDef` palettes to the Mermaid overview — the house theme handles colour.
- **Don't** refer to modules by number in prose. Use names. Numbers are for the *At a Glance* table and the diagram only.
- **Don't** narrate authoring conventions in the body. Structural notes belong in `## Appendix`.
- **Don't** duplicate the data-dependency catalogue here. Where a module produces or consumes data that's already catalogued in `data-dependencies.md`, link to that document by anchor; do not re-state the data-flow detail.
- **Don't** copy the data-skill's `assets/` or `scripts/` folders into this skill — the path indirection is intentional and load-bearing.
- **Don't** commit, push or open PRs. The user handles git externally.

## Command file layout

```
.claude/lib/create-functional-modules-architecture/
├── SKILL.md                                # this file
├── scripts/
│   └── find-modules.sh                     # Phase 2a discovery floor (pure shell)
├── templates/
│   └── functional-modules.template.md      # skeleton with placeholders
└── references/
    ├── OUTPUT-STRUCTURE.md                 # exact, deterministic content shape
    ├── STYLE-GUIDE.md                      # author-facing house style
    └── LESSONS-LEARNED.md                  # critical settings + gotchas
```

Shared (lives in the data-dependency skill, used here by path indirection):

```
.claude/lib/create-data-dependency-architecture/
├── assets/
│   ├── doc-style.css
│   └── mermaid-config.json
└── scripts/
    ├── build-pdf.sh
    ├── distil-binary-data.sh
    └── python/
        ├── md_to_pdf.py
        └── requirements.txt
```

## What goes where — tooling vs data

The skill keeps tooling and data strictly separated:

- **Tooling** lives with the skill at `.claude/lib/create-functional-modules-architecture/`. Nothing per-run is written here.
- **Data** — both input source documents *and* every per-run output — lives at the user-supplied input path. Outputs are written to `<input-folder>/output-functional-modules/`:
  - `extracted-text/` — Phase 1 plain-text extractions (this skill's own copy; the data-dependency skill keeps its own at `<input-folder>/output/extracted-text/`)
  - `module-candidates.txt` — Phase 2a, script-generated keyword scan
  - `module-enumeration.md` — Phase 2a, every named module with classification + status + citation
  - `module-aliases.json` — Phase 2a, pinned canonical-to-aliases map
  - `module-phase-2d-checks.md` — Phase 2d, the seven-item pre-authoring checklist
  - `functional-modules.md` — Phase 3, the catalogue
  - `functional-modules.assets/` — Phase 4, Mermaid PNGs and the rewritten build markdown
  - `functional-modules.pdf` — Phase 4, the deliverable
- **The data-dependency skill's `<input-folder>/output/`** is never written to by this skill, and vice-versa. The two skills coexist by partitioning the input folder's output namespace at the top level (`output/` vs `output-functional-modules/`).
- **The repo running the skill** (this repo, or any other) is never written to by a skill run.
