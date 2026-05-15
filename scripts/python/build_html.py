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
ASIS_SRC = REPO_ROOT / "docs" / "architecture" / "asis"
OUT = REPO_ROOT / "html"

# As-is architecture views generated from PNGs in docs/architecture/asis/.
# Each entry: (display title, intro paragraph, source PNG filename, output relpath without .html)
ASIS_VIEWS: List[Tuple[str, str, str, str]] = [
    (
        "System Context — as-is JI",
        "High-level system context view of the legacy JI (Oracle APEX / OPT) application — actors, "
        "external systems, and integrations as they exist before the NJI rebuild. Authoritative "
        "source for system-context parity validation during NJI design. "
        "Revised version: Finance and Payment Authoriser are shown as separate roles; eLinks, "
        "HR / Administrative Records and HMCTS Email have been removed (the first two are not "
        "real integrations, the third is pure SMTP transport and is now annotated on the edges). "
        "Interactions are numbered sequentially.",
        "JI-SystemContext2.png",
        "asis/system-context",
    ),
    (
        "Components — as-is JI",
        "Component view of the legacy JI application — internal modules and their relationships in "
        "the existing APEX implementation. Used as the parity reference for the NJI functional "
        "decomposition into 11 services.",
        "JI-Components.png",
        "asis/components",
    ),
]

# Sidebar navigation. Each entry: (display label, source path without .md, is_special)
# is_special marks entries that have no source file (e.g. the index page).
# Group naming convention: "As-is — …" for legacy JI; "To-be — …" for NJI.
NAV: List[Tuple[str, List[Tuple[str, str, bool]]]] = [
    ("Overview", [
        ("Index", "index", True),
    ]),
    ("Product", [
        ("PRD (NJI)", "prd", False),
    ]),
    ("As-is — JI Architecture Views", [
        ("System Context (as-is)", "asis/system-context", False),
        ("Components (as-is)", "asis/components", False),
    ]),
    ("To-be — NJI Architecture", [
        ("Architecture (index)", "architecture", False),
        ("Architecture summary", "architecture-summary", False),
    ]),
    ("To-be — NJI Reference", [
        ("User types", "architecture/user-types", False),
        ("Authoritative table ownership", "architecture/data-tables", False),
        ("Conventions", "architecture/conventions", False),
        ("Repository strategy", "architecture/repository-strategy", False),
        ("Repository structure", "architecture/repo-structure", False),
        ("Starter template", "architecture/starter-template", False),
        ("Functional requirements coverage", "architecture/functional-requirements-coverage", False),
        ("Non-functional requirements coverage", "architecture/non-functional-requirements-coverage", False),
    ]),
    ("To-be — NJI Sequence Diagrams", [
        ("Authentication & authorisation", "architecture/sequence-diagrams/user-authentication-and-authorisation", False),
        ("Judge onboarding & sitting gen.", "architecture/sequence-diagrams/judge-onboarding-and-sitting-generation", False),
        ("Absence → Reconciliation", "architecture/sequence-diagrams/absence-to-reconciliation", False),
        ("Salaried sitting confirmation", "architecture/sequence-diagrams/salaried-sitting-confirmation", False),
        ("Payment batch flow", "architecture/sequence-diagrams/payment-batch-flow", False),
        ("Itinerary federated read", "architecture/sequence-diagrams/itinerary-federated-read", False),
        ("MI Feed & Reports", "architecture/sequence-diagrams/mi-feed-and-reports-consumption", False),
        ("Admin maintenance flows", "architecture/sequence-diagrams/admin-maintenance-flows", False),
    ]),
    ("To-be — NJI Open Items", [
        ("Gaps", "architecture/gaps", False),
        ("Assumptions", "architecture/assumptions", False),
        ("Changelog", "architecture/changelog", False),
    ]),
    ("Implementation Readiness", [
        ("Report — 2026-05-15 (current)", "implementation-readiness-report-2026-05-15", False),
        ("Report — 2026-05-06 (historical)", "implementation-readiness-report-2026-05-06", False),
        ("Report — 2026-05-05 (historical)", "implementation-readiness-report-2026-05-05", False),
    ]),
    ("Implementation — Epics (Foundations)", [
        ("Epics index", "epics/index", False),
        ("Requirements inventory", "epics/requirements-inventory", False),
        ("Phase × Area framework", "epics/framework", False),
        ("FR coverage map", "epics/fr-coverage-map", False),
    ]),
    ("Implementation — Phase 0 ✓", [
        ("Phase 0 overview", "epics/phase-0/index", False),
        ("Epic 0.1 — User authenticates", "epics/phase-0/epic-0.1-user-authenticates", False),
        ("Epic 0.2 — Reference Data", "epics/phase-0/epic-0.2-admin-manages-ref-data", False),
        ("Epic 0.3 — Users, Roles, Activation", "epics/phase-0/epic-0.3-admin-manages-users-roles", False),
        ("Epic 0.4 — Transactional Emails", "epics/phase-0/epic-0.4-system-dispatches-emails", False),
        ("Phase 0 Validation Report", "epics/phase-0/validation-report-2026-05-15", False),
    ]),
]

