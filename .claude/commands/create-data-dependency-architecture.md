---
description: Produce a deterministic styled PDF cataloguing a system's inbound and outbound data dependencies on other systems, from a folder of source binary documents (.docx, .doc, .pdf, .md, .txt). Distils the binaries to plain text, identifies flows, writes a Markdown document with a top-level "At a Glance" summary table, three Mermaid diagrams (Data flow overview + Inbound flow + Outbound flow), and a compact Attribute / Detail table under every dependency, then renders to a styled PDF.
argument-hint: "<input_folder> [system_name]"
---

# /create-data-dependency-architecture

The input folder for this run is: **$ARGUMENTS**

Read the full pipeline specification at `.claude/lib/create-data-dependency-architecture/SKILL.md` and execute the five phases against the input folder above. The supporting assets, scripts, templates and reference documents all live alongside the spec at `.claude/lib/create-data-dependency-architecture/`:

- `assets/doc-style.css` — house WeasyPrint stylesheet (typography, dark headers, zebra rows, A4 with 2cm × 1.25cm margins)
- `assets/mermaid-config.json` — Mermaid theme (default + Helvetica)
- `scripts/distil-binary-data.sh` — top-level-only binary → plain-text extractor
- `scripts/find-manual-flows.sh` — manual-flow keyword scan; produces `output/manual-flow-candidates.txt` as the Phase 2 discovery floor
- `scripts/build-pdf.sh` + `scripts/md_to_pdf.py` — the PDF build pipeline (pre-renders Mermaid → PNG, then `pandoc --wrap=none --pdf-engine=weasyprint`)
- `templates/data-dependencies.template.md` — output skeleton
- `references/OUTPUT-STRUCTURE.md` — deterministic content shape
- `references/STYLE-GUIDE.md` — author-facing house style
- `references/LESSONS-LEARNED.md` — non-obvious build settings (read before "fixing" the pipeline)

The build is deterministic: same input + same skill files = byte-equivalent output (modulo PNG rasterisation). All artefacts go in `<input_folder>/output/` (extracted text, markdown, PDF, build assets) — never in `.claude/lib/`, and never in the repo running the command.
