#!/usr/bin/env python3
"""Build schema diagrams (Graphviz DOT → PNG) from the parsed JI DDL.

Pipeline:
  1. Load `ji_schema.json` (produced by `parse_ji_ddl.py`).
  2. Backfill missing PKs from unique indexes named `*_PK`.
  3. Build PK→owner map; infer FK relationships from column-name conventions
     with HIGH / MEDIUM / LOW confidence.
  4. Assign each TBL_* table to a domain cluster.
  5. Emit one overview DOT (clustered table names + relationships) and one
     detail DOT per cluster (full columns + PK/FK/UK markers + trigger badges).
  6. Render each DOT to PNG via `dot`.

Exclusions:
  - TMP_* tables are NOT shown (per user direction).
  - Foreign keys are ALL inferred — no explicit FK constraints exist in the
    source DDL. Confidence is encoded in edge style (solid / dashed / dotted).

Output goes to `docs/architecture/asis/database/`.
"""
from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Set, Tuple

REPO_ROOT = Path(__file__).resolve().parents[2]
DB_DIR = REPO_ROOT / "docs" / "architecture" / "asis" / "database"
SCHEMA_JSON = DB_DIR / "ji_schema.json"

# ---------------------------------------------------------------------------
# Domain clustering
# ---------------------------------------------------------------------------
# Each cluster: (cluster_key, display_label, list_of_table_names, palette_color)
# Palette colors are soft pastels distinct from each other.

CLUSTERS: List[Tuple[str, str, List[str], str]] = [
    (
        "judges-profile",
        "Judges Profile & Reference",
        [
            "TBL_JUDGES",
            "TBL_JUDGES_MASTER",
            "TBL_JUDGES_USER_LINKS",
            "TBL_JUDGE_TYPES",
            "TBL_JUDGE_STATUSES",
            "TBL_JUDGE_CIRCUITS",
            "TBL_LEADERSHIP_JUDGE_TYPES",
            "TBL_JUDGE_TYPE_PROMOTION",
        ],
        "#E3F2FD",  # light blue
    ),
    (
        "judges-patterns",
        "Working Patterns, Tickets & Stats",
        [
            "TBL_JUDGES_WORK_PATTERNS",
            "TBL_JUDGES_WP_DETAIL",
            "TBL_JUDGES_JURIS_SPLIT",
            "TBL_JUDGE_JURIS",
            "TBL_JUDGE_TICKET_TYPES",
            "TBL_JUDGES_TICKETS",
            "TBL_JUDGE_COURTS_LINK",
            "TBL_JUDGE_FEE_RATES",
            "TBL_JUDGES_ANNUAL_LEAVE",
            "TBL_JUDGES_BOOKING_STATS",
            "TBL_JUDGES_MONTHLY_STATS",
        ],
        "#E8F5E9",  # light green
    ),
    (
        "absence-cover",
        "Absence & Cover Workflow",
        [
            "TBL_JI_ABS_OB",
            "TBL_JI_ABS_OB_DETAIL",
            "TBL_JI_ABS_OB_CATS",
            "TBL_JI_ABS_OB_TYPES",
            "TBL_JI_ABS_OB_VAC_OPTS",
            "TBL_JI_VACANCIES",
            "TBL_JI_VACANCY_GROUPS",
            "TBL_JI_VAC_CANCEL_REASONS",
        ],
        "#FFF3E0",  # light orange
    ),
    (
        "bookings-sittings",
        "Bookings & Sittings",
        [
            "TBL_JI_FP_BOOKINGS",
            "TBL_JI_FP_BOOKING_DETAIL",
            "TBL_JI_FP_BOOKING_TYPES",
            "TBL_JI_FP_CANCELLERS",
            "TBL_JI_PLANNED_SITTINGS",
        ],
        "#FCE4EC",  # light pink
    ),
    (
        "reference-work",
        "Reference Data — Work, Durations, Areas, Links",
        [
            "TBL_JI_PLANNED_WORK_TYPES",
            "TBL_JI_PLANNED_WORK_CATS",
            "TBL_JI_ACTUAL_WORK_TYPES",
            "TBL_JI_ACTUAL_WORK_CATS",
            "TBL_JI_SITTING_DURS",
            "TBL_JI_AREAS",
            "TBL_JI_EXTRA_NWDS",
            "TBL_JI_LOC_JT_AWD_LINKS",
            "TBL_JI_LOC_JT_PWD_LINKS",
            "TBL_JI_LOC_JT_SD_LINKS",
            "TBL_JI_UA_JT_LINKS",
        ],
        "#F3E5F5",  # light purple
    ),
    (
        "audit-cross-cutting",
        "Audit & Cross-cutting",
        [
            "TBL_JI_CHANGES",
            "TBL_JI_CHANGE_TYPES",
            "TBL_JI_RESTR_ITIN_USERS",
        ],
        "#FFFDE7",  # light yellow
    ),
]

