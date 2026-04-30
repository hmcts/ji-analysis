# JI Analysis 

## Slash command — Docs to C4

### Purpose

This skill automates the creation of [C4 architecture models](https://c4model.com/) from existing documentation. Rather than manually reading through requirements, design specs, and capability documents to draw architecture diagrams by hand, this skill extracts system structure directly from your documents and produces a browsable, interactive C4 model.

The quality of the generated model reflects the quality of the input documentation. Well-structured documents with clear descriptions of systems, integrations, actors, and boundaries will produce rich, detailed models. Sparse or ambiguous documentation will produce simpler models with gaps clearly flagged for follow-up.

### Overview

A Claude Code skill that transforms a folder of mixed-format documents (.docx, .pdf, .xlsx, .md) into a browsable C4 architecture model, powered by [Structurizr](https://structurizr.com/).

Give it a pile of requirements docs, design specs, or capability documents and it produces:

- A **Structurizr DSL workspace** with System Context, Container, and Component views
- A **static browsable site** you can share with your team
- A **live preview server** for interactive exploration

### Supported platform

| Platform | Status |
|----------|--------|
| macOS (Apple Silicon & Intel) | Supported |
| Linux | Not tested |
| Windows | Not tested |

## Prerequisites

The command requires the following tools on your PATH. Install them all before first use:

```sh
# Java 25+ (required by structurizr-site-generatr)
brew install openjdk@25

# Python 3.10+ (required for document conversion)
brew install python@3

# Structurizr Site Generatr (generates the browsable C4 site)
brew tap avisi-cloud/tools
brew install structurizr-site-generatr

# Claude Code CLI (the slash command runs inside Claude Code)
# See https://docs.anthropic.com/en/docs/claude-code/overview
npm install -g @anthropic-ai/claude-code
```

### BMAD plugin

The command depends on `bmad-distillator` for document compression. Install the [BMAD plugin](https://github.com/bmadcode/BMAD-METHOD) for Claude Code so that the `bmad-distillator` skill is available in your session.

### Verify prerequisites

Run the preflight check script to confirm everything is in place:

```sh
bash .claude/lib/docs-to-c4/scripts/check_prereqs.sh
```

Expected output:

```
OK — prerequisites satisfied.
  java: openjdk version "25" 2025-09-16
  python3: Python 3.14.0
  structurizr-site-generatr: /opt/homebrew/bin/structurizr-site-generatr
  bmad-distillator: /path/to/.claude/skills/bmad-distillator
```

## Installation

Clone this repository:

```sh
git clone git@github.com:scrumconnect/ji-analysis.git
cd ji-analysis
```

The slash command entry-point lives at `.claude/commands/docs-to-c4.md`; the implementation (scripts, assets, references) lives at `.claude/lib/docs-to-c4/`. Both are auto-discovered by Claude Code when you open a session in this project directory.

On first run, the command creates a Python virtual environment at `.claude/lib/docs-to-c4/scripts/python/.venv/` and installs its Python dependencies (`python-docx`, `pypdf`, `openpyxl`) automatically. No manual pip install required.

## Usage

From within a Claude Code session in this project:

```
/docs-to-c4 /path/to/your/documents
```

Or with an explicit system name:

```
/docs-to-c4 /path/to/your/documents "My System Name"
```

The command runs end-to-end on demand and places all output inside `<input_folder>/output/`.

## How it works

```mermaid
sequenceDiagram
    participant User
    participant Skill as docs-to-c4
    participant Prereqs as check_prereqs.sh
    participant Converter as convert_docs_to_md.sh
    participant Distillator as bmad-distillator
    participant Synth as C4 Synthesiser
    participant Validator as validate_dsl.sh
    participant Generator as generate_site.sh

    User->>Skill: /docs-to-c4 <input_folder>

    Note over Skill: Step 1 — Preflight checks
    Skill->>Prereqs: Check Java 25+, Python 3, structurizr-site-generatr, bmad-distillator
    Prereqs-->>Skill: All prerequisites satisfied

    Note over Skill: Step 2 — Validate input folder
    Skill->>Skill: Confirm folder exists and contains files

    Note over Skill: Step 3 — Create output scaffold
    Skill->>Skill: mkdir output/converted, output/distilled

    Note over Skill: Step 4 — Convert binary docs to Markdown
    Skill->>Converter: .docx, .pdf, .xlsx files
    Converter-->>Skill: .md files (typically 50-100x smaller)

    Note over Skill: Step 5 — Distill documents
    Skill->>Distillator: Converted .md files
    Note over Distillator: Fan-out compression per document,<br/>then merge and deduplicate
    Distillator-->>Skill: Single distillate (~10:1 compression)

    Note over Skill: Step 6 — Synthesise C4 model
    Skill->>Synth: Distillate + C4 guide + DSL template
    Note over Synth: Identify actors, systems, containers,<br/>components, relationships,<br/>and explicit non-integrations
    Synth-->>Skill: workspace.dsl

    Note over Skill: Step 7 — Validate DSL
    Skill->>Validator: workspace.dsl
    Validator-->>Skill: DSL validates (or fix and retry)

    Note over Skill: Step 8 — Generate static site
    Skill->>Generator: workspace.dsl
    Generator-->>Skill: Browsable HTML site

    Note over Skill: Step 9 — Write README
    Skill->>Skill: Generate output/README.md with serve commands

    Note over Skill: Step 10 — Print serve command
    Skill-->>User: Copy-paste command to start live preview at localhost:8080
```

## Output structure

All generated artefacts are placed inside `<input_folder>/output/`:

```
<input_folder>/
├── ...source documents (untouched)...
└── output/
    ├── converted/           # Binary docs converted to .md
    ├── distilled/           # Compressed distillate for C4 modelling
    ├── workspace.dsl        # Structurizr DSL — the C4 model
    ├── site/                # Static browsable site
    └── README.md            # Regeneration and serve commands
```

Source documents are never modified.

## Viewing the model

After the skill completes, it prints the exact command to start the live preview server. It looks like:

```sh
/path/to/.claude/lib/docs-to-c4/scripts/serve_site.sh /path/to/output/workspace.dsl
```

Open `http://localhost:8080` in your browser. Stop the server with Ctrl+C.

## C4 views generated

| View | What it shows |
|------|---------------|
| **System Context** | The system, its users (by role), external systems it integrates with, and systems it explicitly does *not* integrate with (architectural boundaries) |
| **Container** | Deployable units inside the system (web apps, APIs, databases) with technology labels |
| **Component** | Internal structure of containers where the source docs describe modules, services, or functional areas |

The skill only models what the source documents describe. It does not infer or hallucinate architecture.

## Supported input formats

| Format | How it's handled |
|--------|-----------------|
| `.docx` | Text, headings, and tables extracted via python-docx |
| `.pdf` | Page-by-page text extraction via pypdf |
| `.xlsx` | Sheet-by-sheet table extraction via openpyxl |
| `.md`, `.txt`, `.csv`, `.json`, `.yaml` | Copied as-is |

## Re-running the command

The command is idempotent — running it again on the same input folder produces an equivalent model. However, **re-running will overwrite previous output** including `workspace.dsl`, the distillate, converted files, and the generated site. If you have manually edited `workspace.dsl`, back it up before re-running.

The document converter supports a `--skip-existing` flag to avoid re-converting files that already have output, but the command does not use this by default.

## Command file structure

```
.claude/
├── commands/
│   └── docs-to-c4.md                   # Slash command entry-point (/docs-to-c4)
└── lib/
    └── docs-to-c4/
        ├── SKILL.md                    # Pipeline specification
        ├── assets/
        │   └── workspace-template.dsl  # Starter DSL template with styles
        ├── references/
        │   ├── c4-model-guide.md       # C4 level primer
        │   └── structurizr-dsl-guide.md # DSL syntax crib sheet
        └── scripts/
            ├── check_prereqs.sh        # Preflight check (Java, Python, tools, BMAD)
            ├── convert_docs_to_md.sh   # Shell wrapper for document conversion
            ├── validate_dsl.sh         # DSL validation via dry-run generation
            ├── generate_site.sh        # Full static site generation
            ├── serve_site.sh           # Live preview server
            └── python/
                ├── convert_docs_to_md.py # Python document converter
                └── requirements.txt    # Python dependencies
```

## Slash command — Create Data Dependency Architecture

### Purpose

This command produces a deterministic, styled PDF cataloguing a system's data dependencies on other systems, in both directions. Rather than freehand-writing an integration document each time and arguing over what shape it should take, the command encodes the content shape, the visual style, and the build pipeline so every run for every system produces an artefact in the same format.

The quality of the output reflects the quality of the input documentation — the command never invents dependencies, every entry traces to a specific section of one of the input documents.

### Overview

A Claude Code slash command that turns a folder of mixed-format documents (.docx, .doc, .pdf, .md, .txt) into a styled, reviewable PDF that catalogues the system's inbound and outbound data flows.

Give it a folder of capability documents, requirements specs and operational guides and it produces:

- A **top-of-document At-a-Glance summary table** listing every flow in one compact view
- **Three Mermaid diagrams** (rendered to PNG before embedding): a top-level *Data flow overview*, plus *Inbound flow* and *Outbound flow* detail diagrams showing the human actors and intermediate steps between source/destination and the system
- A **compact `Attribute / Detail` table** under every numbered dependency, with source citations
- A **rendered PDF** in the house style (Helvetica, dark navy headers with white text, zebra-striped rows, ArchiMate-style rectangular diagrams)

### Supported platform

| Platform | Status |
|----------|--------|
| macOS (Apple Silicon & Intel) | Supported |
| Linux | Should work — drop-in replacement for `textutil` needed (e.g. `libreoffice --headless`) |
| Windows | Not tested |

## Prerequisites

The command requires the following tools on your PATH. Install them all before first use:

```sh
# Python 3.10+ (typing syntax in the build script)
brew install python@3

# Pandoc (Markdown -> HTML, .docx -> text)
brew install pandoc

# Mermaid CLI (renders diagram blocks to PNG before embedding)
npm install -g @mermaid-js/mermaid-cli

# Poppler (provides pdftotext for ingesting .pdf source documents)
brew install poppler

# textutil ships with macOS — used for legacy .doc files
```

WeasyPrint (the PDF rendering engine pandoc uses via `--pdf-engine=weasyprint`) is **not** installed system-wide — the skill's `build-pdf.sh` creates a Python virtual environment under `.claude/lib/create-data-dependency-architecture/scripts/python/.venv/` on first run and installs WeasyPrint there from the skill's `requirements.txt`, then prepends the venv's `bin/` to `PATH` so pandoc finds it. No manual pip install required; deleting `.venv/` and re-running rebuilds it.

`textutil` is built into macOS and used to extract text from the legacy `.doc` binary format. On Linux, swap in `libreoffice --headless --convert-to txt` or `antiword`.

## Installation

The slash command entry-point lives at `.claude/commands/create-data-dependency-architecture.md`; the implementation (CSS, Mermaid config, build scripts, template, references) lives at `.claude/lib/create-data-dependency-architecture/`. Both are auto-discovered by Claude Code when you open a session in this project directory. There is no separate bootstrap step — the command is fully self-contained.

If you want to call the build pipeline from outside a Claude session (e.g. as part of a docs-build CI step), invoke `.claude/lib/create-data-dependency-architecture/scripts/build-pdf.sh` directly — it bootstraps its own venv from the sibling `scripts/python/requirements.txt` and reads the house style from `.claude/lib/create-data-dependency-architecture/assets/`. There is no longer a duplicate copy at the repo root.

## Usage

From within a Claude Code session in this project:

```
/create-data-dependency-architecture /path/to/your/documents
```

Or with an explicit system name:

```
/create-data-dependency-architecture /path/to/your/documents "My System Name"
```

The command runs end-to-end on demand and places all output inside `<input_folder>/output/`. The repo running the command is never written to — tooling lives with the skill, data (inputs and outputs) lives with the input folder.

## How it works

```mermaid
sequenceDiagram
    participant User
    participant Skill as create-data-dependency-architecture
    participant Distil as distil-binary-data.sh
    participant Claude as Claude (analysis)
    participant Build as build-pdf.sh
    participant Mmdc as mmdc (Mermaid CLI)
    participant Pandoc as pandoc + WeasyPrint

    User->>Skill: /create-data-dependency-architecture <input_folder>

    Note over Skill: Phase 1 — Distil binaries to plain text
    Skill->>Distil: top-level files in <input_folder>
    Note over Distil: pandoc for .docx,<br/>textutil for .doc,<br/>pdftotext for .pdf,<br/>copy for .md/.txt
    Distil-->>Skill: .txt files in <input_folder>/output/extracted-text/

    Note over Skill: Phase 2 — Identify dependencies
    Skill->>Claude: read distilled .txt files
    Note over Claude: classify each external system<br/>as Inbound / Outbound / Platform,<br/>capture data items, mechanism,<br/>frequency, status, criticality,<br/>and source citations
    Claude-->>Skill: structured list of flows

    Note over Skill: Phase 3 — Author markdown
    Skill->>Skill: fill template (YAML title, At-a-Glance table,<br/>three Mermaid blocks, per-section<br/>Attribute|Detail tables, sources blockquotes)

    Note over Skill: Phase 4 — Render PDF
    Skill->>Build: .claude/lib/.../scripts/build-pdf.sh <output.md>
    Build->>Mmdc: each ```mermaid block
    Mmdc-->>Build: PNG diagrams (default theme)
    Build->>Pandoc: rewritten markdown + house CSS
    Pandoc-->>Build: A4 PDF (Helvetica, dark headers,<br/>zebra rows, narrow margins)
    Build-->>Skill: <input_folder>/output/data-dependencies.pdf

    Note over Skill: Phase 5 — Verify
    Skill-->>User: Page count, file size, output paths
```

## Output structure

All generated artefacts are placed inside `<input_folder>/output/` — alongside the input data, never inside the repo running the command. Authoring guides, build scripts, CSS, Mermaid configuration and the document template all live inside `.claude/lib/create-data-dependency-architecture/`, separate from any per-run output:

```
<input_folder>/
├── ...source documents (untouched, top level)...
└── output/
    ├── extracted-text/                 # Plain-text extractions of each source binary
    ├── data-dependencies.md            # Source markdown with YAML front matter
    ├── data-dependencies.pdf           # Rendered PDF (the deliverable)
    └── data-dependencies.assets/       # Build artefacts (kept for inspection)
        ├── build.md                    # Pandoc-ready markdown after Mermaid substitution
        ├── diagram-1.png               # Data flow overview (Inbound / Platform / Outbound)
        ├── diagram-2.png               # Inbound flow — Source -> Actors -> JI screens
        └── diagram-3.png               # Outbound flow — JI -> Actors -> Destination
```

Source documents are never modified; the command works from the plain-text extractions in `output/extracted-text/`.

## Output document shape

Every PDF produced by this command has the same structure, in the same order:

| Section | What it contains |
|---------|------------------|
| **Title block** | YAML-driven title + subtitle, centred, dark navy |
| **Lead paragraph + bullets** | Inbound vs Outbound definition |
| **At a Glance** | Compact 5-column summary of every flow (no Status column — that lives in the per-section table) |
| **Data flow overview** | Single Mermaid diagram clustering Inbound / Platform / Outbound around the central system |
| **Inbound dependencies** | Numbered detail entries, each with a 1–2 sentence lead, an 8-row `Attribute / Detail` table at 20% / 80% column split, and a source-citation blockquote |
| **Inbound flow** | Mermaid diagram tracing each source through the actors and JI screens that consume it |
| **Outbound dependencies** | Numbered detail entries with a 9-row `Attribute / Detail` table (extra `Format` row) |
| **Outbound flow** | Mermaid diagram tracing JI's outputs through actors to each destination |
| **Summary** | 3–5 high-level observations |
| **Source Documents** | Exact list of input files actually consumed |

## Re-running the command

The command is **deterministic** — running it again on the same input folder produces a byte-equivalent document (modulo PNG rasterisation). Re-running **overwrites** previous output. If you have manually edited `data-dependencies.md`, back it up before re-running.

## Command file structure

```
.claude/
├── commands/
│   └── create-data-dependency-architecture.md  # Slash command entry-point
└── lib/
    └── create-data-dependency-architecture/
        ├── SKILL.md                              # Pipeline specification (5 phases)
        ├── assets/
        │   ├── doc-style.css                     # House CSS (Helvetica, dark headers,
        │   │                                       zebra rows, 8.5pt tables, A4 with
        │   │                                       2cm × 1.25cm margins)
        │   └── mermaid-config.json               # Mermaid theme: default + Helvetica
        ├── scripts/
        │   ├── build-pdf.sh                      # Venv-bootstrapping shell wrapper
        │   ├── distil-binary-data.sh             # Top-level-only binary -> text extractor
        │   └── python/
        │       ├── md_to_pdf.py                  # Pre-renders Mermaid -> PNG, then
        │       │                                   pandoc --wrap=none -> WeasyPrint
        │       ├── requirements.txt              # pip deps (weasyprint)
        │       └── .venv/                        # auto-created on first build (gitignored)
        ├── templates/
        │   └── data-dependencies.template.md     # Output skeleton with placeholders
        └── references/
            ├── OUTPUT-STRUCTURE.md               # Deterministic content shape spec
            ├── STYLE-GUIDE.md                    # Author-facing house style for the pipeline
            └── LESSONS-LEARNED.md                # Critical settings + non-obvious gotchas
                                                  # (e.g. markdown separator-dash widths
                                                  # drive pandoc colgroup widths)
```

## Slash command — Create Functional Modules Architecture

A sibling of the data-dependency command above. Same workflow (distil → discover → author → render), same house style, but produces a **module-organised** view of the system rather than a data-flow view: one detail section per module covering purpose, capabilities, user actions, business rules, NFRs and source citations.

Spec: `.claude/lib/create-functional-modules-architecture/SKILL.md`. Slash-command entry-point: `.claude/commands/create-functional-modules-architecture.md`.

```
/create-functional-modules-architecture /path/to/your/documents
```

Output lands in `<input_folder>/output-functional-modules/` (deliberately a different top-level folder from the data-dependency skill's `<input_folder>/output/` so the two skills' artefacts never mix).

### Contribute to This Repository

Contributions are welcome! Please see the [CONTRIBUTING.md](.github/CONTRIBUTING.md) file for guidelines.

## License

This project is licensed under the [MIT License](LICENSE).