---
name: check-for-owasp-top10
description: Use when the user asks to audit / review / measure a codebase against the OWASP Top 10 for Agentic Applications 2026. Takes a folder path, runs a deterministic scan over its source files, evaluates the codebase against each of the ten ASI entries (ASI01-ASI10) using the codified rules in `references/OWASP-AGENTIC-TOP10.md`, writes a Markdown report and renders it to a styled PDF using the shared house pipeline. The output sits at `<input-folder>/security/owasp/owasp-agentic-top10-report.{md,pdf}`. The report has a fixed shape: YAML front matter, executive summary, a colour-coded Mermaid "Risk Status Board" headline diagram (2x5 grid tinted by verdict), codebase fingerprint, At-a-Glance table covering all ten ASI entries, then a per-ASI section with a 6-row `Attribute / Detail` table (Verdict, Severity, Affirmative evidence, Risk signals, Coverage gap, Recommendation) plus a sources blockquote. Triggered by phrases like "check this codebase against OWASP agentic top 10", "review for OWASP ASI risks", "produce an OWASP agentic security report".
---

# Skill — check-for-owasp-top10

This skill takes a folder of source code and produces a deterministic, comparable report measuring the codebase against the *OWASP Top 10 for Agentic Applications 2026* (December 2025, OWASP GenAI Security Project — Agentic Security Initiative). The deliverable is both Markdown (for diff-friendly review) and a styled PDF (for circulation).

The output is **deterministic in shape and visual style**:

- Content shape is fixed by [`references/OUTPUT-STRUCTURE.md`](references/OUTPUT-STRUCTURE.md) — same sections, same order, same six-row per-ASI table, same headline *Risk Status Board* diagram.
- Visual style is fixed by the shared house pipeline at `.claude/lib/_shared/`: `assets/doc-style.css` (typography, dark headers, zebra rows, A4 with 2cm × 1.25cm margins) and `assets/mermaid-config.json` (Mermaid theme + Helvetica). The OWASP skill *adds* a fixed risk palette for the headline diagram (red `#d62728` Exposed, amber `#ff9933` Partial, green `#2ca02c` Mitigated, grey `#7f7f7f` Unknown, light-grey `#cccccc` Not applicable) — see `references/OUTPUT-STRUCTURE.md` for the codified palette. This is the one place the OWASP skill diverges from `_shared/`'s "default theme only" guideline: verdict colour is the data, so the palette must be stable, codified, and consistent across runs.
- The rules used to evaluate the codebase live in [`references/OWASP-AGENTIC-TOP10.md`](references/OWASP-AGENTIC-TOP10.md) — that file is the single source of truth for what to look for and how to assign verdicts.
- The plain-text extract of the source PDF sits at [`references/owasp-top10-source-extract.txt`](references/owasp-top10-source-extract.txt) for direct citation.

The verdict per ASI is **evidence-based** — it must come from actual code references (file:line), not from documentation claims or absence of evidence. When nothing concrete is found, the verdict is `Unknown`, not `Mitigated`.

## When to use

Use when the user gives you a folder of source code and asks to:

- "check this codebase against the OWASP agentic top 10"
- "review `<repo>` for OWASP agentic AI risks"
- "produce an OWASP agentic security report for `<folder>`"
- "audit `<folder>` for the new OWASP top 10"

Do **not** use this skill for general security review (use the `code-review` skill / standard SAST tools), for OWASP Top 10 *Web* (the categories are different), or for runtime / red-team testing — this skill produces a static, code-grounded review only.

## Inputs

The user supplies:

1. **Path to a folder of source code** — typically the repo root of the application under review. The skill reads file paths relative to this folder.
2. *(Optional)* **A short codebase name** — defaults to the basename of the input folder. Used in the report title.

The skill does not require any binary documents, distillation step or special tooling — only standard shell utilities (`find`, `awk`, `wc`, `sort`, optionally `rg`).

## External tools required on PATH

