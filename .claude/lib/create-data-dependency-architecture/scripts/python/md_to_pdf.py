#!/usr/bin/env python3
"""Build a PDF from a Markdown file, pre-rendering ```mermaid blocks to PNG.

Usage:
    md_to_pdf.py <input.md> [output.pdf]

Pipeline:
    1. Parse YAML front-matter (if any) for title / subtitle / author.
       If no YAML title is present, fall back to the first leading # H1.
    2. Find each ```mermaid ... ``` fenced block, render to PNG via `mmdc`
       using the house Mermaid config (<skill>/assets/mermaid-config.json),
       and substitute the block with a Markdown image reference.
    3. Run `pandoc --wrap=none --pdf-engine=weasyprint` against the
       rewritten markdown, with the house stylesheet
       (<skill>/assets/doc-style.css) applied.

`--wrap=none` is required: pandoc's HTML5 writer otherwise inserts newlines
inside long text content (including SVG <text> nodes), which weasyprint
collapses into missing inter-word spaces in the rendered output.

PNGs and the rewritten build markdown are placed in a sibling
`<input_stem>.assets/` folder so they live alongside the source markdown
and can be inspected if a render looks wrong.

Dependencies on PATH:
    - mmdc       (npm install -g @mermaid-js/mermaid-cli)
    - pandoc
    - weasyprint
"""

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path


# Skill layout: this script lives at <skill>/scripts/python/md_to_pdf.py, with
# style and mermaid config at <skill>/assets/. Three .parent hops resolve to
# the skill root.
SKILL_ROOT = Path(__file__).resolve().parent.parent.parent
ASSETS = SKILL_ROOT / "assets"
DOC_CSS = ASSETS / "doc-style.css"
MERMAID_CONFIG = ASSETS / "mermaid-config.json"

MERMAID_PATTERN = re.compile(r"^```mermaid\n(.*?)\n```", re.DOTALL | re.MULTILINE)
YAML_FM_PATTERN = re.compile(r"^---\n(.*?)\n---\n", re.DOTALL)


def has_yaml_title(src: str) -> bool:
    m = YAML_FM_PATTERN.match(src)
    if not m:
        return False
    return any(line.lstrip().startswith("title:") for line in m.group(1).splitlines())


def extract_h1_title(src: str) -> tuple[str | None, str]:
    """Return (title, body_with_h1_stripped) — only strips the *first* H1
    if it appears before any other content. If no leading H1 is present,
    returns (None, src) unchanged."""
    lines = src.splitlines(keepends=True)
    for i, line in enumerate(lines):
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("# ") and not stripped.startswith("## "):
            title = stripped[2:].strip()
            # Drop the H1 line and one trailing blank line if present.
            j = i + 1
            if j < len(lines) and lines[j].strip() == "":
                j += 1
            return title, "".join(lines[:i] + lines[j:])
        return None, src
    return None, src


def render_mermaid(mmd_text: str, out_png: Path) -> None:
    out_png.parent.mkdir(parents=True, exist_ok=True)
    mmd_path = out_png.with_suffix(".mmd")
    mmd_path.write_text(mmd_text)
    cmd = [
        "mmdc",
        "-i", str(mmd_path),
        "-o", str(out_png),
        "-b", "white",
        "-s", "2",
        "--quiet",
    ]
    if MERMAID_CONFIG.exists():
        cmd += ["--configFile", str(MERMAID_CONFIG)]
    subprocess.run(cmd, check=True)


def build(input_md: Path, output_pdf: Path | None = None) -> Path:
    input_md = input_md.resolve()
    if output_pdf is None:
        output_pdf = input_md.with_suffix(".pdf")
    else:
        output_pdf = output_pdf.resolve()

    src = input_md.read_text()

    fallback_title: str | None = None
    if not has_yaml_title(src):
        fallback_title, src = extract_h1_title(src)

    assets_dir = input_md.parent / f"{input_md.stem}.assets"
    if assets_dir.exists():
        shutil.rmtree(assets_dir)
    assets_dir.mkdir(parents=True, exist_ok=True)

    rewritten: list[str] = []
    last = 0
    diagram_idx = 0
    for m in MERMAID_PATTERN.finditer(src):
        rewritten.append(src[last:m.start()])
        diagram_idx += 1
        png_path = assets_dir / f"diagram-{diagram_idx}.png"
        render_mermaid(m.group(1), png_path)
        rel = png_path.relative_to(input_md.parent)
        rewritten.append(f"![Diagram {diagram_idx}]({rel})\n")
        last = m.end()
    rewritten.append(src[last:])

    work_md = assets_dir / "build.md"
    work_md.write_text("".join(rewritten))

    pandoc_cmd = [
        "pandoc",
        str(work_md),
        "--wrap=none",
        "--standalone",
        "-o", str(output_pdf),
        "--pdf-engine=weasyprint",
        "-V", "geometry:A4",
        "-V", "geometry:margin=2cm",
        "--resource-path", str(input_md.parent),
    ]
    if fallback_title:
        pandoc_cmd += ["--metadata", f"title={fallback_title}"]
    if DOC_CSS.exists():
        pandoc_cmd += ["--css", str(DOC_CSS)]

    subprocess.run(pandoc_cmd, check=True)

    return output_pdf


def main() -> int:
    parser = argparse.ArgumentParser(description="Render a Markdown file with mermaid blocks to PDF using the house style.")
    parser.add_argument("input", type=Path, help="Path to the input .md file")
    parser.add_argument("output", type=Path, nargs="?", help="Optional output .pdf path")
    args = parser.parse_args()

    if not args.input.exists():
        print(f"error: input file not found: {args.input}", file=sys.stderr)
        return 1

    out = build(args.input, args.output)
    print(f"PDF: {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
