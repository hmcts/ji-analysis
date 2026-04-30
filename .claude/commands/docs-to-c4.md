---
description: Transform a folder of mixed-format source documents (.docx, .pdf, .xlsx, .md) into a browsable C4 architecture model — Structurizr DSL workspace plus a static HTML site. Runs bmad-distillator on the sources, synthesizes the workspace (System Context view at minimum, plus Container and Component views when supported), validates the DSL, and generates a browsable site via `structurizr-site-generatr`. The skill only models what the source documents describe — it does not infer or hallucinate architecture.
argument-hint: "<input_folder> [system_name]"
---

# /docs-to-c4

The input folder for this run is: **$ARGUMENTS**

Read the full pipeline specification at `.claude/lib/docs-to-c4/SKILL.md` and execute it against the input folder above. The supporting scripts, templates and reference documents all live alongside the spec at `.claude/lib/docs-to-c4/`:

- `scripts/check_prereqs.sh` — preflight check (Java 25+, Python 3, structurizr-site-generatr, bmad-distillator)
- `scripts/convert_docs_to_md.sh` + `scripts/python/convert_docs_to_md.py` — binary-to-Markdown converter
- `scripts/validate_dsl.sh` — DSL validation via dry-run generation
- `scripts/generate_site.sh` — full static site build
- `scripts/serve_site.sh` — live preview server (default port 8080)
- `assets/workspace-template.dsl` — starter DSL template with house styles
- `references/c4-model-guide.md` — C4 level primer
- `references/structurizr-dsl-guide.md` — DSL syntax crib sheet

All output lands inside `<input_folder>/output/`; source documents are never modified.
