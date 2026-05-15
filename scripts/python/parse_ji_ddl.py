#!/usr/bin/env python3
"""Parse the JI Tables DDL dump into structured JSON.

Reads `docs/architecture/asis/database/JI_Tables_1.txt` (produced by
`pdftotext -layout JI Tables - 1.pdf`) and emits a JSON file describing each
table: columns, primary key, indexes, triggers.

Foreign keys are NOT extracted here (the source has zero explicit FK constraints).
FK inference happens downstream in `build_schema_diagram.py`.

Output is written next to the source under
`docs/architecture/asis/database/ji_schema.json`.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Dict, List

REPO_ROOT = Path(__file__).resolve().parents[2]
SRC = REPO_ROOT / "docs" / "architecture" / "asis" / "database" / "JI_Tables_1.txt"
OUT = REPO_ROOT / "docs" / "architecture" / "asis" / "database" / "ji_schema.json"


# Match "CREATE TABLE "TBL_NAME"" — capture name, then everything up to the
# closing `;` of the create statement. Tables run multiple lines.
TABLE_RE = re.compile(
    r'^\s*CREATE TABLE\s+"([A-Z_]+)"\s*\(\s*(.*?)\s*\)\s*;',
    re.DOTALL | re.MULTILINE,
)

# Inside the column-block: each column is `"NAME" TYPE [DEFAULT x] [NOT NULL ENABLE],`
# The closing CONSTRAINT clause for the PK is at the end. We split on commas at
# brace-depth 0 to handle types like NUMBER(6,0) without splitting.
COLUMN_RE = re.compile(
    r'^\s*"([A-Z_0-9]+)"\s+([A-Z0-9]+(?:\(\s*\d+(?:\s*,\s*\d+)?\s*\))?)'
    r'(?:\s+DEFAULT\s+(\S+))?'
    r'(\s+NOT NULL ENABLE)?',
)

PK_RE = re.compile(
    r'CONSTRAINT\s+"([A-Z_0-9]+)"\s+PRIMARY KEY\s*\(\s*([^)]+)\)',
)

# Index after a table:
#   CREATE [UNIQUE] INDEX "NAME" ON "TBL_NAME" ("COL"[, "COL"...])
INDEX_RE = re.compile(
    r'CREATE\s+(UNIQUE\s+)?INDEX\s+"([A-Z_0-9]+)"\s+ON\s+"([A-Z_0-9]+)"\s*\(\s*([^)]+)\)',
)

# Trigger declaration:
#   CREATE OR REPLACE EDITIONABLE TRIGGER "NAME"
#   <type> insert|update on "TBL_NAME"
TRIGGER_HEADER_RE = re.compile(
    r'CREATE OR REPLACE EDITIONABLE TRIGGER\s+"([A-Z_0-9]+)"\s+'
    r'(before|after)\s+(insert|update|delete|insert or update|insert or delete|update or delete|insert or update or delete)\s+on\s+"([A-Z_0-9]+)"',
    re.IGNORECASE,
)


def split_top_level(s: str) -> List[str]:
    """Split a comma-separated list, ignoring commas inside parentheses."""
    out: List[str] = []
    depth = 0
    start = 0
    for i, c in enumerate(s):
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
        elif c == "," and depth == 0:
            out.append(s[start:i].strip())
            start = i + 1
    if start < len(s):
        out.append(s[start:].strip())
    return [p for p in out if p]


def parse_columns_block(block: str) -> Dict:
    """Parse the inside of CREATE TABLE (...) — columns + PK constraint."""
    items = split_top_level(block)
    columns: List[Dict] = []
    pk = None
    for item in items:
        # PK clause
        m = PK_RE.search(item)
        if m:
            pk_cols = [c.strip().strip('"') for c in m.group(2).split(",")]
            pk = {"name": m.group(1), "columns": pk_cols}
            continue
        # Skip USING INDEX trailing words on the PK clause line
        if item.startswith(("USING ", "ENABLE")):
            continue
        # Try column
        m = COLUMN_RE.match(item)
        if not m:
            continue
        col = {
            "name": m.group(1),
            "type": m.group(2).replace(" ", ""),
            "nullable": m.group(4) is None,
        }
        if m.group(3):
            col["default"] = m.group(3).strip("'")
        columns.append(col)
    return {"columns": columns, "primary_key": pk}


def extract_trigger_block(text: str, start_idx: int) -> str:
    """Trigger bodies end with `/\nALTER TRIGGER ... ENABLE;`.

    Returns the trigger body (text between header end and the `/` line).
    """
    # Find the slash-on-its-own-line terminator after start_idx
    slash_idx = text.find("\n/\n", start_idx)
    if slash_idx < 0:
        slash_idx = text.find("\n/", start_idx)
    return text[start_idx:slash_idx].strip() if slash_idx > 0 else ""


def parse(text: str) -> Dict:
    tables: Dict[str, Dict] = {}

    # --- tables + columns + PK ---
    for m in TABLE_RE.finditer(text):
        name = m.group(1)
        block = m.group(2)
        info = parse_columns_block(block)
        tables[name] = {
            "name": name,
            "columns": info["columns"],
            "primary_key": info["primary_key"],
            "indexes": [],
            "triggers": [],
            "grants": [],
        }

    # --- indexes ---
    for m in INDEX_RE.finditer(text):
        unique = bool(m.group(1))
        idx_name = m.group(2)
        tbl_name = m.group(3)
        cols = [c.strip().strip('"') for c in m.group(4).split(",")]
        if tbl_name in tables:
            tables[tbl_name]["indexes"].append({
                "name": idx_name,
                "unique": unique,
                "columns": cols,
            })

    # --- triggers ---
    for m in TRIGGER_HEADER_RE.finditer(text):
        trig_name = m.group(1)
        timing = m.group(2).lower()
        event = m.group(3).lower()
        tbl_name = m.group(4)
        body_start = m.end()
        body = extract_trigger_block(text, body_start)
        if tbl_name in tables:
            tables[tbl_name]["triggers"].append({
                "name": trig_name,
                "timing": timing,
                "event": event,
                "body": body,
            })

    return {"tables": tables, "table_count": len(tables)}


def main() -> int:
    if not SRC.exists():
        print(f"error: source not found: {SRC}", file=sys.stderr)
        return 1
    text = SRC.read_text()
    schema = parse(text)
    OUT.write_text(json.dumps(schema, indent=2))
    print(f"Parsed {schema['table_count']} tables → {OUT}")
    # Quick summary
    total_cols = sum(len(t["columns"]) for t in schema["tables"].values())
    total_idx = sum(len(t["indexes"]) for t in schema["tables"].values())
    total_trig = sum(len(t["triggers"]) for t in schema["tables"].values())
    print(f"  total columns:  {total_cols}")
    print(f"  total indexes:  {total_idx}")
    print(f"  total triggers: {total_trig}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
