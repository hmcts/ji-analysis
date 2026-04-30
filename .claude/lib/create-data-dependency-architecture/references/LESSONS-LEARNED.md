# Lessons learned (read this before "fixing" the pipeline)

This file captures the *non-obvious* settings and gotchas that came out of building this pipeline. Each one is a real problem we hit and resolved. Treat the rules as load-bearing — undoing them tends to silently break the output.

## Build pipeline

### 1. `pandoc --wrap=none` is mandatory

Pandoc's HTML5 writer wraps long lines at ~72 columns by default. That wrapping happens **inside** SVG `<text>` content and inside Markdown HTML attributes, where it inserts literal newlines. Downstream renderers (WeasyPrint specifically) then render those as either dropped inter-word spaces *or* literal `\n` glyphs depending on context.

> **Always pass `--wrap=none`.** It's baked into `scripts/md_to_pdf.py`; do not remove it.

### 2. Use WeasyPrint, not LaTeX, as the PDF engine

LaTeX engines (`pdflatex`, `xelatex`, `tectonic`) cannot render inline SVG without significant additional plumbing, and we want real SVG-derived diagrams. WeasyPrint round-trips HTML5 + CSS + raster images without the LaTeX pain.

> The pipeline calls `pandoc --pdf-engine=weasyprint`. WeasyPrint must be on PATH (`brew install weasyprint`).

### 3. Pre-render Mermaid → PNG, don't try inline

We tried inline SVG (Mermaid → embedded `<svg>` in Markdown). WeasyPrint's CSS engine treats SVG presentation properties (`fill`, `stroke`, `text-anchor`, `dominant-baseline`) as CSS and silently drops them, producing colourless boxes with collapsed text. Even when those are inlined as XML attributes, multi-line text in `<text>` nodes ends up missing inter-word spaces (see lesson 1).

> The fix is to render each `mermaid` block to a PNG via `mmdc` *before* pandoc runs, and substitute the block with a Markdown image reference. `scripts/md_to_pdf.py` does this in one pass.

### 4. Use `<br/>` in Mermaid node labels — never `\n`

In current Mermaid CLI versions, `<br/>` produces a real line break in PNG output. Literal `\n` produces the two characters `\` and `n` in the rendered image (or, depending on Mermaid version, an awkward break with the backslash visible).

> All multi-line node and edge labels use `<br/>`. The skill's templates and OUTPUT-STRUCTURE.md enforce this.

### 4a. Markdown separator-dash widths control table column widths

Pandoc's pipe-table reader emits `<colgroup><col style="width:X%">` derived from the **relative width of the `---` runs in the header separator row**. So this markdown:

```
| # | External System | Data Type | Data | Mechanism |
|---|----------------|-----------|------|-----------|
```

makes pandoc allocate ~6 / 34 / 23 / **12** / 23 % — and the *Data* column ends up the narrowest. The fix is in the markdown, not the CSS: write the separator with deliberately lopsided dash counts to get the column shares you want. The skill's template uses `4 / 25 / 13 / 35 / 23` which gives Data 35% so its cells wrap to ≤ 2 lines.

External CSS rules trying to override these inline `<col style="width: X%">` declarations don't work reliably, even with `:has()` and `!important` — pandoc's inline styles win in the cascade. Drive widths from the markdown.

### 5. Pandoc strips leading numbers — *and most punctuation* — from heading IDs

A heading like `### 7. JFEPS / Finance System` becomes anchor `#jfeps-finance-system`, not `#7-jfeps-finance-system`. Cross-references that include the number will break with `ERROR: No anchor #7-…`.

> Write cross-references in the no-number form: `[7](#jfeps-finance-system-fee-paid-payment-files)`.

The same stripping applies to embedded punctuation, but **with no replacement hyphen**. The brand `L!BERATA` in a heading becomes `lberata` in the anchor (the `!` is removed; no hyphen is inserted to fill the gap), so `### 3. JFEPS / L!BERATA (reconciliation)` produces anchor `#jfeps-lberata-reconciliation` — *not* `#jfeps-l-berata-reconciliation`. Slashes and parentheses surrounded by spaces *do* collapse to single hyphens because the spaces around them carry the hyphen; an in-word punctuation mark like `!` does not.

