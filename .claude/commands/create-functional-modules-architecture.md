---
description: Produce a deterministic styled PDF cataloguing a system's functional modules from a folder of source binary documents (.docx, .doc, .pdf, .md, .txt). Distils the binaries to plain text, identifies modules, writes a Markdown document with a top-level "At a Glance" module table, a single Mermaid module overview diagram, and a per-module section (Capabilities bullets + Attribute / Detail table + Key user actions + Sources blockquote), then renders to a styled PDF using the same house typography as the data-dependency skill.
argument-hint: "<input_folder> [system_name]"
---

# /create-functional-modules-architecture

The input folder for this run is: **$ARGUMENTS**

Read the full pipeline specification at `.claude/lib/create-functional-modules-architecture/SKILL.md` and execute the five phases against the input folder above. The skill consumes the shared house pipeline at `.claude/lib/_shared/` (owned by `_shared/`, not by this skill — see `.claude/lib/_shared/README.md`):

- Shared house style → `.claude/lib/_shared/assets/doc-style.css` (WeasyPrint stylesheet) and `.claude/lib/_shared/assets/mermaid-config.json` (Mermaid theme)
- Shared distiller → `.claude/lib/_shared/scripts/distil-binary-data.sh` (top-level-only binary → text)
- Shared PDF builder → `.claude/lib/_shared/scripts/build-pdf.sh` + `.claude/lib/_shared/scripts/python/md_to_pdf.py` (pre-renders Mermaid → PNG, then `pandoc --wrap=none --pdf-engine=weasyprint`)

Skill-local files (in `.claude/lib/create-functional-modules-architecture/`):

- `scripts/find-modules.sh` — module-keyword scan; produces `output/module-candidates.txt` as the Phase 2 discovery floor
- `templates/functional-modules.template.md` — output skeleton
- `references/OUTPUT-STRUCTURE.md` — deterministic content shape
- `references/STYLE-GUIDE.md` — author-facing house style for module-level docs
- `references/LESSONS-LEARNED.md` — non-obvious settings inherited from the build pipeline + the new module-enumeration lessons

The build is deterministic: same input + same skill files = byte-equivalent output (modulo PNG rasterisation). All artefacts go in `<input_folder>/output-functional-modules/` (extracted text, markdown, PDF, build assets) — never in `.claude/lib/`, never in the repo running the command, and never in the data-dependency skill's `<input_folder>/output/` folder. The two skills coexist by partitioning the input folder's output namespace at the top level.
