---
title: "OWASP Agentic Top 10 — {{CODEBASE_NAME}} Review"
subtitle: "Static review of {{CODEBASE_NAME}} against the OWASP Top 10 for Agentic Applications 2026"
date: "{{REVIEW_DATE}}"
---

This report measures the codebase at `{{INPUT_PATH}}` against the ten Agentic Security Initiative (ASI) entries from *OWASP Top 10 for Agentic Applications 2026* (December 2025, OWASP GenAI Security Project).

The review covers code at `{{INPUT_PATH}}` as of {{REVIEW_DATE}} ({{COMMIT_REF}}). Source files in {{LANGS_SHORT}} were read through static review; binary artefacts and generated code under `node_modules/`, `.venv/`, `dist/`, `build/` and similar were not scanned. {{ADDITIONAL_LIMITATIONS}}

## Executive Summary

- {{EXEC_BULLET_POSTURE}} (`{{COUNT_MITIGATED}}` Mitigated, `{{COUNT_PARTIAL}}` Partial, `{{COUNT_EXPOSED}}` Exposed, `{{COUNT_UNKNOWN}}` Unknown, `{{COUNT_NA}}` Not applicable across the ten ASI entries).
- {{EXEC_BULLET_TOP_FINDING}}.
- {{EXEC_BULLET_SYSTEMIC_GAP}}.
- {{EXEC_BULLET_BEST_MITIGATION}}.
- {{EXEC_BULLET_AGENTIC_FINGERPRINT}}.

## Risk Status Board

```mermaid
flowchart LR
    classDef exposed fill:#d62728,color:#fff,stroke:#7a1010,stroke-width:1.5px
    classDef partial fill:#ff9933,color:#fff,stroke:#a35400,stroke-width:1.5px
    classDef mitigated fill:#2ca02c,color:#fff,stroke:#1f7a1f,stroke-width:1.5px
    classDef unknown fill:#7f7f7f,color:#fff,stroke:#444444,stroke-width:1.5px
    classDef na fill:#cccccc,color:#333,stroke:#888888,stroke-width:1.5px

    subgraph row2 [" "]
        direction TB
        A6["ASI06<br/>Memory Poison<br/><b>{{V06}}</b>"]:::{{CLASS_06}}
        A7["ASI07<br/>Inter-Agent Comms<br/><b>{{V07}}</b>"]:::{{CLASS_07}}
        A8["ASI08<br/>Cascading<br/><b>{{V08}}</b>"]:::{{CLASS_08}}
        A9["ASI09<br/>Trust Exploit<br/><b>{{V09}}</b>"]:::{{CLASS_09}}
        A10["ASI10<br/>Rogue Agents<br/><b>{{V10}}</b>"]:::{{CLASS_10}}
    end

    subgraph row1 [" "]
        direction TB
        A1["ASI01<br/>Goal Hijack<br/><b>{{V01}}</b>"]:::{{CLASS_01}}
        A2["ASI02<br/>Tool Misuse<br/><b>{{V02}}</b>"]:::{{CLASS_02}}
        A3["ASI03<br/>Identity Abuse<br/><b>{{V03}}</b>"]:::{{CLASS_03}}
        A4["ASI04<br/>Supply Chain<br/><b>{{V04}}</b>"]:::{{CLASS_04}}
        A5["ASI05<br/>RCE<br/><b>{{V05}}</b>"]:::{{CLASS_05}}
    end
```

> Red = Exposed (highest priority), amber = Partial, green = Mitigated, dark grey = Unknown, light grey = Not applicable. Tile contents reflect this run's verdicts; the colour mapping is fixed across all OWASP Agentic Top 10 reports.

`{{CLASS_NN}}` placeholders take one of: `exposed`, `partial`, `mitigated`, `unknown`, `na` — derived deterministically from the matching `{{VNN}}` verdict (`Exposed` → `exposed`, `Partial` → `partial`, `Mitigated` → `mitigated`, `Unknown` → `unknown`, `Not applicable` → `na`). The `<b>{{VNN}}</b>` cell can show `N/A` instead of `Not applicable` for the *Not applicable* case to keep the tile compact. **Do not reorder the subgraph declarations** — `row2` declared before `row1` is what makes Mermaid render ASI01-05 on top and ASI06-10 on the bottom (Mermaid flips parallel sibling subgraphs in declaration order).

## Codebase Fingerprint