# ---------------------------------------------------------------------------
# External-reference column hints
# ---------------------------------------------------------------------------
# Columns that almost certainly refer to tables NOT in this PDF. These get a
# special "External" marker in the diagram and are documented separately.

EXTERNAL_REF_HINTS: Dict[str, str] = {
    "LOC_ID": "External: LOCATIONS / OFFICES (not in this PDF)",
    "LOC_TYPE_ID": "External: LOCATION TYPES (not in this PDF)",
    "BASE_LOC_ID": "External: LOCATIONS (not in this PDF)",
    "BASE_LOC_TYPE_ID": "External: LOCATION TYPES (not in this PDF)",
    "HEARING_LOC_ID": "External: LOCATIONS (not in this PDF)",
    "HEARING_LOC_TYPE_ID": "External: LOCATION TYPES (not in this PDF)",
    "REGION_ID": "External: REGIONS (not in this PDF)",
    "CUT_COURTROOM_ID": "External: COURTROOMS / CUT_* (not in this PDF)",
    "CUT_OWNER_ID": "External: COURTROOMS / CUT_* (not in this PDF)",
    "COURT_ID": "External: COURTS (not in this PDF)",
    "HMCS_LEGAL_TIER_CODE": "External: HMCS Legal Tier codes (not in this PDF)",
    "FP_STATUS_ID": "External: FP Status lookup (not in this PDF)",
    "LONDON_WT_STATUS_ID": "External: London Weighting Status lookup (not in this PDF)",
    "OPT_USER_ID": "External: OPT users (not in this PDF)",
    "FILL_ACTION_ID": "External: Fill Action lookup (not in this PDF)",
    "ABS_OB_LENGTH_TYPE_ID": "External: Absence Length Type lookup (not in this PDF)",
    "VACANCY_STATUS_ID": "External: Vacancy Status lookup (not in this PDF)",
    "SITTING_TYPE_ID": "External: Sitting Type lookup (not in this PDF)",
}

# ---------------------------------------------------------------------------
# Loading + PK backfill
# ---------------------------------------------------------------------------


def load_schema() -> Dict:
    schema = json.loads(SCHEMA_JSON.read_text())
    # Filter to production tables only (drop TMP_*)
    schema["tables"] = {
        name: t for name, t in schema["tables"].items()
        if not name.startswith("TMP_")
    }
    # Backfill missing PKs from unique *_PK indexes
    for name, t in schema["tables"].items():
        if t["primary_key"]:
            continue
        for idx in t["indexes"]:
            if idx["unique"] and idx["name"].endswith("_PK"):
                t["primary_key"] = {
                    "name": idx["name"],
                    "columns": idx["columns"],
                    "from_index": True,
                }
                break
    return schema


# ---------------------------------------------------------------------------
# FK inference
# ---------------------------------------------------------------------------


def build_pk_map(schema: Dict) -> Dict[str, str]:
    """Map: PK column name → owner table.

    Only single-column PKs participate (composite PKs are link-table style).
    """
    pk_map: Dict[str, str] = {}
    for name, t in schema["tables"].items():
        pk = t.get("primary_key")
        if not pk or len(pk["columns"]) != 1:
            continue
        col = pk["columns"][0]
        # If two tables claim the same PK column, prefer the one whose name
        # contains the PK column name (more specific owner). This handles e.g.
        # tables that legitimately re-use a code column.
        if col in pk_map:
            existing = pk_map[col]
            # Heuristic: shorter name wins if both contain the column
            if name in existing:
                continue
            if existing in name:
                pk_map[col] = name
                continue
        pk_map[col] = name
    return pk_map