- `bash` (4+)
- `find`, `awk`, `wc`, `sort`, `sed`, `xargs`
- `ripgrep` (`rg`) — preferred for the fingerprint scan; the script falls back to `grep -rn` if `rg` is missing.
- For Phase 5 (PDF rendering), the same tools the data-dependency skill needs:
  - `python3` (3.10+)
  - `pandoc`
  - `weasyprint` (auto-installed by the build script into a venv on first run)
  - `mmdc` (Mermaid CLI — `npm install -g @mermaid-js/mermaid-cli`)

If `ripgrep` is missing, surface it to the user as a soft warning; the fallback works but is much slower on large repos. If any of the PDF-rendering tools are missing, the skill should still write the Markdown report (Phase 4 still succeeds) and report which tool was missing instead of producing the PDF.

## Pipeline

Run these phases in order. Each phase reads the previous phase's outputs.

### Phase 1 — Verify input + bootstrap output folder

1. Verify `<input-folder>` exists and is a directory. If not, error and stop.
2. Create `<input-folder>/security/owasp/` (this is where the report goes) and `<input-folder>/security/owasp/scan/` (scratch area for the scan artefacts).
3. Capture the review date (`YYYY-MM-DD`) and, if `<input-folder>` is a git repository, the short SHA via `git -C <input-folder> rev-parse --short HEAD`. If the working tree is dirty, append `-dirty`. If the folder is not a git repo, record `uncommitted working tree`.

### Phase 2 — Deterministic codebase scan

Run `scripts/scan-codebase.sh <input-folder>` (default output goes to `<input-folder>/security/owasp/scan/`). This produces four files:

| File | Purpose |
|----|----|
| `inventory.txt` | Sorted list of every code-eligible file scanned (paths relative to `<input-folder>`). |
| `inventory-counts.txt` | File counts by top-level directory and by extension; total file count. |
| `loc.txt` | Total lines of code across the inventory. |
| `fingerprint-hits.txt` | Grep hits for agentic-app fingerprints (frameworks, vector stores, RCE patterns, peer-agent protocols), one match per line: `path:line:matched-text`. |

This phase is the *discovery floor*: anything in `fingerprint-hits.txt` is a candidate piece of evidence the model must reconcile in Phase 3 (either as affirmative evidence, as a risk signal, or as dismissed-with-reason). The phase itself is byte-stable across re-runs.

### Phase 3 — Read and evaluate

For each ASI entry in order ASI01–ASI10:

1. Read the corresponding section of [`references/OWASP-AGENTIC-TOP10.md`](references/OWASP-AGENTIC-TOP10.md). It tells you what to look for, what counts as affirmative, what counts as risk, and how to assign a verdict.
2. Use `Grep`, `Glob` and `Read` to locate concrete evidence in `<input-folder>`. Start from `fingerprint-hits.txt` — that's the floor — but go further: the rules listed in `OWASP-AGENTIC-TOP10.md` cover patterns the script does not match (e.g. semantic patterns, structural choices).
3. For every claim you make in the report, capture an exact `path/relative/to/input/file.py:42` reference. **No file:line, no claim** — claims without code references do not go into the *Affirmative evidence* or *Risk signals* rows.
4. Assign a verdict from the closed vocabulary: `Mitigated`, `Partial`, `Exposed`, `Unknown`, `Not applicable`.
5. Assign a severity from `Critical`, `High`, `Medium`, `Low`, `Informational`, `—` (use `—` only when verdict is `Not applicable`).
6. Write the per-ASI bullet evidence (file references) in concise prose — no narrative, just the facts.

Important rules:

- **Use `Not applicable` correctly.** ASI07 (Insecure Inter-Agent Communication) is `Not applicable` if the codebase has no peer-agent calls. ASI10 (Rogue Agents) is `Not applicable` if there is no autonomous behaviour beyond a single tool call. Don't pad the report with "Mitigated" for things that simply don't exist in the code.
- **Don't confuse documentation with implementation.** A README that says "we use signed manifests" is not evidence — only code that actually validates a signature counts.
- **When in doubt, mark `Unknown`.** If you can see neither an affirmative pattern nor a risk pattern, the right verdict is `Unknown` with a `Coverage gap` row explaining what would need to be checked at runtime.
- **Severity is contextual.** A `Partial` verdict on a code-execution surface is High; a `Partial` verdict on inter-agent-comms in a single-agent codebase is Low or Informational. Use the rubric in `OWASP-AGENTIC-TOP10.md` § *How the rubric translates to severity*.