| Attribute | Detail |
|-----|--------------------|
| **Path reviewed** | `{{INPUT_PATH}}` |
| **Primary languages** | {{LANGS_FULL}} |
| **Files scanned** | {{FILE_COUNT}} |
| **Lines of code** | {{LOC}} |
| **Agentic frameworks detected** | {{FRAMEWORKS}} |
| **Vector / memory stores** | {{VECTOR_STORES}} |
| **MCP / A2A surfaces** | {{MCP_SURFACES}} |
| **Tools registered with the agent** | {{TOOL_COUNT}} |
| **External integrations** | {{EXTERNAL_INTEGRATIONS}} |
| **Review date / commit** | {{REVIEW_DATE}} / {{COMMIT_REF}} |

## At a Glance

| # | ASI Entry | Verdict | Severity | Headline |
|----|-------------------------------------|--------------|--------------|--------------------------------------------------|
| 01 | Agent Goal Hijack                   | {{V01}} | {{S01}} | {{H01}} |
| 02 | Tool Misuse and Exploitation        | {{V02}} | {{S02}} | {{H02}} |
| 03 | Identity and Privilege Abuse        | {{V03}} | {{S03}} | {{H03}} |
| 04 | Agentic Supply Chain Vulnerabilities| {{V04}} | {{S04}} | {{H04}} |
| 05 | Unexpected Code Execution (RCE)     | {{V05}} | {{S05}} | {{H05}} |
| 06 | Memory & Context Poisoning          | {{V06}} | {{S06}} | {{H06}} |
| 07 | Insecure Inter-Agent Communication  | {{V07}} | {{S07}} | {{H07}} |
| 08 | Cascading Failures                  | {{V08}} | {{S08}} | {{H08}} |
| 09 | Human-Agent Trust Exploitation      | {{V09}} | {{S09}} | {{H09}} |
| 10 | Rogue Agents                        | {{V10}} | {{S10}} | {{H10}} |

The separator-dash widths above are load-bearing — pattern `4 / 37 / 14 / 14 / 50` keeps the *Headline* column wide so its cells wrap to ≤ 2 lines. Verdict is one of: `Mitigated`, `Partial`, `Exposed`, `Unknown`, `Not applicable`. Severity is one of: `Critical`, `High`, `Medium`, `Low`, `Informational`, `—`.

---

### ASI01 — Agent Goal Hijack

{{LEAD_01}}

| Attribute | Detail |
|-----|--------------------|
| **Verdict** | {{V01}} |
| **Severity** | {{S01}} |
| **Affirmative evidence** | {{AFF_01}} |
| **Risk signals** | {{RISK_01}} |
| **Coverage gap** | {{GAP_01}} |
| **Recommendation** | {{REC_01}} |

> Sources: *OWASP Top 10 for Agentic Applications 2026* — ASI01; codified rules at `.claude/lib/check-for-owasp-top10/references/OWASP-AGENTIC-TOP10.md`.

(... repeat the same `### ASI<NN> — <Title>` + lead + 6-row Attribute table + Sources blockquote for ASI02 through ASI10 ...)

---

## Codebase scan summary

- Top-level directories scanned: {{TOP_LEVEL_DIRS}}.
- Excluded patterns: `**/.git/**`, `**/node_modules/**`, `**/.venv/**`, `**/venv/**`, `**/dist/**`, `**/build/**`, `**/target/**`, `**/__pycache__/**`, `**/*.min.js`, `**/*.min.css`, `**/*.map`.
- Tools used: `scan-codebase.sh` (file inventory + fingerprint hits), then `Glob` / `Grep` / `Read` for targeted lookups against the OWASP rules in `.claude/lib/check-for-owasp-top10/references/OWASP-AGENTIC-TOP10.md`.
- Files unread / unreadable: {{UNREAD_FILES}}.

## Limitations of static review

- Runtime behaviour, network policy, IAM configuration and deployed secrets are not visible from source code alone.
- Production logs and monitoring effectiveness are not assessed.
- The *content* of system prompts is not evaluated — only that prompts exist and are version-controlled.
- Third-party / external services that tools call are visible only at the call site; their authentication, rate limiting and authorisation cannot be verified from this review.
- Behavioural alignment of the underlying model is out of scope.

## References

- *OWASP Top 10 for Agentic Applications 2026* — OWASP GenAI Security Project, December 2025. CC BY-SA 4.0.
- Codified rules: `.claude/lib/check-for-owasp-top10/references/OWASP-AGENTIC-TOP10.md`.
- Source extract: `.claude/lib/check-for-owasp-top10/references/owasp-top10-source-extract.txt`.
