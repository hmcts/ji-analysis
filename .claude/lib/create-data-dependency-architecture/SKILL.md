---
name: create-data-dependency-architecture
description: Use when the user asks to produce a data-dependencies architecture document for a system from a folder of source binary documents (.docx, .doc, .pdf, .pptx, .md, .txt). The skill distils the binaries into plain text via the BMAD-style distillation process (pandoc + textutil + pdftotext), analyses them for the system's inbound and outbound data dependencies, writes a deterministic Markdown document with a top-level "At a Glance" summary table, a clustered Mermaid overview diagram (Inbound / Platform / Outbound subgraphs), and a compact `Attribute / Detail` summary table under every dependency, then renders the Markdown to a styled PDF using the house typography and Mermaid theme. Triggered by phrases like "create a data dependencies doc from this folder", "build the data-dependency architecture for X", "generate the data-dependencies PDF from these source docs".
---

# Skill — create-data-dependency-architecture

This skill turns a folder of source documents about a system into a styled PDF cataloguing the system's data dependencies on other systems, in both directions.

The output is **deterministic** in both content shape and visual style:

- Content shape is fixed by [`references/OUTPUT-STRUCTURE.md`](references/OUTPUT-STRUCTURE.md) — the same sections, in the same order, with the same Attribute / Detail table under every dependency.
- Visual style is fixed by [`assets/doc-style.css`](assets/doc-style.css) (typography, headings, tables, captions, page setup) and [`assets/mermaid-config.json`](assets/mermaid-config.json) (Mermaid theme + fonts).
- The hard-won settings that make the pipeline work are documented in [`references/LESSONS-LEARNED.md`](references/LESSONS-LEARNED.md). Read that file before "fixing" the build script — most of the rules are non-obvious and load-bearing.

## When to use

Use when the user gives you a folder of source documents and asks for:

- "the data dependencies for `<system>`"
- "what does `<system>` depend on / produce"
- "build a data-dependencies doc / PDF / architecture document"
- "what other systems are involved with `<system>`"

Do **not** use this skill for general C4 architecture (use `docs-to-c4` for that), for code-level dependencies (use the code-review-graph skills), or for one-off prose summaries — this skill produces a specific, formal artefact.

## Inputs

The user normally supplies:

1. **Path to a folder of source documents** — top-level files only; subfolders are intentionally ignored. Supported types: `.docx`, `.pptx`, `.doc`, `.pdf`, `.md`, `.markdown`, `.txt`. Anything else is skipped with a warning.
2. *(Optional)* **System name** — full name and a short form (e.g. *Judicial Itineraries* / *JI*). If not given, derive it from the documents' titles or file names.
3. *(Optional)* **Output path** for the markdown — defaults to `<input-folder>/output/data-dependencies.md`. Outputs always sit **alongside the input data**, never inside the project running the tooling, so the skill can be invoked against any docs folder without leaking artefacts back into this repo.

## External tools required on PATH

- `python3` (3.10+ for type-hint syntax in `md_to_pdf.py`)
- `pandoc`
- `weasyprint`
- `mmdc` (Mermaid CLI — `npm install -g @mermaid-js/mermaid-cli`)
- `textutil` *(macOS only — needed for `.doc` extraction)*
- `pdftotext` *(part of `poppler` — needed for `.pdf` source documents)*

If any are missing, surface it to the user immediately rather than producing partial output.

## Pipeline