### Phase 4 — Author the report markdown

Use [`templates/report.template.md`](templates/report.template.md) as the skeleton; fill it in following [`references/OUTPUT-STRUCTURE.md`](references/OUTPUT-STRUCTURE.md) **exactly**.

Critical rules (full list in `OUTPUT-STRUCTURE.md`):

- YAML front matter with `title:`, `subtitle:`, `date:` — no leading H1 in the body.
- One `## Risk Status Board` Mermaid block near the top — a 2×5 grid of ASI tiles tinted by verdict using the codified palette (red Exposed / amber Partial / green Mitigated / grey Unknown / light-grey N/A). Each tile node carries the verdict's classDef name (`:::exposed`, `:::partial`, `:::mitigated`, `:::unknown`, `:::na`) — picked deterministically from each ASI's Phase 3 verdict. **Do not invent new colours per run** — the palette is a fixed part of the skill, not a per-document choice.
- One `## At a Glance` table covering **all ten** ASI entries, in order ASI01–ASI10. Use the closed-vocabulary Verdict and Severity values verbatim. Cells terse — 6–14 words for the Headline column.
- The table-separator dash pattern `4 / 37 / 14 / 14 / 50` is load-bearing — copy it verbatim from the template; it controls Pandoc's column widths.
- Every per-ASI section has the **same six-row `Attribute / Detail` table**: Verdict, Severity, Affirmative evidence, Risk signals, Coverage gap, Recommendation. Six rows, every time, even when an answer is "None observed" or "—". Use the dash pattern `5 / 20` for the separator row (20% / 80% column split — narrow Attribute label, wide Detail).
- The `> Sources:` blockquote is mandatory and identical across all ten entries.
- Cross-references inside the document use the no-number heading-anchor form (Pandoc strips leading numbers from heading IDs).
- Mermaid line-break rules from the data-dependency skill's `LESSONS-LEARNED` apply: use `<br/>` inside node labels, never `\n`.

Save the markdown to:

```
<input-folder>/security/owasp/owasp-agentic-top10-report.md
```

If the file already exists, **overwrite it**. The skill is intentionally idempotent — re-running on the same codebase replaces the previous report.

### Phase 5 — Render the PDF

Run the **shared** house build pipeline (the same one used by `create-data-dependency-architecture` and `create-functional-modules-architecture`):

```bash
.claude/lib/_shared/scripts/build-pdf.sh \
  <input-folder>/security/owasp/owasp-agentic-top10-report.md
```

The wrapper invokes `.claude/lib/_shared/scripts/python/md_to_pdf.py` which:

1. Parses YAML front matter for title / subtitle.
2. Pre-renders each ` ```mermaid ` block (including the *Risk Status Board*) to a PNG via `mmdc --configFile=<_shared>/assets/mermaid-config.json`. The classDef colour palette in the headline diagram **is honoured** — `mmdc` respects per-node classDef styling on top of the default theme.
3. Substitutes each block with a Markdown image reference into a working copy of the markdown.
4. Runs `pandoc --wrap=none --pdf-engine=weasyprint --css=<_shared>/assets/doc-style.css` against the working copy.
5. Writes `<input>.pdf` next to the source markdown, plus a sibling `<input>.assets/` folder containing the rendered Mermaid PNGs and the rewritten build markdown.

The resulting layout is identical to the data-dependency skill's PDFs — Helvetica throughout, 11 pt body / 8.5 pt tables, dark-navy headers with white text, zebra rows, A4 with 2 cm × 1.25 cm margins, page numbers bottom-right. **No skill-specific stylesheet** — the OWASP skill consumes the shared house style verbatim. The only difference is the headline diagram's classDef palette, which is data-dependent (verdict colours), not branding.

If pandoc emits any `No anchor #...` errors, find the matching `[label](#wrong-id)` cross-reference in the markdown and correct it (typical cause: leading numbers / in-word punctuation that pandoc strips from heading ids — see the data-dependency skill's `LESSONS-LEARNED.md` LESSON 5).

If a Phase 5 prerequisite is missing (`pandoc`, `weasyprint`, `mmdc`), do not fail the whole run — keep the Markdown deliverable from Phase 4 and report which tool was missing.

