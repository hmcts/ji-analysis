---
description: Audit a codebase against the OWASP Top 10 for Agentic Applications 2026. Runs a deterministic inventory + fingerprint scan over the source files, evaluates the codebase against each ASI entry (ASI01-ASI10) using codified rules, writes a Markdown report and renders it to a styled PDF using the shared house pipeline. The output sits at `<input_folder>/security/owasp/owasp-agentic-top10-report.{md,pdf}`. The report has a fixed shape — executive summary, a colour-coded Risk Status Board headline diagram (2x5 grid of ASI tiles tinted by verdict), codebase fingerprint, At-a-Glance table covering all ten entries, then a per-ASI section with a six-row Attribute / Detail table (Verdict, Severity, Affirmative evidence, Risk signals, Coverage gap, Recommendation) and a sources blockquote.
argument-hint: "<input_folder>"
---

# /check-for-owasp-top10

The codebase under review is at: **$ARGUMENTS**

Read the full pipeline specification at `.claude/lib/check-for-owasp-top10/SKILL.md` and execute the six phases against the folder above. The supporting scripts, templates and reference documents all live alongside the spec at `.claude/lib/check-for-owasp-top10/`:

- `scripts/scan-codebase.sh` — deterministic inventory + agentic-fingerprint scan (Phase 2 discovery floor); writes to `<input_folder>/security/owasp/scan/`
- `templates/report.template.md` — output skeleton (incl. *Risk Status Board* Mermaid block with the codified verdict palette)
- `references/OWASP-AGENTIC-TOP10.md` — **the codified rules** for each ASI entry (description, what to look for in code, verdict rubric, mitigation guidelines). This is the single source of truth for verdicts.
- `references/OUTPUT-STRUCTURE.md` — deterministic content shape for the report (incl. headline-diagram spec + colour palette)
- `references/owasp-top10-source-extract.txt` — plain-text extraction of the source PDF, available for direct citation

Phase 5 (PDF rendering) calls the **shared** house build pipeline at `.claude/lib/_shared/scripts/build-pdf.sh` — same CSS, same Mermaid theme, same A4 layout used by the data-dependency and functional-modules skills. The OWASP report gets the same Helvetica / dark-navy-headers / zebra-rows look as the other PDFs, with one documented divergence: the *Risk Status Board* uses a fixed verdict-coloured palette (red Exposed → light grey N/A) because verdict colour is the data, not branding. The pipeline is owned by `.claude/lib/_shared/`, not by any individual skill — see `.claude/lib/_shared/README.md`.

The output is written to `<input_folder>/security/owasp/owasp-agentic-top10-report.{md,pdf}` plus a sibling `.assets/` build-artefact folder. The repo running the command is never written to; the codebase under review is read-only.

Verdicts come from concrete code references (file:line) — not from documentation claims or absence of evidence. When in doubt, mark `Unknown` rather than `Mitigated` or `Exposed`. Use `Not applicable` only for ASI entries whose architectural prerequisites the codebase has not made (e.g. ASI07 on a single-agent codebase).
