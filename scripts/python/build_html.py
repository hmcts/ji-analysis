#!/usr/bin/env python3
"""Build a static HTML view of the NJI planning artefacts.

Reads markdown from `_bmad-output/planning-artifacts/` and writes HTML to `html/`
at the repo root. Mirrors the source directory structure. Rewrites `.md` links
to `.html`. Copies images, PDFs, dot, and mmd files alongside. Generates an
index page and a sidebar navigation present on every page.

Requirements: pandoc on PATH. No third-party Python dependencies.

Run via the shell wrapper `scripts/build-html.sh` from any working directory.
"""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import List, Tuple

REPO_ROOT = Path(__file__).resolve().parents[2]
SRC = REPO_ROOT / "_bmad-output" / "planning-artifacts"
OUT = REPO_ROOT / "html"

# Sidebar navigation. Each entry: (display label, source path without .md, is_special)
# is_special marks entries that have no source file (e.g. the index page).
NAV: List[Tuple[str, List[Tuple[str, str, bool]]]] = [
    ("Overview", [
        ("Index", "index", True),
    ]),
    ("Product", [
        ("PRD", "prd", False),
    ]),
    ("Architecture", [
        ("Architecture (index)", "architecture", False),
        ("Architecture summary", "architecture-summary", False),
    ]),
    ("Architecture — Reference", [
        ("Authoritative table ownership", "architecture/data-tables", False),
        ("Conventions", "architecture/conventions", False),
        ("Repository strategy", "architecture/repository-strategy", False),
        ("Repository structure", "architecture/repo-structure", False),
        ("Starter template", "architecture/starter-template", False),
        ("Functional requirements coverage", "architecture/functional-requirements-coverage", False),
        ("Non-functional requirements coverage", "architecture/non-functional-requirements-coverage", False),
    ]),
    ("Sequence Diagrams", [
        ("Authentication & authorisation", "architecture/sequence-diagrams/user-authentication-and-authorisation", False),
        ("Judge onboarding & sitting gen.", "architecture/sequence-diagrams/judge-onboarding-and-sitting-generation", False),
        ("Absence → Reconciliation", "architecture/sequence-diagrams/absence-to-reconciliation", False),
        ("Salaried sitting confirmation", "architecture/sequence-diagrams/salaried-sitting-confirmation", False),
        ("Payment batch flow", "architecture/sequence-diagrams/payment-batch-flow", False),
        ("Itinerary federated read", "architecture/sequence-diagrams/itinerary-federated-read", False),
        ("MI Feed & Reports", "architecture/sequence-diagrams/mi-feed-and-reports-consumption", False),
        ("Admin maintenance flows", "architecture/sequence-diagrams/admin-maintenance-flows", False),
    ]),
    ("Open Items", [
        ("Gaps", "architecture/gaps", False),
        ("Assumptions", "architecture/assumptions", False),
        ("Changelog", "architecture/changelog", False),
    ]),
    ("Implementation Readiness", [
        ("Report — 2026-05-06 (current)", "implementation-readiness-report-2026-05-06", False),
        ("Report — 2026-05-05 (historical)", "implementation-readiness-report-2026-05-05", False),
    ]),
    ("Implementation", [
        ("Epics & Stories", "epics", False),
    ]),
]

FRONTMATTER_RE = re.compile(r"\A---\n.*?\n---\n", re.DOTALL)
MD_LINK_RE = re.compile(r"(\]\()([^)]+?)(\.md)(#[^)]+)?(\))")

CSS = """
*{box-sizing:border-box}
body{margin:0;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif;color:#1f2328;line-height:1.55;background:#fff}
aside.nav{position:fixed;top:0;left:0;width:280px;height:100vh;overflow-y:auto;background:#f6f8fa;border-right:1px solid #d0d7de;padding:16px 12px;font-size:14px}
aside.nav h2{font-size:14px;margin:0 0 12px;letter-spacing:.02em;text-transform:uppercase;color:#57606a}
aside.nav h2 a{color:inherit;text-decoration:none}
aside.nav h3{font-size:11px;margin:14px 0 4px;color:#57606a;text-transform:uppercase;letter-spacing:.06em;font-weight:600}
aside.nav ul{list-style:none;margin:0;padding:0}
aside.nav li{margin:2px 0}
aside.nav a{color:#0969da;text-decoration:none;display:block;padding:4px 8px;border-radius:6px}
aside.nav a:hover{background:#eaeef2}
aside.nav a.current{background:#ddf4ff;font-weight:600;color:#0a3069}
main.content{margin-left:280px;max-width:1000px;padding:20px 40px 80px}
main h1,main h2,main h3,main h4{margin-top:24px;margin-bottom:8px;font-weight:600;line-height:1.25}
main h1{border-bottom:1px solid #d0d7de;padding-bottom:6px;font-size:1.9em}
main h2{border-bottom:1px solid #eaeef2;padding-bottom:4px;font-size:1.4em}
main h3{font-size:1.15em}
main p{margin:6px 0 14px}
main code{background:#eff1f3;padding:1px 4px;border-radius:3px;font-size:.92em;font-family:ui-monospace,SFMono-Regular,"SF Mono",Menlo,monospace}
main pre{background:#f6f8fa;padding:12px 14px;border-radius:6px;overflow-x:auto;font-size:.88em;line-height:1.45;border:1px solid #eaeef2}
main pre code{background:transparent;padding:0;font-size:1em}
main blockquote{border-left:3px solid #d0d7de;color:#57606a;margin:8px 0;padding:0 12px}
main table{border-collapse:collapse;margin:12px 0;font-size:.92em;display:block;overflow-x:auto;max-width:100%}
main th,main td{border:1px solid #d0d7de;padding:6px 10px;vertical-align:top;text-align:left}
main th{background:#f6f8fa;font-weight:600}
main tr:nth-child(2n){background:#fafbfc}
main img{max-width:100%;height:auto;border:1px solid #d0d7de;border-radius:4px;display:block;margin:8px 0}
main a{color:#0969da;text-decoration:none}
main a:hover{text-decoration:underline}
main ul,main ol{margin:6px 0 14px;padding-left:28px}
main li{margin:2px 0}
main hr{border:none;border-top:1px solid #d0d7de;margin:24px 0}
.breadcrumb{color:#57606a;font-size:13px;margin:0 0 16px}
.breadcrumb a{color:#0969da;text-decoration:none}
.source-note{margin-top:40px;padding-top:12px;border-top:1px solid #eaeef2;font-size:12px;color:#57606a}
.source-note a{color:#57606a;text-decoration:underline}
"""