def infer_fks(schema: Dict, pk_map: Dict[str, str]) -> List[Dict]:
    """For every non-PK column in every table, look for FK candidates.

    Returns list of dicts: {from_table, from_col, to_table, to_col, confidence,
    note?}
    """
    fks: List[Dict] = []
    for name, t in schema["tables"].items():
        pk = t.get("primary_key") or {"columns": []}
        pk_cols = set(pk["columns"])
        for col in t["columns"]:
            cname = col["name"]
            # Skip the PK columns themselves
            if cname in pk_cols and len(pk["columns"]) == 1:
                continue
            # Skip non-ID-ish columns
            if not (cname.endswith("_ID") or cname.endswith("_CODE")
                    or cname.endswith("_TYPE") or cname == "JUDGE_CODE"):
                continue

            # External-reference hint check
            if cname in EXTERNAL_REF_HINTS:
                fks.append({
                    "from_table": name,
                    "from_col": cname,
                    "to_table": "_EXTERNAL_",
                    "to_col": cname,
                    "confidence": "external",
                    "note": EXTERNAL_REF_HINTS[cname],
                })
                continue

            # HIGH: exact PK match
            if cname in pk_map and pk_map[cname] != name:
                fks.append({
                    "from_table": name,
                    "from_col": cname,
                    "to_table": pk_map[cname],
                    "to_col": cname,
                    "confidence": "high",
                })
                continue

            # MEDIUM: column ends with a known PK column (prefixed reference)
            # e.g. START_SITTING_DUR_ID → SITTING_DUR_ID → TBL_JI_SITTING_DURS
            #      JI_PLANNED_WORK_TYPE_ID → ? matches no PK exactly
            matched = False
            best_match = None
            best_pk_len = 0
            for pk_col, owner in pk_map.items():
                # Match only when the suffix is at least 5 chars to avoid noise
                # like X_ID matching all *_ID columns.
                if len(pk_col) < 5:
                    continue
                if cname == pk_col:
                    continue  # already handled above
                # Prefix-with-underscore match: column is "<PREFIX>_<PK>"
                if cname.endswith("_" + pk_col):
                    if len(pk_col) > best_pk_len:
                        best_pk_len = len(pk_col)
                        best_match = (pk_col, owner)
            if best_match is not None:
                pk_col, owner = best_match
                if owner != name:
                    fks.append({
                        "from_table": name,
                        "from_col": cname,
                        "to_table": owner,
                        "to_col": pk_col,
                        "confidence": "medium",
                    })
                    matched = True
            if matched:
                continue

            # LOW: column has *_ID suffix but no PK match; might be unmapped.
            # Skip silently — including these would create noise.

    return fks


# ---------------------------------------------------------------------------
# DOT generation
# ---------------------------------------------------------------------------


def table_cluster_map() -> Dict[str, str]:
    out = {}
    for key, _label, tables, _color in CLUSTERS:
        for t in tables:
            out[t] = key
    return out


def cluster_color_map() -> Dict[str, str]:
    return {key: color for key, _label, _tables, color in CLUSTERS}


def fmt_type(t: str) -> str:
    """Compact type for display. NUMBER(6,0) → NUMBER(6,0); VARCHAR2(4000) → VARCHAR2(4000)."""
    return t


def html_escape(s: str) -> str:
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def trigger_badges(triggers: List[Dict]) -> str:
    """Compact badges showing what trigger types fire on the table."""
    if not triggers:
        return ""
    seen: Set[str] = set()
    for tr in triggers:
        timing = tr["timing"][0].upper()  # B or A
        event = tr["event"][0].upper()  # I, U, D
        seen.add(f"{timing}{event}")
    badges = " ".join(sorted(seen))
    return f' <font color="#0a3069" point-size="9">[{badges}]</font>'