> When linking to a heading that contains in-word punctuation, drop the punctuation entirely in the anchor (e.g. `L!BERATA` → `lberata`, `R&D` → `rd`, `JI's` → `jis`).

## Mermaid styling

### 6. Use the `default` theme via `--configFile`

Don't hand-craft a `classDef` palette per document — that's the "reinvent every time" anti-pattern. The house theme lives in `assets/mermaid-config.json` (theme `default`, Helvetica fontFamily) and is passed to mmdc via `--configFile`. The default theme produces pastel-purple nodes with cream subgraph backgrounds.

### 7. Use `subgraph` clustering, not flat node lists

Group nodes by role using `subgraph`. The convention is three groups:

- `inbound [Inbound]` — nodes with `direction TB`
- `platform [Platform]` — only if there's a runtime/platform dependency
- `outbound [Outbound]` — nodes with `direction TB`

The central system goes outside any subgraph, rendered as a cylinder `SYS[("...")]`.

### 8. Dashed arrows for non-implemented / out-of-band flows

Use `A -. "label" .-> B` for any flow that is not a real system-to-system integration: manual flagging, platform runtime, "stated NFR but not implemented". This visually preserves the gap distinction without needing colour or text annotation.

## Document content

### 9. The compact `Attribute / Detail` table is mandatory under each dependency

Every numbered detail entry has an 8-row (inbound) or 9-row (outbound) compact table after a 1–2 sentence lead paragraph. Without this, the document slips into prose and stops being scannable. The table mirrors the row in the top-of-document `## At a Glance` summary, with each cell expanded to the level of detail a reader needs.

### 10. The `## At a Glance` table covers *all* flows in one place

One table at the top, with all numbered rows (inbound + platform + outbound). Anyone wanting a 30-second read should be able to skim that table alone and know what depends on what. Avoid splitting it into separate inbound / outbound summary tables — the at-a-glance value comes from seeing both directions side by side.

### 11. Cite source documents in a blockquote, not inline

Each detail entry ends with:

```markdown
> Sources: *Doc Name* (section reference); *Other Doc* (section reference).
```

The house stylesheet renders this with a light grey left bar and muted text, which keeps citations visually distinct from body prose without dominating the page.

### 12. List source documents that were *actually* read

The `## Source Documents` section at the bottom must exactly match the files at the top level of the input folder when the skill ran. Don't pad the list with documents that weren't actually consumed; don't omit ones that were.

### 18. Manual-copy dependencies are first-class

Several runs against the same source documents produced different catalogues because the model interpreted *"no integration; users enter data by hand"* as *"no dependency"*. It is not. If there is a **named upstream system** whose data is moved into the target system by a human transcribing, re-keying, or copy-pasting, that upstream system is a real inbound dependency — its `Status` is `Manual copy`, its `Mechanism` describes the human path, and it appears as a numbered row in the catalogue.

The distinction that matters is not *automated vs manual*, it is *named upstream system vs no upstream system*. If court staff enter availability into JI from a paper rota in their head, there is no upstream system and no dependency. If court staff enter availability into JI from data they look up in eLinks, eLinks is the dependency — recorded with `Status` = `Manual copy`. The catalogue is about *what `<SystemShort>` depends on*, not about *what is automated*.

### 19. Discovery has a floor, not a ceiling — the keyword scan is the floor

`scripts/find-manual-flows.sh` scans the extracted text for ~23 canonical phrases (`copies from`, `manually enter`, `transcribe`, `look up in`, `obtained from`, `no integration`, `out-of-band`, …) and writes `output/manual-flow-candidates.txt`. The script is the *discovery floor*: anything it finds, the model **must** reconcile in Phase 2d (either as a catalogue entry or as a written dismissal). It is not the ceiling — the model still has to enumerate systems the script can't keyword-match.