FRONTMATTER_RE = re.compile(r"\A---\n.*?\n---\n", re.DOTALL)
MD_LINK_RE = re.compile(r"(\]\()([^)]+?)(\.md)(#[^)]+)?(\))")
HEADING_RE = re.compile(r'<h([23])\s+id="([^"]+)">(.*?)</h\1>', re.DOTALL)
H2_SECTION_RE = re.compile(r'<h2\s+id="([^"]+)">(.*?)</h2>', re.DOTALL)
TAG_RE = re.compile(r"<[^>]+>")

# Show in-page TOC and wrap H2 sections in <details> when a page has at least
# this many H2 headings. Short pages don't benefit from progressive disclosure.
TOC_THRESHOLD = 3

CSS = """
*{box-sizing:border-box}
html{scroll-behavior:smooth;scroll-padding-top:16px}
body{margin:0;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif;color:#1f2328;line-height:1.55;background:#fff}
aside.nav{position:fixed;top:0;left:0;width:280px;height:100vh;overflow-y:auto;background:#f6f8fa;border-right:1px solid #d0d7de;padding:16px 12px;font-size:14px}
aside.nav h2.site-title{font-size:14px;margin:0 0 12px;letter-spacing:.02em;text-transform:uppercase;color:#57606a}
aside.nav h2.site-title a{color:inherit;text-decoration:none}
aside.nav details.nav-group{margin:2px 0;border-radius:5px}
aside.nav details.nav-group>summary{font-size:11px;padding:5px 8px 5px 4px;cursor:pointer;color:#57606a;text-transform:uppercase;letter-spacing:.06em;font-weight:600;border-radius:4px;list-style:none;user-select:none;display:flex;align-items:center;gap:6px}
aside.nav details.nav-group>summary::-webkit-details-marker{display:none}
aside.nav details.nav-group>summary::before{content:'▸';display:inline-block;font-size:9px;color:#8c959f;transition:transform 0.15s ease;flex:0 0 10px;text-align:center}
aside.nav details.nav-group[open]>summary::before{transform:rotate(90deg)}
aside.nav details.nav-group>summary:hover{background:#eaeef2;color:#1f2328}
aside.nav details.nav-group ul{list-style:none;margin:2px 0 6px;padding:0 0 0 16px}
aside.nav details.nav-group li{margin:1px 0}
aside.nav details.nav-group a{color:#0969da;text-decoration:none;display:block;padding:3px 8px;border-radius:6px;font-size:13px}
aside.nav details.nav-group a:hover{background:#eaeef2}
aside.nav details.nav-group a.current{background:#ddf4ff;font-weight:600;color:#0a3069}
.nav-controls{margin:0 0 10px;font-size:11px}
.nav-controls button{background:none;border:none;color:#0969da;cursor:pointer;padding:2px 4px;font-size:inherit;font-family:inherit;text-decoration:underline}
.nav-controls button:hover{color:#0a3069}
aside.toc{position:fixed;top:0;right:0;width:240px;height:100vh;overflow-y:auto;background:#fbfbfc;border-left:1px solid #eaeef2;padding:20px 14px;font-size:13px}
aside.toc h4{font-size:11px;margin:0 0 8px;color:#57606a;text-transform:uppercase;letter-spacing:.06em;font-weight:600}
aside.toc ul{list-style:none;margin:0;padding:0}
aside.toc li{margin:1px 0}
aside.toc li.h3{padding-left:14px;font-size:12px}
aside.toc a{color:#57606a;text-decoration:none;display:block;padding:3px 8px;border-radius:4px;line-height:1.35;border-left:2px solid transparent}
aside.toc a:hover{background:#eaeef2;color:#0a3069}
main.content{margin-left:280px;max-width:1000px;padding:20px 40px 80px}
body.has-toc main.content{margin-right:240px}
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
main details.section{border:1px solid #d0d7de;border-radius:6px;margin:14px 0;background:#fff;overflow:hidden}
main details.section>summary{cursor:pointer;padding:10px 14px;background:#f6f8fa;list-style:none;user-select:none;display:flex;align-items:center;gap:10px;color:#1f2328;border-radius:5px}
main details.section[open]>summary{border-bottom:1px solid #d0d7de;border-radius:5px 5px 0 0}
main details.section>summary::-webkit-details-marker{display:none}
main details.section>summary::before{content:'▸';display:inline-block;font-size:11px;color:#57606a;transition:transform 0.15s ease;flex:0 0 12px;text-align:center}
main details.section[open]>summary::before{transform:rotate(90deg)}
main details.section>summary:hover{background:#eaeef2}
main details.section>summary .section-title{font-size:1.15em;font-weight:600;line-height:1.3}
main details.section>summary .section-title code{font-size:.95em}
main .section-body{padding:14px 18px 18px}
main .section-body>h3:first-child,main .section-body>p:first-child,main .section-body>ul:first-child{margin-top:6px}
.section-controls{margin:6px 0 18px;display:flex;gap:14px;font-size:13px;align-items:center}
.section-controls .label{color:#57606a;font-size:12px}
.section-controls button{background:none;border:1px solid #d0d7de;color:#0969da;cursor:pointer;padding:3px 10px;font-size:13px;font-family:inherit;border-radius:5px}
.section-controls button:hover{background:#eaeef2;color:#0a3069}
.breadcrumb{color:#57606a;font-size:13px;margin:0 0 16px}
.breadcrumb a{color:#0969da;text-decoration:none}
.source-note{margin-top:40px;padding-top:12px;border-top:1px solid #eaeef2;font-size:12px;color:#57606a}
.source-note a{color:#57606a;text-decoration:underline}
@media (max-width: 1200px){
  aside.toc{display:none}
  body.has-toc main.content{margin-right:0}
}
"""