def build_table_node(
    table: Dict,
    fks_from_table: List[Dict],
    pk_map: Dict[str, str],
    detail: bool,
    cluster_set: Set[str] | None = None,
) -> str:
    """Build an HTML-like Graphviz label for one table.

    detail=False: just the table name + trigger badges (for overview).
    detail=True: full column list with PK/FK/UK markers. When `cluster_set` is
                 provided, columns whose FK target is OUTSIDE the cluster (or
                 external) are italicised and the target table name is shown in
                 italics in the marker cell — no edge will be drawn for those.
    """
    name = table["name"]
    pk = table.get("primary_key") or {"columns": []}
    pk_cols = set(pk["columns"])
    cluster_set = cluster_set or set()

    # Unique constraints from indexes named *_UK*
    uk_cols: Set[str] = set()
    for idx in table["indexes"]:
        if idx["unique"] and "_UK" in idx["name"]:
            for c in idx["columns"]:
                uk_cols.add(c)

    # FK origin columns
    fk_by_col: Dict[str, Dict] = {}
    for fk in fks_from_table:
        fk_by_col[fk["from_col"]] = fk

    pk_from_idx = pk.get("from_index", False)

    if not detail:
        # Overview: name + trigger badges + small column count
        col_count = len(table["columns"])
        badges = trigger_badges(table["triggers"])
        header = (
            f'<table border="0" cellborder="0" cellspacing="0" cellpadding="2">'
            f'<tr><td align="center"><b>{html_escape(name)}</b>{badges}</td></tr>'
            f'<tr><td align="center"><font point-size="9" color="#57606a">{col_count} columns</font></td></tr>'
            f'</table>'
        )
        return header

    # Detail mode — full table
    rows = []
    badges = trigger_badges(table["triggers"])
    pk_note = " (from *_PK index)" if pk_from_idx else ""
    pk_label = ", ".join(pk["columns"]) if pk["columns"] else "(no PK declared)"
    rows.append(
        f'<tr><td bgcolor="#d0d7de" align="left" colspan="3">'
        f'<b>{html_escape(name)}</b>{badges}</td></tr>'
    )
    rows.append(
        f'<tr><td bgcolor="#eaeef2" align="left" colspan="3">'
        f'<font point-size="9"><i>PK: {html_escape(pk_label)}{html_escape(pk_note)}</i></font></td></tr>'
    )
    for col in table["columns"]:
        cname = col["name"]
        ctype = col["type"]
        markers: List[str] = []
        cname_display = html_escape(cname)
        is_cross_cluster_ref = False

        if cname in pk_cols:
            markers.append("PK")
            cname_display = f"<b>{cname_display}</b>"

        fk = fk_by_col.get(cname)
        if fk:
            if fk["confidence"] == "external":
                # External reference: italicise column, mark target in italics
                cname_display = f"<i>{cname_display}</i>"
                hint = EXTERNAL_REF_HINTS.get(cname, "external")
                # Compact hint: strip "External: " prefix and "(not in this PDF)" suffix
                hint_clean = hint.replace("External: ", "").replace(" (not in this PDF)", "")
                markers.append(f"→ <i>{html_escape(hint_clean)}</i>")
                is_cross_cluster_ref = True
            elif fk["to_table"] in cluster_set:
                # In-cluster FK → edge will be drawn; mark with plain "FK"
                if cname not in pk_cols:
                    markers.append("FK")
            else:
                # Cross-cluster FK: italicise column, show target table in italics
                cname_display = f"<i>{cname_display}</i>"
                markers.append(f"→ <i>{html_escape(fk['to_table'])}</i>")
                is_cross_cluster_ref = True

        if cname in uk_cols and cname not in pk_cols:
            markers.append("UK")
        if not col.get("nullable", True):
            markers.append("NN")
        marker_str = " ".join(markers) if markers else ""
        marker_color = "#888" if is_cross_cluster_ref else "#0969da"
        marker_cell = (
            f'<td align="left"><font point-size="9" color="{marker_color}">{marker_str}</font></td>'
            if marker_str
            else '<td align="left"> </td>'
        )
        # Port only for in-cluster references (where we'll draw an edge); for
        # other rows the port is harmless but unused.
        port = re.sub(r'[^A-Za-z0-9]', '_', cname.lower())
        rows.append(
            f'<tr>'
            f'<td port="{port}" align="left"><font face="monospace" point-size="10">{cname_display}</font></td>'
            f'<td align="left"><font face="monospace" point-size="9" color="#57606a">{html_escape(ctype)}</font></td>'
            f'{marker_cell}'
            f'</tr>'
        )
    return (
        f'<table border="1" color="#57606a" cellborder="0" cellspacing="0" cellpadding="3">'
        + "".join(rows)
        + '</table>'
    )


def write_detail_legend_node() -> str:
    """Compact detail-diagram legend. ~6 rows; single column."""
    return (
        '<table border="0" cellborder="1" cellspacing="0" cellpadding="3" bgcolor="white">'
        '<tr><td bgcolor="#d0d7de"><font point-size="10"><b>Legend</b></font></td></tr>'
        '<tr><td align="left"><font point-size="9"><b>PK</b> primary · <b>FK</b> in-area (line) · <b>UK</b> unique · <b>NN</b> not null</font></td></tr>'
        '<tr><td align="left"><font point-size="9"><i>col</i> → <i>TBL_X</i> — cross-area ref (no line)</font></td></tr>'
        '<tr><td align="left"><font point-size="9"><i>col</i> → <i>hint</i> — external (not in PDF)</font></td></tr>'
        '<tr><td align="left"><font point-size="9"><b>[BI/BU/AI/AU/…]</b> = trigger Before/After × Insert/Update/Delete</font></td></tr>'
        '<tr><td align="left"><font point-size="9">━━ solid blue = HIGH FK · - - dashed = MEDIUM FK</font></td></tr>'
        '</table>'
    )


def write_overview_legend_node() -> str:
    """Compact overview legend. ~4 rows."""
    return (
        '<table border="0" cellborder="1" cellspacing="0" cellpadding="3" bgcolor="white">'
        '<tr><td bgcolor="#d0d7de"><font point-size="10"><b>Legend</b></font></td></tr>'
        '<tr><td align="left"><font point-size="9">Box = area · <font face="monospace">TBL_NAME (n)</font> = column count</font></td></tr>'
        '<tr><td align="left"><font point-size="9">Arrow with N = inter-area FK count (line weight scales)</font></td></tr>'
        '<tr><td align="left"><font point-size="9"><b>[BI/BU/…]</b> = trigger Before/After × Insert/Update/Delete</font></td></tr>'
        '</table>'
    )