### Phase 6 — Verify and report back to user

After writing the report and rendering the PDF:

1. Confirm the markdown exists, has non-zero size, and contains all ten `### ASI<NN>` sections (e.g. via `grep -c '^### ASI' <output>.md`; the count should be 10).
2. If Phase 5 succeeded, run `pdfinfo <output>.pdf | grep -E 'Pages|File size'` to confirm a real PDF was produced.
3. Tell the user: where the report and PDF were written, the per-verdict counts (`X Mitigated, Y Partial, Z Exposed, Q Unknown, R Not applicable`), and the single highest-severity finding by name. Don't post a long summary of the document body — the report is the deliverable.

## Anti-patterns to avoid

- **Don't infer verdicts from absence of evidence.** "I didn't see any `eval()` calls, so ASI05 is Mitigated" is wrong — it's `Unknown` unless you also found *affirmative* evidence (sandboxing, allowlists, etc.). Mark `Unknown` and explain in the Coverage gap row.
- **Don't claim affirmative evidence from documentation.** A doc that says "we use mTLS" is not enough — the report needs the call site that configures mTLS.
- **Don't cite line numbers you didn't actually read.** Re-confirm each `file:line` reference by reading the file before the report ships.
- **Don't pad with `Mitigated` for `Not applicable` cases.** A single-agent codebase doesn't have inter-agent communication — that's `Not applicable`, not `Mitigated`.
- **Don't refactor / fix the code.** This skill produces a *report* — it does not modify the code under review. The report should recommend changes; the user decides whether to apply them.
- **Don't run the user's code.** Even when the codebase has tests, do not execute them. The skill is purely static.
- **Don't commit, push or open PRs.** The repo running the skill must not be modified beyond the skill files themselves; the *target* codebase (`<input-folder>`) is reviewed read-only.

## Command file layout

```
.claude/lib/check-for-owasp-top10/
├── SKILL.md                                 # this file
├── scripts/
│   └── scan-codebase.sh                     # deterministic inventory + fingerprint scan
├── templates/
│   └── report.template.md                   # report skeleton (incl. Risk Status Board + classDef palette)
└── references/
    ├── OWASP-AGENTIC-TOP10.md               # codified rules — what to look for, how to verdict
    ├── OUTPUT-STRUCTURE.md                  # deterministic content shape (incl. headline diagram spec)
    └── owasp-top10-source-extract.txt       # plain-text PDF extraction (for direct citation)
```

The PDF build pipeline (`build-pdf.sh`, `md_to_pdf.py`, `doc-style.css`, `mermaid-config.json`) is owned by `.claude/lib/_shared/` and **shared** with `create-data-dependency-architecture` and `create-functional-modules-architecture` — the OWASP skill calls into it rather than duplicating it. No per-skill stylesheet, no per-skill mermaid config: one house style, one Mermaid theme, used by every PDF this repo's skills produce. See `.claude/lib/_shared/README.md` for the canonical ownership map.

## What goes where — tooling vs data

- **Tooling** lives with the skill at `.claude/lib/check-for-owasp-top10/` (`SKILL.md`, `scripts/`, `templates/`, `references/`) plus the shared build pipeline at `.claude/lib/_shared/`. Nothing per-run is written into either location.
- **Data** — both the input source code and the per-run output — lives at the user-supplied input path:
  - `<input-folder>/` — the codebase under review (never modified).
  - `<input-folder>/security/owasp/scan/` — Phase 2 scan artefacts (`inventory.txt`, `inventory-counts.txt`, `loc.txt`, `fingerprint-hits.txt`).
  - `<input-folder>/security/owasp/owasp-agentic-top10-report.md` — Phase 4 markdown deliverable.
  - `<input-folder>/security/owasp/owasp-agentic-top10-report.pdf` — Phase 5 PDF deliverable.
  - `<input-folder>/security/owasp/owasp-agentic-top10-report.assets/` — Phase 5 build artefacts (rendered Mermaid PNGs, rewritten build markdown — kept for inspection).
- **The repo running the skill** is never written to by a skill run; the repo's own `docs/` directory is not part of this skill.