Why have the script at all if the model already enumerates? Because models forget. Across runs, the prose-level instruction to "look in NFR sections" or "check for manual transfers" is followed unevenly. A 100-line shell script does not forget. The script is intentionally over-eager; false positives are cheap to dismiss in `phase-2d-checks.md`, while missed dependencies are expensive (they're the failure mode this exists to prevent).

### 20. Phase 2 produces auditable artefacts

The discovery / classification phase used to be entirely in the model's head. Now it produces four files under `<input-folder>/output/`, and Phase 3 authoring is gated on all four:

| Artefact | Purpose |
|----|----|
| `manual-flow-candidates.txt` | Discovery floor — every keyword hit, sorted, byte-stable across re-runs. Generated by `find-manual-flows.sh`. |
| `system-enumeration.md` | Every named system, with canonical name, aliases, classification, closed-vocabulary `Status` and citation. Includes ruled-out systems. |
| `system-aliases.json` | Pinned canonical-to-aliases map so the same alias resolution applies across re-runs. |
| `phase-2d-checks.md` | Seven fixed checklist items, each marked ✅ with justification or ❌ with resolution action. Authoring blocked until all ✅. |

These artefacts make re-runs reproducible (the same map, the same enumeration, the same checks) and reviewable (a human can spot a missed system in seconds). They live under `<input-folder>/output/`, alongside `extracted-text/` and the eventual `data-dependencies.{md,pdf}`, so the running repo never accumulates per-run state.

## Distillation

### 13. Extract text first; don't load binaries into Claude's context

The original ji-analysis session had ~6 MB of binary docs to analyse. Loading them into context wasted tokens and produced lower-quality reads than working from already-extracted plain text. The skill's `distil-binary-data.sh` writes UTF-8 `.txt` files into `<input-folder>/output/extracted-text/` and the analysis works from those.

### 14. Top-level only — never descend into subfolders of the input

The user's source folders typically contain a `build/` or `output/` directory of generated artefacts that look document-like but are not the source. The instruction applied here ("Look at the documents in the folder only — do not go into subfolders") is general — preserve it. `distil-binary-data.sh` enforces this with `find -maxdepth 1`.

### 15. macOS `.doc` needs `textutil`; `.docx` and `.pptx` work with pandoc

The legacy Word binary `.doc` format does not parse well in pandoc. `textutil -convert txt` (built into macOS) handles it cleanly. Don't try `pandoc input.doc` and assume the empty output is "no content".

PowerPoint `.pptx` is handled by pandoc directly (`pandoc -f pptx -t plain --wrap=none`). Pandoc reads the embedded slide XML and emits speaker text, bulleted content, table contents and slide titles as plain text. The format detection occasionally mis-fires on `.pptx` if the file extension is unusual or absent, so the script passes `-f pptx` explicitly. Embedded images and complex SmartArt do not extract; they show up as bracketed alt-text fragments (e.g. `[3d fluency style increase icon]`) which are harmless to leave in the extracted text.

## Project hygiene

### 16. Outputs go alongside the input data, never inside the running project

Per the user's CLAUDE.md, the system `/tmp` and `/var/folders/` are out of bounds — but equally, the repo running the skill must not accumulate per-run artefacts either. Tooling and data are kept strictly separate:

- Tooling lives with the skill (`.claude/lib/create-data-dependency-architecture/`).
- Every per-run output — extracted text, build markdown, Mermaid PNGs, the rendered PDF — lives under `<input-folder>/output/` (e.g. `output/extracted-text/`, `output/data-dependencies.md`, `output/data-dependencies.assets/`).

This way the skill can be invoked against any docs folder without leaking artefacts back into the project running it, and the same output layout matches the sibling `docs-to-c4` skill. Outputs are inspectable and the user can decide whether to keep them with the source documents or discard them after a run.

### 17. Don't run any git operations from inside Claude

The project's CLAUDE.md and the user's saved memory both say git is handled externally via VSCode. The skill should never `git add`, `git commit`, `git push`, or open PRs. Producing the PDF + markdown is the deliverable; commits are not part of the skill.