def fk_edge_attrs(confidence: str) -> str:
    if confidence == "high":
        return 'style="solid", color="#1f6feb", penwidth=1.4, arrowsize=0.7'
    if confidence == "medium":
        return 'style="dashed", color="#6c757d", penwidth=1.0, arrowsize=0.6'
    if confidence == "external":
        return 'style="dotted", color="#999", penwidth=0.8, arrowsize=0.5'
    return 'style="dotted", color="#aaa"'


def build_overview_dot(schema: Dict, fks: List[Dict]) -> str:
    """Overview: each cluster rendered as ONE big box listing its tables.

    No per-table edges. Inter-cluster arrows summarise FK relationships between
    areas with a count label.
    """
    cmap = table_cluster_map()
    cluster_labels = {key: label for key, label, _t, _c in CLUSTERS}
    cluster_colors = cluster_color_map()

    # Aggregate inter-cluster FK counts (skip externals + intra-cluster)
    cluster_edges: Dict[Tuple[str, str], int] = {}
    for fk in fks:
        if fk["to_table"] == "_EXTERNAL_" or fk["confidence"] == "external":
            continue
        c_from = cmap.get(fk["from_table"])
        c_to = cmap.get(fk["to_table"])
        if not c_from or not c_to or c_from == c_to:
            continue
        cluster_edges[(c_from, c_to)] = cluster_edges.get((c_from, c_to), 0) + 1

    lines = [
        'digraph JI_Schema_Overview {',
        '  graph [rankdir=TB, splines=true, overlap=false, nodesep=0.35, ranksep=0.6, newrank=true, bgcolor="white", fontname="Helvetica", fontsize=14, labelloc="t", label=<<b>JI as-is database schema — overview</b><br/><font point-size="11">46 production tables in 6 areas · inter-area FK relationships aggregated · 0 explicit FK constraints in source DDL</font>>];',
        '  node [shape=plain, fontname="Helvetica"];',
        '  edge [fontname="Helvetica", fontsize=10];',
        '',
    ]

    # Render each cluster as a single HTML-table node
    for key, label, tables, color in CLUSTERS:
        safe_key = key.replace("-", "_")
        # Build the cluster's table-listing HTML
        rows = [
            f'<tr><td bgcolor="{color}" align="center" cellpadding="6">'
            f'<font point-size="13"><b>{html_escape(label)}</b></font>'
            f'<br/><font point-size="9" color="#57606a">{len(tables)} tables</font>'
            f'</td></tr>'
        ]
        for tbl_name in tables:
            tbl = schema["tables"].get(tbl_name)
            if not tbl:
                continue
            ncols = len(tbl["columns"])
            badges = trigger_badges(tbl["triggers"])
            rows.append(
                f'<tr><td align="left" cellpadding="3">'
                f'<font face="monospace" point-size="11">{html_escape(tbl_name)}</font>'
                f' <font point-size="9" color="#57606a">({ncols})</font>'
                f'{badges}'
                f'</td></tr>'
            )
        node_label = (
            f'<table border="1" color="#999" cellborder="0" cellspacing="0" cellpadding="0" bgcolor="white">'
            + "".join(rows)
            + '</table>'
        )
        lines.append(f'  "_cluster_{safe_key}" [label=<{node_label}>];')

    lines.append('')

    # Force a compact 3-column × 2-row grid by ranking clusters explicitly.
    # In rankdir=TB, rank=same puts nodes on the same horizontal row.
    grid_cols = 3
    cluster_keys = [k for k, *_ in CLUSTERS]
    rows = [cluster_keys[i:i + grid_cols] for i in range(0, len(cluster_keys), grid_cols)]
    for row in rows:
        row_nodes = "; ".join(f'"_cluster_{k.replace("-", "_")}"' for k in row)
        lines.append(f'  {{ rank=same; {row_nodes}; }}')
    # Force row1 above row2 via an invisible weighted edge between first
    # nodes of consecutive rows. This avoids dot ordering rows by FK direction.
    for top_row, bot_row in zip(rows, rows[1:]):
        sk_top = top_row[0].replace("-", "_")
        sk_bot = bot_row[0].replace("-", "_")
        lines.append(f'  "_cluster_{sk_top}" -> "_cluster_{sk_bot}" [style=invis, weight=20];')
    lines.append('')

    # Inter-cluster arrows (sized by edge count for visual weight)
    for (c_from, c_to), count in cluster_edges.items():
        safe_from = c_from.replace("-", "_")
        safe_to = c_to.replace("-", "_")
        pw = min(1.0 + (count / 8.0), 4.0)  # 1.0 → 4.0 stroke width
        lines.append(
            f'  "_cluster_{safe_from}" -> "_cluster_{safe_to}" '
            f'[label="  {count}  ", color="#1f6feb", penwidth={pw:.2f}, arrowsize=0.9, fontcolor="#0a3069", constraint=false];'
        )

    # Legend pinned to bottom-right. In TB mode with rank=same rows in place,
    # rank=sink puts the legend below row 2; pairing it with the last cluster
    # of the bottom row encourages right-alignment.
    legend_html = write_overview_legend_node()
    lines.append('')
    lines.append(f'  "_legend" [shape=plain, label=<{legend_html}>];')
    if rows:
        last_row = rows[-1]
        anchor = last_row[-1].replace("-", "_")  # bottom-right cluster
        lines.append(f'  "_cluster_{anchor}" -> "_legend" [style=invis, weight=10];')
    lines.append('  { rank=sink; "_legend"; }')

    lines.append('}')
    return "\n".join(lines)