INLINE_JS = """
(function(){
  // 1. Sidebar accordion: persist user's group open/close preference per group.
  //    The current page's group is always open on load (regardless of stored state).
  document.querySelectorAll('aside.nav details.nav-group').forEach(function(d){
    var key = 'nav-group-' + d.dataset.group;
    if (d.dataset.current !== 'true') {
      var stored = localStorage.getItem(key);
      if (stored === 'open') d.open = true;
      else if (stored === 'closed') d.open = false;
    }
    d.addEventListener('toggle', function(){
      localStorage.setItem(key, d.open ? 'open' : 'closed');
    });
  });

  // 2. Expand all / Collapse all (sidebar)
  document.querySelectorAll('button[data-nav-action]').forEach(function(b){
    b.addEventListener('click', function(){
      var open = b.dataset.navAction === 'expand';
      document.querySelectorAll('aside.nav details.nav-group').forEach(function(d){ d.open = open; });
    });
  });

  // 3. When a fragment link points to a heading inside a collapsed <details>,
  //    open all ancestor <details> elements so the target is visible.
  function openAncestors(id){
    if (!id) return;
    var el = document.getElementById(id);
    if (!el) return;
    if (el.tagName === 'DETAILS') el.open = true;
    var cur = el.parentElement;
    while (cur) {
      if (cur.tagName === 'DETAILS') cur.open = true;
      cur = cur.parentElement;
    }
    setTimeout(function(){
      try { el.scrollIntoView({block: 'start', behavior: 'smooth'}); } catch (e) {}
    }, 60);
  }
  if (window.location.hash) {
    openAncestors(window.location.hash.slice(1));
  }
  window.addEventListener('hashchange', function(){
    openAncestors(window.location.hash.slice(1));
  });
  document.addEventListener('click', function(e){
    var a = e.target.closest('a[href^="#"]');
    if (!a) return;
    var href = a.getAttribute('href');
    if (!href || href.length < 2) return;
    setTimeout(function(){ openAncestors(href.slice(1)); }, 10);
  });

  // 4. Expand all / Collapse all (content sections)
  document.querySelectorAll('button[data-section-action]').forEach(function(b){
    b.addEventListener('click', function(){
      var open = b.dataset.sectionAction === 'expand';
      document.querySelectorAll('main.content details.section').forEach(function(d){ d.open = open; });
    });
  });
})();
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


def build_inpage_toc(body_html: str) -> str:
    """Build a right-side in-page TOC from H2/H3 headings.

    Returns empty string when the page has fewer than TOC_THRESHOLD H2 headings —
    short pages don't benefit from an in-page TOC.
    """
    headings = HEADING_RE.findall(body_html)
    h2_count = sum(1 for level, _, _ in headings if level == "2")
    if h2_count < TOC_THRESHOLD:
        return ""
    items = []
    for level, slug, inner in headings:
        text = TAG_RE.sub("", inner).strip()
        cls = ' class="h3"' if level == "3" else ""
        items.append(f'<li{cls}><a href="#{slug}">{text}</a></li>')
    return '<aside class="toc"><h4>On this page</h4><ul>' + "".join(items) + "</ul></aside>"


def slugify_group(group_name: str) -> str:
    """Stable group key for localStorage and data-group attributes."""
    return re.sub(r"[^a-z0-9]+", "-", group_name.lower()).strip("-")


def nav_html(current_relpath: str, page_to_root: str) -> str:
    parts = [f'<h2 class="site-title"><a href="{page_to_root}index.html">NJI Documentation</a></h2>']
    parts.append(
        '<div class="nav-controls">'
        '<button data-nav-action="expand" title="Expand all groups">Expand all</button> '
        '<button data-nav-action="collapse" title="Collapse all groups">Collapse all</button>'
        '</div>'
    )
    for group_name, items in NAV:
        is_current_group = any(relpath == current_relpath for _label, relpath, _is_special in items)
        open_attr = " open" if is_current_group else ""
        current_attr = ' data-current="true"' if is_current_group else ""
        group_key = slugify_group(group_name)
        parts.append(
            f'<details class="nav-group" data-group="{group_key}"{current_attr}{open_attr}>'
        )
        parts.append(f"<summary>{group_name}</summary>")
        parts.append("<ul>")
        for label, relpath, _is_special in items:
            href = f"{page_to_root}{relpath}.html"
            cls = ' class="current"' if relpath == current_relpath else ""
            parts.append(f'<li><a href="{href}"{cls}>{label}</a></li>')
        parts.append("</ul>")
        parts.append("</details>")
    return "\n".join(parts)


def wrap_h2_sections(body_html: str) -> Tuple[str, bool]:
    """Wrap each H2 + its following content in a <details> accordion.

    Content above the first H2 stays visible (preamble). Returns the transformed
    HTML and a flag indicating whether any sections were wrapped (used by the
    page template to show the expand-all controls).

    Pages with fewer than TOC_THRESHOLD H2 headings are returned unchanged: the
    overhead of collapsing 1–2 sections is worse than the linear scan.
    """
    parts = H2_SECTION_RE.split(body_html)
    h2_count = (len(parts) - 1) // 3 if len(parts) > 1 else 0
    if h2_count < TOC_THRESHOLD:
        return body_html, False

    out = [parts[0]]  # preamble: everything before the first H2
    for i in range(1, len(parts), 3):
        sec_id = parts[i]
        sec_title_html = parts[i + 1]
        sec_content = parts[i + 2] if i + 2 < len(parts) else ""
        out.append(
            f'<details class="section" id="{sec_id}">'
            f'<summary><span class="section-title">{sec_title_html}</span></summary>'
            f'<div class="section-body">{sec_content}</div>'
            f'</details>'
        )
    return "".join(out), True


PAGE_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title} — NJI Documentation</title>
<style>{css}</style>
</head>
<body class="{body_class}">
<aside class="nav">{nav}</aside>
<main class="content">
{section_controls}
{content}
{source_note}
</main>
{toc}
<script>{js}</script>
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

    # Build right-side in-page TOC from the original H2/H3 headings BEFORE we wrap
    # H2s into <details> — TOC anchor targets remain stable (id is preserved on the
    # <details> element).
    toc = build_inpage_toc(content)

    # Wrap H2 sections in <details>. Pages with <3 H2s are returned unchanged.
    content, has_sections = wrap_h2_sections(content)
    if has_sections:
        section_controls = (
            '<div class="section-controls">'
            '<span class="label">Sections:</span>'
            '<button data-section-action="expand">Expand all</button>'
            '<button data-section-action="collapse">Collapse all</button>'
            '</div>'
        )
    else:
        section_controls = ""

    body_class = " ".join(c for c in ["has-toc" if toc else "", "has-sections" if has_sections else ""] if c)

    html = PAGE_TEMPLATE.format(
        title=title,
        css=CSS,
        js=INLINE_JS,
        nav=nav_html(current_relpath, page_to_root),
        section_controls=section_controls,
        content=content,
        source_note=source_note,
        toc=toc,
        body_class=body_class,
    )
    out_path.write_text(html)


def build_index_body() -> str:
    parts = ["<h1>JI / NJI Documentation</h1>"]
    parts.append(
        "<p>HTML rendering of the JI / NJI planning artefacts. The sidebar — available on every page — "
        "is organised so it is clear what belongs to the legacy <strong>as-is</strong> JI and what "
        "belongs to the <strong>to-be</strong> NJI rebuild.</p>"
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


def build_asis_views() -> None:
    """Generate HTML wrapper pages for as-is architecture PNG views.

    Copies each source PNG from docs/architecture/asis/ into html/asis/ and wraps it in an
    HTML page using the standard sidebar template, so the views are first-class documents
    in the site rather than raw images.
    """
    if not ASIS_SRC.exists():
        print(f"warn: as-is source not found: {ASIS_SRC} — skipping as-is views", file=sys.stderr)
        return
    for title, intro, source_png, out_relpath in ASIS_VIEWS:
        src_png = ASIS_SRC / source_png
        if not src_png.exists():
            print(f"warn: as-is view source not found: {src_png} — skipping", file=sys.stderr)
            continue
        # copy PNG next to the generated HTML
        dst_png = OUT / (out_relpath + ".png")
        dst_png.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src_png, dst_png)
        print(f"copy:  {out_relpath}.png  (from {src_png.relative_to(REPO_ROOT)})")
        # generate wrapper page
        png_name = Path(out_relpath).name + ".png"
        body = (
            f"<h1>{title}</h1>\n"
            f"<p>{intro}</p>\n"
            f'<img src="./{png_name}" alt="{title}">\n'
        )
        out_html = OUT / (out_relpath + ".html")
        write_page(out_html, title, body, out_relpath, src_png)
        print(f"build: {out_relpath}.html")


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

    # generate as-is architecture view pages from docs/architecture/asis/
    build_asis_views()

    # write index page
    write_page(OUT / "index.html", "JI / NJI Documentation", build_index_body(), "index", None)
    print("build: index.html")

    print(f"\nDone. Output: {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