def strip_frontmatter(md: str) -> str:
    return FRONTMATTER_RE.sub("", md, count=1)


def rewrite_md_links(md: str) -> str:
    """Rewrite `.md` link targets to `.html`, preserving fragments."""
    def repl(m: re.Match) -> str:
        before, path, _ext, frag, after = m.groups()
        return f"{before}{path}.html{frag or ''}{after}"
    return MD_LINK_RE.sub(repl, md)


def md_to_html_body(md_path: Path) -> str:
    src = md_path.read_text()
    src = strip_frontmatter(src)
    src = rewrite_md_links(src)
    result = subprocess.run(
        ["pandoc", "--from", "gfm", "--to", "html5", "--no-highlight"],
        input=src, capture_output=True, text=True, check=True,
    )
    return result.stdout


def extract_title(md_path: Path) -> str:
    text = strip_frontmatter(md_path.read_text())
    for line in text.splitlines():
        if line.startswith("# "):
            return line[2:].strip()
    return md_path.stem.replace("-", " ").title()


def nav_html(current_relpath: str, page_to_root: str) -> str:
    parts = [f'<h2><a href="{page_to_root}index.html">NJI Documentation</a></h2>']
    for group_name, items in NAV:
        parts.append(f"<h3>{group_name}</h3>")
        parts.append("<ul>")
        for label, relpath, _is_special in items:
            href = f"{page_to_root}{relpath}.html"
            cls = ' class="current"' if relpath == current_relpath else ""
            parts.append(f'<li><a href="{href}"{cls}>{label}</a></li>')
        parts.append("</ul>")
    return "\n".join(parts)


PAGE_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title} — NJI Documentation</title>
<style>{css}</style>
</head>
<body>
<aside class="nav">{nav}</aside>
<main class="content">
{content}
{source_note}
</main>
</body>
</html>
"""


def write_page(out_path: Path, title: str, content: str, current_relpath: str, source_md: Path | None) -> None:
    depth = current_relpath.count("/")
    page_to_root = "../" * depth if depth else "./"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    if source_md is not None:
        src_rel = source_md.relative_to(REPO_ROOT)
        source_note = f'<p class="source-note">Source: <code>{src_rel}</code></p>'
    else:
        source_note = ""
    html = PAGE_TEMPLATE.format(
        title=title,
        css=CSS,
        nav=nav_html(current_relpath, page_to_root),
        content=content,
        source_note=source_note,
    )
    out_path.write_text(html)


def build_index_body() -> str:
    parts = ["<h1>NJI Documentation</h1>"]
    parts.append(
        "<p>HTML rendering of the NJI planning artefacts. "
        "The sidebar is available on every page for quick navigation.</p>"
    )
    for group_name, items in NAV:
        parts.append(f"<h2>{group_name}</h2>")
        parts.append("<ul>")
        for label, relpath, is_special in items:
            if is_special:
                continue
            parts.append(f'<li><a href="{relpath}.html">{label}</a></li>')
        parts.append("</ul>")
    return "\n".join(parts)


def main() -> int:
    if not SRC.exists():
        print(f"error: source directory not found: {SRC}", file=sys.stderr)
        return 1
    if shutil.which("pandoc") is None:
        print("error: pandoc not found on PATH", file=sys.stderr)
        return 1

    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)

    # convert markdown files
    md_files = sorted(SRC.rglob("*.md"))
    for src_md in md_files:
        rel = src_md.relative_to(SRC).with_suffix("")
        relpath_str = str(rel)
        title = extract_title(src_md)
        body = md_to_html_body(src_md)
        out_path = OUT / (relpath_str + ".html")
        write_page(out_path, title, body, relpath_str, src_md)
        print(f"build: {relpath_str}.html")

    # copy non-markdown assets (skip OS junk)
    skip_names = {".DS_Store", "Thumbs.db"}
    for src_file in sorted(SRC.rglob("*")):
        if not src_file.is_file() or src_file.suffix == ".md":
            continue
        if src_file.name in skip_names:
            continue
        rel = src_file.relative_to(SRC)
        dst = OUT / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src_file, dst)
        print(f"copy:  {rel}")

    # write index page
    write_page(OUT / "index.html", "NJI Documentation", build_index_body(), "index", None)
    print("build: index.html")

    print(f"\nDone. Output: {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