def chunk_for_grid(items: List[str], cols: int) -> List[List[str]]:
    """Split items into rows of `cols` for grid arrangement."""
    return [items[i:i + cols] for i in range(0, len(items), cols)]


def build_detail_dot(schema: Dict, fks: List[Dict], cluster_key: str, cluster_label: str, cluster_tables: List[str], color: str) -> str:
    """Detail diagram for one cluster.

    Only intra-cluster FK edges are drawn. Cross-cluster references appear as
    italicised columns with the target name in italics in the marker cell
    (handled in build_table_node). Tables are laid out in a grid using
    rank=same constraints so the diagram spreads rather than stacks.
    """
    pk_map = build_pk_map(schema)
    cluster_set = set(cluster_tables)

    # Only keep FKs where BOTH ends are in this cluster (intra-cluster)
    intra_fks = [
        fk for fk in fks
        if fk["from_table"] in cluster_set
        and fk["to_table"] in cluster_set
        and fk["to_table"] != "_EXTERNAL_"
    ]

    # Choose grid width: roughly sqrt(N) tables per row, capped for readability
    n = len(cluster_tables)
    cols = max(2, min(4, int(round(n ** 0.5))))
    rows_of_tables = chunk_for_grid(cluster_tables, cols)

    safe_key = cluster_key.replace("-", "_")
    lines = [
        f'digraph JI_Schema_{safe_key} {{',
        f'  graph [rankdir=TB, splines=true, overlap=false, nodesep=0.35, ranksep=0.7, newrank=true, bgcolor="white", fontname="Helvetica", fontsize=14, labelloc="t", label=<<b>JI as-is schema — {html_escape(cluster_label)}</b><br/><font point-size="11">Full columns · PK/FK/UK markers · trigger badges · intra-area FK edges only</font>>];',
        '  node [shape=plain, fontname="Helvetica"];',
        '  edge [fontname="Helvetica", fontsize=9];',
        '',
        f'  subgraph cluster_main {{',
        f'    label=<<b>{html_escape(cluster_label)}</b>>;',
        f'    labeljust="l";',
        f'    labelloc="t";',
        f'    style="filled,rounded";',
        f'    fillcolor="{color}";',
        f'    color="#999";',
        f'    fontsize=12;',
        f'    margin=18;',
    ]

    # Render each table node
    for tbl_name in cluster_tables:
        tbl = schema["tables"].get(tbl_name)
        if not tbl:
            continue
        tbl_fks = [fk for fk in fks if fk["from_table"] == tbl_name]
        label_html = build_table_node(tbl, tbl_fks, pk_map, detail=True, cluster_set=cluster_set)
        lines.append(f'    "{tbl_name}" [label=<{label_html}>];')

    lines.append('')

    # Grid layout: force tables into rows using rank=same blocks. Add invisible
    # edges between consecutive tables on the same row to encourage horizontal
    # ordering without making them appear connected.
    for row in rows_of_tables:
        if len(row) > 1:
            lines.append('    { rank=same; ' + '; '.join(f'"{t}"' for t in row) + '; }')
            for a, b in zip(row, row[1:]):
                lines.append(f'    "{a}" -> "{b}" [style=invis, weight=10];')

    # Invisible edges between row-1 and row-2 first elements etc. to keep rows
    # roughly in vertical order
    for top_row, bot_row in zip(rows_of_tables, rows_of_tables[1:]):
        if top_row and bot_row:
            lines.append(f'    "{top_row[0]}" -> "{bot_row[0]}" [style=invis, weight=5];')

    lines.append('  }')
    lines.append('')

    # Intra-cluster FK edges. The source attaches to the originating column
    # row (so the reader can see WHERE the FK leaves from) and exits east
    # (`:e`) to the right. The destination attaches to the target TABLE as a
    # whole — no column port — letting Graphviz pick the shortest attachment
    # point on the target box. With splines=true edge routing is curved; for
    # tightest paths we'd use splines=ortho but that loses cluster routing.
    drawn = set()
    for fk in intra_fks:
        from_port = re.sub(r'[^A-Za-z0-9]', '_', fk["from_col"].lower())
        attrs = fk_edge_attrs(fk["confidence"])
        src = f'"{fk["from_table"]}":{from_port}:e'
        dst = f'"{fk["to_table"]}"'
        key = (src, dst)
        if key in drawn:
            continue
        drawn.add(key)
        lines.append(f'  {src} -> {dst} [{attrs}];')

    # Legend, pinned to bottom-right. In TB layout, "bottom" = sink rank.
    # "Right" is encouraged by an invisible edge from the last (bottom-right)
    # table in the grid to the legend.
    legend_html = write_detail_legend_node()
    lines.append('')
    lines.append(f'  "_legend" [shape=plain, label=<{legend_html}>];')
    if rows_of_tables:
        last_row = rows_of_tables[-1]
        if last_row:
            anchor = last_row[-1]  # bottom-right table
            lines.append(f'  "{anchor}" -> "_legend" [style=invis, weight=1, constraint=false];')
            # Force the legend to share rank with the bottom row so it sits at
            # the same vertical level rather than below in its own row.
            lines.append('    { rank=sink; "_legend"; "' + last_row[-1] + '"; }')

    lines.append('}')
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------


