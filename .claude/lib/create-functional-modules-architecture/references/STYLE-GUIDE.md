---
title: "Functional Modules Architecture — Style Guide"
subtitle: "Author-facing house style for module-by-module catalogue PDFs"
---

This is the author-facing style guide for documents produced by the `create-functional-modules-architecture` skill. The pipeline shares its house style with the sibling `create-data-dependency-architecture` skill (same `assets/doc-style.css`, same `assets/mermaid-config.json`, same `build-pdf.sh`), so this guide repeats only the *module-specific* prose conventions; the typographic / layout rules are inherited verbatim from the data-dependency skill's [`STYLE-GUIDE.md`](../../create-data-dependency-architecture/references/STYLE-GUIDE.md).

The goal is **once-set, never-reinvented styling**: authors focus on content, the build applies the look. If a rule below feels restrictive, edit the stylesheet (a single change benefits both skills), not the document.

---

## 1. File header — YAML front matter only

Every renderable document starts with YAML front matter that supplies a `title:` and a `subtitle:`. Do **not** add a leading `# H1`; the build pipeline strips it if you do, but it's cleaner to omit it. Inherited verbatim from the data-skill style guide.

```yaml
---
title: "Judicial Itineraries (JI) — Functional Modules"
subtitle: "Module-by-module catalogue of JI's functional surface"
---
```

---

## 2. Headings — same scale as the data-skill

| Level | Used for | Style applied |
|-------|----------|----------------|
| `#` (H1) | Not used in the body — title is in YAML front matter | — |
| `##` (H2) | Major sections (`At a Glance`, `Module overview`, `Modules`, `Cross-cutting NFRs`, `Summary`, `Appendix`, `Source Documents`) | 16pt, dark navy, with thin underline rule |
| `###` (H3) | Numbered module entries (e.g. *2. Manage Judges*) | 13pt, dark navy |
| `####` (H4) | Rare — small uppercase labels inside a module entry | 11pt, uppercase, slightly tracked |

Number the H3s inline (`### 1. Home`, `### 2. Manage Judges`); the numbers must align with the `#` column in the *At a Glance* table.

---

## 3. The "At a Glance" table

Every functional-modules document opens with an *At a Glance* compact summary table immediately after the lead paragraph. The shape is fixed — copy the header *and the separator dashes* verbatim:

```markdown
| # | Module | Primary Users | Purpose | Status |
|----|--------------------------|------------------|------------------------------------|----------------|
| 1 | **Home** | All users | Landing page; navigation; dashboard counts | Implemented |
| 2 | **Manage Judges** | RSU; Court | Maintain judge profiles, working patterns | Implemented |
```

Rules:

- **Five columns only**: `#`, `Module`, `Primary Users`, `Purpose`, `Status`. No description column, no NFR column — those live in the per-module *Attribute / Detail* table.
- The `Module` cell holds the module name in **bold**; aliases / variant names go in `module-enumeration.md`, not here.
- The `Status` cell uses the closed vocabulary verbatim — `Implemented`, `Partial`, `Discovery required`, `Out of scope`.
- **Separator-dash widths are load-bearing.** The `4 / 26 / 18 / 36 / 16` dash pattern (count `-` per column) tells pandoc to emit `<col style="width: 4% / 26% / 18% / 36% / 16%">`. The wide *Purpose* share is what keeps its cells to ≤ 2 lines.
- Cells must be **terse — 1–8 words per cell**. Full nuance lives in the per-module *Attribute / Detail* table.

---

## 4. Module detail entries

Each numbered H3 follows a fixed structure (specified in [`OUTPUT-STRUCTURE.md`](OUTPUT-STRUCTURE.md) §6). The author-facing rules:

### 4.1 Lead paragraph — 1–2 sentences only

Open with **one to two sentences** stating purpose and primary user. Name the module in **bold** on first reference. Don't restate the *At a Glance* row; expand it.

```markdown
✅ The **Manage Judges** module is the system of entry for judge profiles. RSU users maintain personal details, working patterns, jurisdictional split and tickets here; Court users have read-only or DJ-only access depending on role.

❌ The Manage Judges module (which is module 2 in this document) is a critical part of the JI system that allows users (mostly RSU but also Court) to do various things related to judges, such as creating, editing, and updating their information, working patterns, and other related details, as described in the source documents.
```

### 4.2 Capabilities — bulleted list, ≤ 1 line each

After the lead paragraph, a `**Capabilities**` heading followed by a bulleted list. **One capability per bullet, one line per bullet.** No nested bullets.

```markdown
✅
- Maintain judge profiles (salaried and fee-paid)
- Define and update working patterns; auto-populate itineraries
- Maintain per-judge statistics for the financial year

❌
- Maintain judge profiles, including:
  - Salaried judges
  - Fee-paid judges
  - And lots of fields per judge (name, email, payroll number, …)
```

If a capability genuinely needs more than one line to describe, it belongs in the prose lead paragraph or in the `Business rules` row of the *Attribute / Detail* table — not in the bullet list.

### 4.3 Attribute / Detail table — nine mandatory rows

Use a two-column table where the left column is the attribute label and the right column is the description. The shape is fixed — copy the header *and the separator dashes* verbatim:

```markdown
| Attribute | Detail |
|-----|--------------------|
| **Module ID** | MJ |
| **Primary users** | RSU (Full Access); Court (Full Access for DJs) |
| **Trigger / entry points** | Top-level "Manage Judges" tab; deep-link from Judge Itinerary |
| **Inputs** | Judge profile fields; working patterns (see Data Dependencies §1, §2) |
| **Outputs** | Judge records consumed by Judge Itinerary, Court Itinerary, Sittings, Bookings |
| **Business rules** | Salaried vs fee-paid affects available fields; DJ access constrained to base location |
| **Cross-module dependencies** | [Court Itinerary](#court-itinerary); [Judge Itinerary](#judge-itinerary); [Bookings](#fee-paid-and-other-bookings) |
| **NFRs** | MJ-NFR-01..05 — search returns ≤ 10s; auditable; RSU-only updates |
| **Status** | Implemented |
```

Rules:

- **Separator-dash widths are load-bearing.** The `5 / 20` dash pattern produces `<col style="width: 20% / 80%">` — narrow Attribute label, wide Detail.
- All nine rows are **mandatory** in the order shown. If a value is genuinely unknown, write `Unknown` rather than dropping the row.
- The `Status` row uses one of the four verbatim values defined in [`OUTPUT-STRUCTURE.md`](OUTPUT-STRUCTURE.md) §6. No paraphrases.
- The `Cross-module dependencies` row uses anchor links (no numbers), or the literal string `None` if the module is standalone.

### 4.4 Key user actions — optional, WHEN/THEN format

If the module has clear primary user actions, list them after the *Attribute / Detail* table under a `**Key user actions**` heading. Each action is a single bullet using `WHEN <X> THEN <Y>` form — drawn directly from the source documents.

```markdown
**Key user actions**

- **WHEN** an RSU user opens *Manage Judges* and selects a judge **THEN** the system displays the judge's profile with personal, role and working-pattern tabs.
- **WHEN** an RSU user updates a judge's working pattern **THEN** the system regenerates the judge's itinerary up to 31st March following the start date, preserving any pre-existing absences.
```

Omit this section entirely for purely back-office or read-only modules. Don't pad it with weak actions.

### 4.5 Sources blockquote — one per module

End every module entry with a sources blockquote:

```markdown
> Sources: *<Doc Name>* (section reference); *<Doc Name>* (section reference).
```

The stylesheet renders blockquotes with a light grey left bar and muted text colour. Cite the most specific reference available (a requirements ID like `MJ-FR-01`, a section number like `§4.2a`, or a clearly named subsection).

---

## 5. The Module overview diagram

Exactly **one** Mermaid `flowchart LR` block per document. Same theme, shapes and `<br/>` rules as the data-skill (inherited verbatim).

- Three subgraphs grouping modules by domain — typical groupings are `Operational`, `Finance`, `Admin & MI`.
- All nodes are plain rectangles (`["..."]`).
- Number each node with its *At a Glance* row number (`["1. Home"]`).
- Solid arrows for explicit cross-module flows the source calls out; dashed arrows (`-.->`) for `Discovery required` or `Out of scope` flows.
- `<br/>` for line breaks; never `\n`.

---

## 6. Cross-references

When linking to another module, use the no-number anchor form and the module *name* as the link text:

```markdown
✅ "the [Payments module](#payments) consumes confirmed bookings from the [Fee-paid Bookings module](#fee-paid-and-other-bookings)"
❌ "the chain runs `2 → 3 → 7`"
```

Numbers belong in tables and diagrams. Names belong in prose.

When linking *across documents* to the data-dependency catalogue (which lives in the sibling `<input-folder>/output/` folder when both skills have run against the same input), use a relative-path anchor link that walks up from `output-functional-modules/` and into `output/`:

```markdown
[JFEPS payment schedule](../output/data-dependencies.md#jfeps-lberata-finance-fee-paid-payment-schedules)
```

These cross-document links are textual only — they remain readable in the rendered PDF even if the data-dependency PDF is not present.

---

## 7. Closing sections

Optional `## Cross-cutting NFRs` (only if the source documents describe truly system-wide NFRs distinct from per-module ones). Otherwise omit.

`## Summary` — three to five bullets describing module counts by status, the most critical end-to-end flow (using module names, not row numbers), and any notable gaps. Not a recap of the body; an at-a-glance editorial.

Optional `## Appendix` — one short bullet per non-obvious structural decision (e.g. why a sub-module is presented under a parent, why a system mentioned in the source documents was deliberately ruled out). Omit if there is nothing to record.

`## Source Documents` — exactly the files at the top level of the input folder when the skill ran. Don't pad; don't omit.

---

## 8. Building the PDF

```bash
.claude/lib/create-data-dependency-architecture/scripts/build-pdf.sh <input-folder>/output-functional-modules/functional-modules.md
```

This produces `functional-modules.pdf` next to the source. Mermaid PNGs and the rewritten build markdown are written to `functional-modules.assets/` for inspection if anything looks off.

The build script lives in the **data-dependency skill** by design (see [`LESSONS-LEARNED.md`](LESSONS-LEARNED.md) F1). Don't copy it into this skill.
