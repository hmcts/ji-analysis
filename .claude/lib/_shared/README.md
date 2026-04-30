# `_shared/` — shared assets used by multiple skills in this repo

This folder is **not a skill**. It is a library of assets and scripts that several skills consume from one canonical location, so there is no ambiguity about ownership and no duplication across skills. The leading underscore is a convention to make this obvious — `_shared/` sorts before any real skill folder and signals "supporting library, not a slash command".

## What's here

```
.claude/lib/_shared/
├── README.md                       # this file
├── assets/
│   ├── doc-style.css               # WeasyPrint stylesheet — house typography,
│   │                                 dark headers, zebra rows, A4 with
│   │                                 2 cm × 1.25 cm margins
│   └── mermaid-config.json         # Mermaid theme (default + Helvetica)
└── scripts/
    ├── build-pdf.sh                # Venv-bootstrapping shell wrapper that
    │                                 invokes md_to_pdf.py
    ├── distil-binary-data.sh       # Top-level-only binary → plain-text
    │                                 extractor (.docx / .doc / .pdf / .pptx /
    │                                 .md / .markdown / .txt)
    └── python/
        ├── md_to_pdf.py            # Pre-renders Mermaid blocks to PNG via
        │                             mmdc, then runs pandoc --wrap=none with
        │                             the house CSS through WeasyPrint
        ├── requirements.txt        # pip deps for the build (weasyprint)
        └── .venv/                  # Auto-created on first build (gitignored)
```

## Who consumes what

| Skill | Uses |
|---|---|
| `create-data-dependency-architecture` | `distil-binary-data.sh` (Phase 1), `build-pdf.sh` + `md_to_pdf.py` + `assets/*` (Phase 4) |
| `create-functional-modules-architecture` | `distil-binary-data.sh` (Phase 1), `build-pdf.sh` + `md_to_pdf.py` + `assets/*` (Phase 4) |
| `check-for-owasp-top10` | `build-pdf.sh` + `md_to_pdf.py` + `assets/*` (Phase 5). Does not use the distiller — it works against source code, not binary documents. |

The `docs-to-c4` skill is **independent** — it has its own toolchain (Java + structurizr-site-generatr) and does not consume anything from `_shared/`.

## Calling conventions

Skills call into this folder by **absolute repo-rooted path**, not by relative path:

```bash
# Distillation (data-dep, functional-modules)
.claude/lib/_shared/scripts/distil-binary-data.sh <input-folder>

# PDF rendering (data-dep, functional-modules, OWASP)
.claude/lib/_shared/scripts/build-pdf.sh <path-to-markdown>
```

The Python builder resolves its asset paths relative to its own location (`Path(__file__).resolve().parent.parent.parent` → `_shared/` → `assets/doc-style.css`, `assets/mermaid-config.json`), so the scripts are position-independent within `_shared/` but cannot be moved out of `_shared/scripts/python/` without an update to `md_to_pdf.py`.

## Style enforcement — single source of truth

Every PDF this repo produces uses the same:

- A4 page, 2 cm × 1.25 cm margins
- Helvetica throughout, 11 pt body / 8.5 pt tables
- Dark-navy headers with white text, zebra rows
- Page numbers bottom-right
- Default Mermaid theme + Helvetica via `mermaid-config.json`

There are **no per-skill stylesheets**. If a skill genuinely needs a one-off visual override (the OWASP skill's *Risk Status Board* fixed risk palette is the one current example), the override is codified inside the skill's content (Mermaid `classDef` in the markdown) — not by patching `doc-style.css` or shipping a duplicate. If a change to the house style is genuinely needed, edit `assets/doc-style.css` here and every skill benefits.

## What does NOT live here

- **Skill-specific scripts** (`find-manual-flows.sh`, `find-modules.sh`, `scan-codebase.sh`) — each lives with its owning skill.
- **Skill-specific reference docs** (`OUTPUT-STRUCTURE.md` per skill, plus `STYLE-GUIDE.md` and `LESSONS-LEARNED.md` which currently have skill-specific content even though they overlap on shared-pipeline lessons).
- **Templates** — each skill owns its template under `<skill>/templates/`.
- **Per-run output** — outputs always live alongside the user-supplied input data, never inside `.claude/lib/`.