def render_dot(dot_path: Path, png_path: Path, dpi: int = 150) -> None:
    subprocess.run(
        ["dot", "-Tpng", f"-Gdpi={dpi}", str(dot_path), "-o", str(png_path)],
        check=True,
    )


# ---------------------------------------------------------------------------
# Companion markdown
# ---------------------------------------------------------------------------


def build_companion_md(schema: Dict, fks: List[Dict]) -> str:
    """Build the companion reference markdown: triggers, externals, FK rationale."""
    lines = ["# JI as-is database — diagram companion reference", ""]
    lines.append("This document accompanies the PNG schema diagrams in this folder. It contains:")
    lines.append("")
    lines.append("- Trigger reference (every trigger, its table, timing, event, and body)")
    lines.append("- External-reference inventory (columns pointing to tables NOT in this PDF)")
    lines.append("- FK inference confidence notes")
    lines.append("")

    # --- Trigger reference ---
    lines.append("## Trigger reference")
    lines.append("")
    lines.append("All 24 triggers extracted from the source DDL. Triggers are predominantly mechanical: `BI_*` (before-insert) assign the PK from a sequence; `BU_*` (before-update) maintain `LAST_MODIFIED_BY` / `LAST_MODIFIED_DATE` audit columns.")
    lines.append("")
    lines.append("| Table | Trigger | Timing | Event | Purpose (summary) |")
    lines.append("|---|---|---|---|---|")
    for tname in sorted(schema["tables"]):
        t = schema["tables"][tname]
        for tr in t["triggers"]:
            timing = tr["timing"].capitalize()
            event = tr["event"]
            body = tr["body"]
            # Determine summary purpose
            if "nextval" in body and "PK" in tr["name"].upper() or "BI_" in tr["name"]:
                purpose = "Auto-assign PK from sequence"
            elif "LAST_MODIFIED" in body.upper():
                purpose = "Maintain LAST_MODIFIED_BY/DATE audit"
            elif "nextval" in body:
                purpose = "Auto-assign PK from sequence"
            else:
                purpose = "—"
            lines.append(f"| `{tname}` | `{tr['name']}` | {timing} | {event} | {purpose} |")
    lines.append("")
    lines.append("### Trigger bodies (full)")
    lines.append("")
    for tname in sorted(schema["tables"]):
        t = schema["tables"][tname]
        if not t["triggers"]:
            continue
        lines.append(f"#### `{tname}`")
        lines.append("")
        for tr in t["triggers"]:
            lines.append(f"**`{tr['name']}`** — {tr['timing']} {tr['event']}")
            lines.append("")
            lines.append("```sql")
            lines.append(tr["body"])
            lines.append("```")
            lines.append("")

    # --- External references ---
    lines.append("## External-reference inventory")
    lines.append("")
    lines.append("These columns reference tables that are **NOT present in the source PDF**. Likely live in a separate reference-data dump (locations, regions, courtrooms, OPT user accounts, status lookups). Confirm with the data-dictionary owner before treating them as authoritative.")
    lines.append("")
    lines.append("| Column | Inferred target | Tables using it |")
    lines.append("|---|---|---|")
    # Group external refs by column name
    by_col: Dict[str, Set[str]] = {}
    for fk in fks:
        if fk["confidence"] != "external":
            continue
        by_col.setdefault(fk["from_col"], set()).add(fk["from_table"])
    for col in sorted(by_col):
        users = ", ".join(f"`{t}`" for t in sorted(by_col[col]))
        hint = EXTERNAL_REF_HINTS.get(col, "External")
        lines.append(f"| `{col}` | {hint} | {users} |")
    lines.append("")

    # --- FK inference notes ---
    lines.append("## FK inference notes")
    lines.append("")
    lines.append("The source DDL contains **zero explicit `FOREIGN KEY` constraints**. Every relationship in the diagrams is inferred from column-naming conventions. Confidence buckets:")
    lines.append("")
    lines.append("- **HIGH (solid line, blue)** — column name exactly matches another table's primary-key column. Example: `JI_ABS_OB_ID` in `TBL_JI_VACANCIES` matches `TBL_JI_ABS_OB.JI_ABS_OB_ID`.")
    lines.append("- **MEDIUM (dashed line, grey)** — column is a *prefixed* version of another table's PK column (≥ 5-char suffix). Example: `START_SITTING_DUR_ID` and `END_SITTING_DUR_ID` both end with `SITTING_DUR_ID`, the PK of `TBL_JI_SITTING_DURS`.")
    lines.append("- **EXTERNAL (dotted line, light grey)** — column references a table outside this PDF.")
    lines.append("")
    lines.append("Columns ending in `_ID` or `_CODE` that match neither rule are flagged in the diagram body but no edge is drawn. They may be valid FK references to tables not yet identified.")
    lines.append("")
    lines.append("### Counts")
    lines.append("")
    n_high = sum(1 for fk in fks if fk["confidence"] == "high")
    n_med = sum(1 for fk in fks if fk["confidence"] == "medium")
    n_ext = sum(1 for fk in fks if fk["confidence"] == "external")
    lines.append(f"- HIGH confidence FKs: **{n_high}**")
    lines.append(f"- MEDIUM confidence FKs: **{n_med}**")
    lines.append(f"- EXTERNAL references: **{n_ext}**")
    lines.append("")

    # --- All inferred FKs table ---
    lines.append("### All inferred FKs")
    lines.append("")
    lines.append("| Source table | Source column | → | Target table | Target column | Confidence |")
    lines.append("|---|---|---|---|---|---|")
    for fk in sorted(fks, key=lambda f: (f["from_table"], f["from_col"])):
        if fk["to_table"] == "_EXTERNAL_":
            tgt_table = "_(external)_"
            tgt_col = "—"
        else:
            tgt_table = f"`{fk['to_table']}`"
            tgt_col = f"`{fk['to_col']}`"
        lines.append(
            f"| `{fk['from_table']}` | `{fk['from_col']}` | → | {tgt_table} | {tgt_col} | {fk['confidence']} |"
        )
    lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main() -> int:
    if not SCHEMA_JSON.exists():
        print(f"error: run parse_ji_ddl.py first; {SCHEMA_JSON} not found", file=sys.stderr)
        return 1
    if shutil.which("dot") is None:
        print("error: graphviz `dot` not found on PATH", file=sys.stderr)
        return 1

    schema = load_schema()
    print(f"Loaded {len(schema['tables'])} production tables")

    pk_map = build_pk_map(schema)
    print(f"PK map: {len(pk_map)} single-column PKs available for FK matching")

    fks = infer_fks(schema, pk_map)
    n_high = sum(1 for fk in fks if fk["confidence"] == "high")
    n_med = sum(1 for fk in fks if fk["confidence"] == "medium")
    n_ext = sum(1 for fk in fks if fk["confidence"] == "external")
    print(f"FKs inferred: {n_high} HIGH, {n_med} MEDIUM, {n_ext} EXTERNAL")

    # Detect tables outside any cluster (parser sanity)
    assigned = {t for _, _, ts, _ in CLUSTERS for t in ts}
    unassigned = [t for t in schema["tables"] if t not in assigned]
    if unassigned:
        print(f"WARNING: unassigned tables not in any cluster: {unassigned}", file=sys.stderr)

    # Overview DOT + PNG
    overview_dot = DB_DIR / "ji_schema_overview.dot"
    overview_png = DB_DIR / "ji_schema_overview.png"
    overview_dot.write_text(build_overview_dot(schema, fks))
    print(f"wrote {overview_dot.name}")
    # Overview renders at lower DPI so the on-screen image fits without
    # horizontal scrolling. Detail diagrams stay at 150 DPI for legibility.
    render_dot(overview_dot, overview_png, dpi=110)
    print(f"rendered {overview_png.name}")

    # Per-cluster detail DOTs + PNGs
    for key, label, tables, color in CLUSTERS:
        dot_path = DB_DIR / f"ji_schema_{key}.dot"
        png_path = DB_DIR / f"ji_schema_{key}.png"
        dot_path.write_text(build_detail_dot(schema, fks, key, label, tables, color))
        print(f"wrote {dot_path.name}")
        render_dot(dot_path, png_path, dpi=120)
        print(f"rendered {png_path.name}")

    # Companion markdown
    md_path = DB_DIR / "ji_schema_companion.md"
    md_path.write_text(build_companion_md(schema, fks))
    print(f"wrote {md_path.name}")

    print("\nDone.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