Run these phases in order. Do not skip phases; do not parallelise (each phase needs the previous one's output).

### Phase 1 — Distil binaries to plain text

Run `scripts/distil-binary-data.sh <input-folder> <output-folder>` with:

- `<input-folder>` = the user-supplied source folder.
- `<output-folder>` = `<input-folder>/output/extracted-text/` (the script's default if you omit the second argument). Outputs sit alongside the input data so tooling and data stay separated — the running project never accumulates per-run artefacts.

The script ignores subfolders (top-level only — see [LESSON 14](references/LESSONS-LEARNED.md)), which means the new `output/` subdirectory is skipped automatically on re-runs. It chooses the right tool per file type (pandoc for `.docx` and `.pptx`, textutil for `.doc`, pdftotext for `.pdf`, copy for already-textual files).

Capture the list of files actually distilled — you'll need it for the `## Source Documents` section of the output.

> If the user has `bmad-distillator` available locally and prefers richer markdown output, run it *in addition to* this script and read both outputs. The plain-text extraction is the safety net; bmad-distilled markdown is a bonus.

### Phase 2 — Extract data dependencies from the distilled text

Read each `.txt` file in `<input-folder>/output/extracted-text/`. **Do not** read the binaries directly — that wastes context and produces lower-quality reads (see [LESSON 13](references/LESSONS-LEARNED.md)).

This phase has four sub-steps. **Run them in order — don't collapse them.** Variance between runs (the same skill against the same docs producing different counts of dependencies) almost always traces to a system being lost during interpretation. The enumerate-then-classify pattern below is the fix.

Phase 2 produces four on-disk artefacts that gate Phase 3. Authoring `data-dependencies.md` is **not allowed** until all four exist:

| Artefact | Phase | Purpose |
|----|----|----|
| `output/manual-flow-candidates.txt` | 2a (script) | Discovery floor: deterministic keyword hits across the extracted text. |
| `output/system-enumeration.md` | 2a | Every named system, with canonical name / aliases / classification / status / citation. |
| `output/system-aliases.json` | 2a | Pinned canonical-to-aliases map so re-runs collapse aliases the same way. |
| `output/phase-2d-checks.md` | 2d | Closed seven-item checklist; every item ✅ before authoring. |

See [LESSON 20](references/LESSONS-LEARNED.md) for why each is required.

#### Phase 2a — Enumerate every named system (no system left behind)

**Step 1 — Run the keyword scan.** Before reading anything yourself, run:

```bash
.claude/lib/create-data-dependency-architecture/scripts/find-manual-flows.sh <input-folder>
```

This writes `<input-folder>/output/manual-flow-candidates.txt` — every line in the extracted text that matches one of the canonical manual-flow phrases (`copies from`, `manually enter`, `transcribe`, `look up in`, `obtained from`, `no integration`, `out-of-band`, …). The script is the *discovery floor*: anything it finds is a candidate dependency you must reconcile in Phase 2d. It is not the ceiling — your Phase 2a enumeration must also pick up systems the script can't keyword-match. See [LESSON 19](references/LESSONS-LEARNED.md).

**Step 2 — Enumerate every named system.** Build a flat list of every external system, integration point, third-party tool or named external party that appears *anywhere* in the source documents. **Include systems even if the docs say there is "no integration" with them, or "data is entered manually"** — those are gap dependencies, not non-dependencies, and they belong in the catalogue ([LESSON 18](references/LESSONS-LEARNED.md)).

For each source document, walk through at least these places and capture every named system:

1. Sections titled "Integrations", "Dependencies", "Data Integration", "External Consumption" or similar.
2. "Assumptions" / "Constraints" / "Dependencies" sections (typically `5.x` in HMCTS-style docs).
3. Glossary entries that name another system.
4. Prose mentions of any system that data flows to or from (e.g. *"JI emails the file to L!BERATA"*, *"data is copied from the Judicial Database"*).
5. Non-functional requirements that name a system (e.g. *NFR-3: the system shall support eLinks integration*).
6. Every line in `output/manual-flow-candidates.txt` — extract the named upstream system from each match.

**Step 3 — Pin the alias map.** Resolve aliases **before** classifying — if two names refer to the same system (*eLinks* ≡ *Judicial Database*; *JFEPS* ≡ *JFEBS* ≡ *L!BERATA* in some HMCTS contexts), record them as one entry with all aliases listed. Splitting them produces an inflated count; missing the equivalence produces a duplicate.

Write the resolution to `<input-folder>/output/system-aliases.json` with two top-level keys:

```json
{
  "canonical_to_aliases": {
    "eLinks": ["Judicial Database", "JD"],
    "L!BERATA": ["JFEPS", "JFEBS"]
  },
  "aliases_to_canonical": {
    "Judicial Database": "eLinks",
    "JD": "eLinks",
    "JFEPS": "L!BERATA",
    "JFEBS": "L!BERATA"
  }
}
```

Every alias listed under `canonical_to_aliases` must round-trip through `aliases_to_canonical`. Catalogue and enumeration use the canonical name as the primary identifier; aliases live in dedicated cells.

**Step 4 — Write the enumeration.** Save `<input-folder>/output/system-enumeration.md` with one row per canonical system:

```markdown
# System Enumeration — <System Name>

| Canonical name | Aliases | Classification | Status | Citation |
|----|----|----|----|----|
| eLinks | Judicial Database; JD | Inbound | Manual copy | *JI Functional Requirements* §5.3.1 |
| L!BERATA | JFEPS; JFEBS | Outbound; Inbound (return leg) | Implemented (automated); Manual copy (return leg) | *JI Functional Requirements* §5.3.4 |
| Court Staff | — | Internal user (ruled out) | Manual entry (no upstream system) | (not a system; users) |
```

Include every named system, even ones being ruled out — ruling-out is recorded with a one-line justification in the `Citation` column, never by omission.

#### Phase 2b — Classify each enumerated system

For each system in the enumerated list, choose exactly one classification:

- **Inbound** — `<SystemShort>` consumes data from it.
- **Outbound** — `<SystemShort>` produces data for it.
- **Platform** — `<SystemShort>` runs on it (only if the docs explicitly call out a runtime / platform / hosting / transport dependency).
- **Ruled out** — the docs name the system but explicitly state `<SystemShort>` does not exchange any data with it via any route, OR the named entity is an internal user role rather than an external system. Document the ruling-out with a one-line justification rooted in the source. Ruled-out systems stay in `system-enumeration.md`; they do **not** appear in the catalogue.

Apply these rules during classification — they are the ones most often broken under model variance:

- **The `Status` cell uses a closed vocabulary.** Every `Status` value — both in `system-enumeration.md` and in the per-section `Attribute / Detail` tables — must be **exactly** one of:
  - `Implemented (automated)` — a real system-to-system integration is in production.
  - `Manual copy` — a human regularly transcribes / re-keys / copies data from a named upstream system into `<SystemShort>`. The upstream system **is** the dependency.
  - `Manual entry (no upstream system)` — a human enters data with no upstream system to point at. Used only in `system-enumeration.md` to record a ruled-out row; never appears in the catalogue.
  - `Stated NFR; not implemented` — an NFR specifies the integration but it has not been built.
  - `No integration (by design)` — the source documents explicitly state the systems do not exchange data. Used only in `system-enumeration.md`; never appears in the catalogue.

  No paraphrases ("Manual entry by RSU", "manual", "Not implemented"). The Phase 2d cross-check rejects any non-conforming string before authoring.

- **Always include the reconciliation return leg of every outbound flow as a separate inbound entry.** If JI sends payments to a finance system and later receives payment status back (even via manual flagging), that is **two** catalogue entries — one outbound (JI → finance) and one inbound (finance → JI as the return leg). [OUTPUT-STRUCTURE](references/OUTPUT-STRUCTURE.md) explicitly prefers this over a single "Both" entry.
- **Distinguish "system" from "user input".** Court staff, judicial team users and judges are *users* of `<SystemShort>`, not external systems. Their data entry is not an inbound dependency on its own — record them in `system-enumeration.md` as ruled-out with `Status` = `Manual entry (no upstream system)`. But if the data they enter has a real upstream source (e.g. court listings originate in a case management system; working patterns originate in an HR system), the upstream source **is** the inbound dependency with `Status` = `Manual copy`, even if the route is "user manually copies from system X into JI". See [LESSON 18](references/LESSONS-LEARNED.md).
- **Gap dependencies count.** If a data flow is described in the source documents but is currently fulfilled by manual transcription instead of an integration, include it with the appropriate closed-vocabulary `Status`. The catalogue is about what data `<SystemShort>` depends on, not what is automated.
- **Use "Both" sparingly.** Only if there is a genuinely bidirectional integration that does not reduce to "outbound flow + reconciliation return leg".

#### Phase 2c — Capture per-dependency facts

For each dependency that survives classification, capture (from the source text, not invented):

- Full name, plus any aliases / replacement names mentioned.
- Direction (per Phase 2b).
- Data type label (Master / reference, Reference / configuration, Operational / transactional, Financial reconciliation, Aggregated MI, Notifications & document distribution, Runtime services, etc.).
- The specific data items (semicolon-separated where multiple).
- Mechanism — *how* the data moves today.
- Frequency — when it moves.
- Format (outbound only — file type or transport).
- Status — exactly one of `Implemented (automated)`, `Manual copy`, `Stated NFR; not implemented` (the three values that can appear in the catalogue). `Manual entry (no upstream system)` and `No integration (by design)` are reserved for `system-enumeration.md` rule-outs.
- Criticality — Critical / High / Medium / Low — and a one-line justification grounded in the source.
- Source citations — exact document name + section reference for each fact.

If a value cannot be found in the source documents, write "Unknown" rather than inventing.

#### Phase 2d — Cross-check before authoring

Write the cross-check to `<input-folder>/output/phase-2d-checks.md`. The seven items below are **fixed across every run** — copy them verbatim, in this order. For each item, mark ✅ followed by a one-line justification or pointer (e.g. *"see eLinks row in catalogue"*, *"line 142 dismissed as internal screen flow"*), or ❌ followed by the resolution action you took. Authoring (Phase 3) is **gated on every item being ✅** — do not start authoring until the file shows seven ✅s.

```markdown
# Phase 2d Cross-check — <System Name>

- [ ] 1. Every system in `system-enumeration.md` is either in the catalogue with a per-section entry, or marked "ruled out" with a one-line justification.
- [ ] 2. Every line in `manual-flow-candidates.txt` is accounted for: either the upstream system is an inbound entry with `Status` = `Manual copy`, or the line is dismissed with a one-line justification (e.g. "phrase used metaphorically", "refers to internal screen flow not a system").
- [ ] 3. Every outbound flow has a corresponding inbound entry for its reconciliation / status return leg, or the source documents explicitly state there is no return flow.
- [ ] 4. No catalogue entry is an internal user role (court staff, RSU, judges).
- [ ] 5. Aliases from `system-aliases.json` are collapsed: no system appears under two different names in the catalogue.
- [ ] 6. Every catalogue entry's `Status` value is exactly one of `Implemented (automated)`, `Manual copy`, `Stated NFR; not implemented`.
- [ ] 7. Every catalogue entry has a `> Sources:` blockquote pointing at a real section / requirement ID in the source documents.
```

If any check fails, return to Phase 2a/b and fix — don't paper over the gap in Phase 3.

### Phase 3 — Author the markdown

**Gate.** Do not author `data-dependencies.md` until **all four** Phase 2 artefacts exist and `phase-2d-checks.md` has every item marked ✅:

- `<input-folder>/output/manual-flow-candidates.txt` (script-generated)
- `<input-folder>/output/system-enumeration.md`
- `<input-folder>/output/system-aliases.json`
- `<input-folder>/output/phase-2d-checks.md` — every item ✅

If any artefact is missing or any check is ❌, return to the appropriate sub-phase. Authoring without the gate is the failure mode this gating exists to prevent.

Use [`templates/data-dependencies.template.md`](templates/data-dependencies.template.md) as the skeleton; fill it in following [`references/OUTPUT-STRUCTURE.md`](references/OUTPUT-STRUCTURE.md) **exactly**. Don't deviate from the structure.

Critical rules (full list in [LESSONS-LEARNED.md](references/LESSONS-LEARNED.md)):

- YAML front matter with `title:` and `subtitle:` — no leading H1 in the body.
- One single `## At a Glance` table near the top with **all** flows in one place. Number them in narrative order (inbound, then platform, then outbound).
- One `## Data flow overview` Mermaid `flowchart LR` block (the top-of-document overview diagram):
  - **Three subgraphs**: `Inbound`, `Platform` (omit if none), `Outbound`.
  - Each subgraph uses `direction TB`.
  - All containers (the central system *and* every external system) as **plain rectangles** — ArchiMate-style. Use `SYS["System<br/>Short"]`. **Do not** use cylinder (`[(...)]`), circle (`((...))`), or other special Mermaid shapes; the visual distinction between hub and dependencies comes from the diagram's left/right layout and subgraph clustering, not from shape variation.
  - Number each external node label: `["1. eLinks"]`.
  - **`<br/>` for line breaks — never `\n`.**
  - Dashed arrows (`-.->`) for non-implemented / out-of-band / platform flows.
- Each numbered detail section has:
  1. A 1–2 sentence lead paragraph.
  2. A compact  `Attribute | Detail` table — **mandatory**.
  3. A `> Sources: *Doc Name* (section).` blockquote.
- Cross-references use the no-number heading anchor form (pandoc strips leading numbers — `[JFEPS / Finance System](#jfeps-finance-system-fee-paid-payment-files)`, *not* `#7-jfeps-...`). The link **text** is the dependency *name*, not its row number.
- **Prose mentions other dependencies by name, not by number.** Write *"the [JFEPS reconciliation flow](#jfeps-reconciliation) is the return leg…"*, never *"Dependency 3 is the return leg…"* or *"the chain runs `2 → JI → 6 → 3`"*. Numbers belong in the *At a Glance* table and in diagram node labels only — they shift between runs and break readability when used in prose.
- **Don't narrate the skill's authoring conventions in the document body.** Phrases like *"modelled here as a separate inbound entry per the OUTPUT-STRUCTURE convention"*, *"per the structure of this document"* or *"as the convention dictates"* are noise — the reader cares about the data flows, not why we organised them this way. If a particular structural decision genuinely needs explaining (e.g. why one integration is split into two entries, or why a system mentioned in the source docs was deliberately ruled out), put a one-line note in the optional `## Appendix` section described in [OUTPUT-STRUCTURE](references/OUTPUT-STRUCTURE.md). Body prose stays clean.

Save the markdown to the user-supplied output path (default `<input-folder>/output/data-dependencies.md`). The PDF in Phase 4 will land next to it (`<input-folder>/output/data-dependencies.pdf`) along with the build-artefact `<stem>.assets/` sibling.

### Phase 4 — Render the PDF

Run `scripts/build-pdf.sh <path-to-markdown>`.

The wrapper invokes `scripts/md_to_pdf.py` which:

1. Parses YAML front matter for title / subtitle (or strips a leading `# H1` if no YAML title is present).
2. Pre-renders each ` ```mermaid ` block to a PNG via `mmdc --configFile=assets/mermaid-config.json` (this is what makes the diagram colours and fonts deterministic — see [LESSON 6](references/LESSONS-LEARNED.md)).
3. Substitutes each block with a Markdown image reference into a working copy of the markdown.
4. Runs `pandoc --wrap=none --pdf-engine=weasyprint --css=assets/doc-style.css` against the working copy.
5. Writes `<input>.pdf` next to the source markdown, plus a sibling `<input>.assets/` folder containing the rendered Mermaid PNGs and the rewritten build markdown (kept for inspection).

`--wrap=none` is mandatory — see [LESSON 1](references/LESSONS-LEARNED.md). Don't remove it.

### Phase 5 — Verify and report

After the build succeeds:

1. Run `pdfinfo <output.pdf> | grep -E 'Pages|File size'` to confirm a real PDF was produced.
2. Briefly tell the user what was produced, where, and the page count. Don't post a summary of the document content unless asked — the PDF is the deliverable.

If pandoc emits any "No anchor #..." errors, find the matching `[label](#wrong-id)` link in the markdown and correct it (typical cause: the link includes a leading number that pandoc strips from the heading id — see [LESSON 5](references/LESSONS-LEARNED.md)).

## Bootstrapping a fresh repository

If the target repository does **not** already have the build pipeline (`scripts/build-pdf.sh`, `scripts/python/md_to_pdf.py`, `scripts/python/requirements.txt`, `scripts/styles/doc-style.css`, `scripts/styles/mermaid-config.json`):

1. Copy this skill's `scripts/build-pdf.sh` to the repo at `scripts/build-pdf.sh`.
2. Copy this skill's `scripts/python/md_to_pdf.py` and `scripts/python/requirements.txt` to the repo at `scripts/python/md_to_pdf.py` and `scripts/python/requirements.txt`.
3. Copy this skill's `assets/doc-style.css` and `assets/mermaid-config.json` to the repo at `scripts/styles/doc-style.css` and `scripts/styles/mermaid-config.json`.
4. `chmod +x scripts/build-pdf.sh`.
5. Run from the repo's copy thereafter — `scripts/build-pdf.sh` will create `scripts/python/.venv/` on first run and install `requirements.txt` into it. Add `scripts/python/.venv/` to the repo's `.gitignore`.

This way the user has the build pipeline in their repo (committable, reviewable, customisable) without the skill files leaking in. The Python script is never invoked directly — always go through `scripts/build-pdf.sh` so the venv is set up consistently.

If the repo already has these files, **don't overwrite them** — the user may have customised the style. Run from the repo's copy.

## Anti-patterns to avoid

- **Don't drop a dependency just because the source documents say "no integration".** If there is a *named upstream system* whose data is moved into `<SystemShort>` by manual transcription, it is a `Manual copy` inbound dependency and belongs in the catalogue. "No integration" describes the mechanism, not the absence of a dependency. (See [LESSON 18](references/LESSONS-LEARNED.md).)
- **Don't** invent data dependencies. Every entry must trace to a specific section of one of the input documents.
- **Don't** skip the per-dependency `Attribute | Detail` table even if the section feels short — it's the document's load-bearing pattern.
- **Don't** add custom colour `classDef` palettes to Mermaid diagrams — the house theme handles colour. (See [LESSON 6](references/LESSONS-LEARNED.md).)
- **Don't** generate one diagram per dependency. The document has **exactly three** diagrams: (1) the top-of-document *Data flow overview* covering all flows in one picture; (2) an *Inbound flow* detail diagram immediately under `## Inbound dependencies` showing intermediary actors and JI screens; (3) an *Outbound flow* detail diagram immediately under `## Outbound dependencies` showing intermediary actors and destinations. Per-section diagrams under each numbered entry are forbidden — the per-dependency `Attribute / Detail` table is what carries that level of detail.
- **Don't** refer to dependencies by number in prose. Use names. Numbers are for tables and diagrams only — prose like *"Dependency 3 is the return leg of 6"* both reads badly and breaks when row numbers shift.
- **Don't** narrate the skill's authoring conventions in the document body. The reader cares about the flows, not about how we organised them. Reasoning notes belong in `## Appendix`, if anywhere.
- **Don't** commit, push or open PRs. The user handles git externally — see [LESSON 17](references/LESSONS-LEARNED.md) and the project memory.

## Command file layout

```
.claude/lib/create-data-dependency-architecture/
├── SKILL.md                              # this file
├── assets/
│   ├── doc-style.css                     # weasyprint stylesheet
│   └── mermaid-config.json               # mermaid theme/fonts
├── scripts/
│   ├── build-pdf.sh                      # venv-bootstrapping shell wrapper
│   ├── distil-binary-data.sh             # binary → text extractor (pure shell)
│   ├── find-manual-flows.sh              # Phase 2a discovery floor (pure shell)
│   └── python/
│       ├── md_to_pdf.py                  # the actual builder
│       ├── requirements.txt              # pip deps (weasyprint)
│       └── .venv/                        # auto-created on first build, gitignored
├── templates/
│   └── data-dependencies.template.md     # skeleton with placeholders
└── references/
    ├── OUTPUT-STRUCTURE.md               # exact, deterministic content shape
    ├── STYLE-GUIDE.md                    # author-facing house style for the pipeline
    └── LESSONS-LEARNED.md                # critical settings + gotchas
```

## What goes where — tooling vs data

The skill keeps tooling and data strictly separated:

- **Tooling** lives with the skill at `.claude/lib/create-data-dependency-architecture/` (`SKILL.md`, `assets/`, `scripts/`, `templates/`, `references/`). Nothing per-run is written here.
- **Data** — both input source documents *and* every per-run output — lives at the user-supplied input path. Outputs are written to `<input-folder>/output/`:
  - `extracted-text/` — Phase 1 plain-text extractions
  - `manual-flow-candidates.txt` — Phase 2a, script-generated keyword scan
  - `system-enumeration.md` — Phase 2a, every named system with classification + status + citation
  - `system-aliases.json` — Phase 2a, pinned canonical-to-aliases map
  - `phase-2d-checks.md` — Phase 2d, the seven-item pre-authoring checklist
  - `data-dependencies.md` — Phase 3, the catalogue
  - `data-dependencies.assets/` — Phase 4, Mermaid PNGs and the rewritten build markdown
  - `data-dependencies.pdf` — Phase 4, the deliverable

  The input folder's top level is never modified; only the `output/` subdirectory is created and overwritten.
- **The repo running the skill** (this repo, or any other) is never written to by a skill run. The repo's own `docs/` directory is **not** part of this skill — don't write outputs there, and don't put authoring guides, style references or build scripts there either. Authoring/style content belongs in `references/` here; outputs belong with the input data.

If you find yourself writing a `docs/STYLE-GUIDE.md`, `docs/CONVENTIONS.md` or similar — stop. Add the content to `references/STYLE-GUIDE.md` here instead, and have authors read it from the skill.
