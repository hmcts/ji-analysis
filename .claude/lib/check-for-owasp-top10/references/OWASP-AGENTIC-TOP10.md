# OWASP Top 10 for Agentic Applications — codified rules

This file is the *normative* reference the `check-for-owasp-top10` skill uses to evaluate a codebase. It is derived from *OWASP Top 10 For Agentic Applications 2026* (December 2025, OWASP GenAI Security Project — Agentic Security Initiative) — the original PDF text is preserved alongside this file at `owasp-top10-source-extract.txt` for citation.

For each of the ten Agentic Security Initiative (ASI) entries, this file captures:

- **Description** — one-paragraph summary of the threat.
- **What to look for in code** — concrete patterns the analyst should grep / read for. *Affirmative signals* indicate a mitigation is present; *risk signals* indicate the codebase is exposed.
- **Verdict rubric** — how to assign a status (`Mitigated`, `Partial`, `Exposed`, `Not applicable`, `Unknown`) and a severity (`Critical`/`High`/`Medium`/`Low`).
- **Mitigation guidelines** — distilled from the source PDF; what the codebase should do.

Use this file in **Phase 3** of the pipeline. The verdict per ASI must come from evidence in the code, not from absence of evidence — when nothing is found, assign `Unknown` rather than `Mitigated` or `Exposed`.

---

## ASI01 — Agent Goal Hijack

**Description.** Attackers manipulate an agent's objectives, task selection or decision pathways via prompt-based manipulation, deceptive tool outputs, malicious artefacts, forged agent-to-agent messages or poisoned external data. Distinguished from ASI06 (persistent memory corruption) and ASI10 (autonomous misalignment) — ASI01 covers active, attacker-driven goal redirection.

**What to look for in code.**

- *Affirmative signals.*
  - System prompts loaded from version-controlled files (not user-supplied) and protected from runtime mutation.
  - Input validation / sanitisation of user-provided text, uploaded documents, RAG-retrieved content before they reach the model.
  - Human-in-the-loop confirmation gates around goal-changing or high-impact actions.
  - "Intent capsule" / signed goal-binding patterns: a signed envelope containing the declared goal + constraints validated each cycle.
  - Logging of goal state, tool-use patterns and deviation alerts.
- *Risk signals.*
  - Direct concatenation of user input into the system prompt or planner prompt.
  - RAG retrieval that ingests untrusted sources (web, email, calendar, uploaded files) without content-filter / prompt-carrier detection.
  - Agent loops that re-plan based on tool output without any policy / intent re-validation.
  - Hard-coded `"You are a helpful agent…"` prompt strings spliced with `f"…{user_input}…"`.

**Verdict rubric.**

- `Mitigated` — system prompts are immutable at runtime, all untrusted natural-language input passes through a documented validation layer, and goal-changing actions require explicit human approval or pass a policy engine.
- `Partial` — at least one of the above is in place but at least one is missing.
- `Exposed` — user / external content concatenates directly into prompts with no validation, and there is no human approval on high-impact actions.
- `Not applicable` — codebase has no agent-style planner / multi-step reasoning loop.

**Mitigation guidelines.** Treat all NL inputs as untrusted; lock and version-control system prompts; require human approval for goal-changing or high-impact actions; sanitise every connected data source (RAG, email, calendar, files, peer-agent messages); maintain logging and continuous monitoring of agent activity with goal-state baselines.

---

## ASI02 — Tool Misuse and Exploitation

**Description.** Agents misuse legitimate tools (delete data, over-invoke costly APIs, exfiltrate information) due to prompt injection, misalignment, unsafe delegation or ambiguous instruction. Differs from ASI03 (privilege escalation) and ASI05 (RCE) — ASI02 is about misuse of *already-granted* privilege.

**What to look for in code.**

- *Affirmative signals.*
  - Per-tool permission profiles: scopes, rate limits, egress allowlists expressed as code (IAM / authorization policy).
  - Read-only modes for query tools; explicit confirmation step for destructive actions (delete, transfer, publish).
  - Pre-execution policy enforcement / dry-run / diff preview pattern before high-impact tool calls.
  - Sandboxed tool execution with outbound network allowlists.
  - Cost / rate / token budgets with automatic revocation when exceeded.
  - Short-lived credentials or just-in-time tokens for tool invocation; tokens bound to user session.
  - Fully qualified tool names + version pins; ambiguous-resolution fail-closed.
  - Immutable logs of tool invocations with anomaly / drift detection.
- *Risk signals.*
  - Tools defined with broad scopes ("admin", `*`, write access to production DBs) registered with an agent that doesn't otherwise need them.
  - Tool definitions that pass user-controlled strings to `subprocess`, `shell=True`, or unbounded SQL.
  - No rate-limit or cost cap on agent-driven tool loops.
  - Email / messaging tools without `dry_run` / `confirm` parameters.
  - Tool resolution by short alias only (`report`) rather than fully qualified name.

**Verdict rubric.**

- `Mitigated` — every tool registered with the agent has a documented least-privilege scope, destructive actions require human / policy approval, and tool calls flow through a logged enforcement point.
- `Partial` — least-privilege is partially applied; some destructive actions still auto-execute.
- `Exposed` — tools have broad scopes, no approval gates on destructive calls, no rate / cost caps.

**Mitigation guidelines.** Least Agency + Least Privilege per tool; action-level authentication and human approval for destructive calls; sandboxes with egress allowlists; policy enforcement middleware ("intent gate"); adaptive budgets with automatic revocation; just-in-time / ephemeral access; semantic + identity validation of tool names; immutable logs and drift detection.

---

## ASI03 — Identity and Privilege Abuse

**Description.** Dynamic trust and delegation in agents are exploited to escalate access by manipulating delegation chains, role inheritance, control flows and agent context (which includes cached credentials and conversation history). Maps to T3 Privilege Compromise.

**What to look for in code.**

- *Affirmative signals.*
  - Per-agent identities (mTLS, scoped tokens) with short-lived credentials per task.
  - Per-session sandboxes with separated permissions; memory wiped between tasks / users.
  - Per-action authorization checked against a centralised policy engine.
  - OAuth / token use bound to a *signed intent* (subject, audience, purpose, session).
  - Re-authentication required on context switch; no privilege inheritance across agents without re-validating original intent.
  - Detection of delegated / transitive permissions and abnormal cross-agent privilege elevation.
- *Risk signals.*
  - Long-lived API keys hard-coded in agent configuration.
  - Single shared service-account credential used by all agent runs and all users.
  - Memory / cache that persists credentials across sessions or users.
  - Sub-agent ("tool-using" agent) that inherits the caller's full token rather than receiving a scoped sub-token.
  - "Agent → agent" trust where internal requests are accepted without identity attestation.
  - TOCTOU patterns: permission validated once at workflow start, then reused.

**Verdict rubric.**

- `Mitigated` — agents have distinct, scoped identities; tokens are short-lived; per-action authorization is enforced; memory is cleared between sessions.
- `Partial` — agents have some identity separation but credentials are long-lived or shared.
- `Exposed` — single hard-coded credential, no per-session isolation, sub-agents inherit full caller rights.

**Mitigation guidelines.** Task-scoped, time-bound permissions; per-agent identities with short-lived credentials; isolated per-session sandboxes; per-action authorization; human-in-the-loop for privilege escalation; bind tokens to signed intent; detect transitive permission inheritance.

---

## ASI04 — Agentic Supply Chain Vulnerabilities

**Description.** Tools, agents, plug-ins, datasets, MCP / A2A interfaces, agentic registries and update channels can be malicious, compromised or tampered with. Unlike static dependencies (LLM03), agentic ecosystems compose capabilities at runtime, expanding the attack surface to a "live supply chain".

**What to look for in code.**

- *Affirmative signals.*
  - SBOM / AIBOM artefacts checked into the repo; CI verifies signatures and provenance.
  - Pinned dependency versions (`requirements.txt` with `==`, `package-lock.json`, `pnpm-lock.yaml`, `poetry.lock`, `uv.lock`).
  - Allowlist of trusted package registries; CI rejects unsigned / unverified artefacts.
  - MCP / A2A endpoints configured as a fixed allowlist with mTLS or signed agent cards.
  - Tool descriptors and prompt templates loaded only from version-controlled paths (not fetched at runtime).
  - Reproducible builds; "kill switch" pattern to instantly disable a specific tool / prompt / agent connection.
- *Risk signals.*
  - Unpinned versions (`>=`, `^`, `~`, `latest`).
  - MCP server URL or A2A endpoint configurable at runtime from environment / user input without verification.
  - Prompt templates fetched over HTTP from external URLs at startup.
  - `npm install` / `pip install` happening inside agent execution (live install).
  - Direct use of public registries (`npmjs.org`, `pypi.org`) without proxy / allowlist.
  - No content-hash pinning of MCP tool descriptors.

**Verdict rubric.**

- `Mitigated` — dependencies are pinned, lockfiles committed, signatures verified in CI, MCP / A2A allowlisted with mTLS, no runtime fetch of templates / tools.
- `Partial` — lockfiles present but registries are unrestricted; or MCP endpoints allowlisted but prompts still loaded over HTTP.
- `Exposed` — unpinned dependencies, runtime template fetch, MCP endpoints accept any URL.

**Mitigation guidelines.** Provenance + SBOMs / AIBOMs; dependency gatekeeping with pinning and typosquat scans; sandboxed containers with strict network limits; version-controlled prompts and memory schemas; mutual auth + attestation between agents (PKI, mTLS); continuous re-validation of signatures at runtime; content-hash + commit-ID pinning; supply-chain kill switch.

---

## ASI05 — Unexpected Code Execution (RCE)

**Description.** Agents that generate or execute code (vibe coding tools, code-interpreter agents) can be steered by prompt injection or unsafe serialisation into running attacker-controlled code, leading to host / container compromise, persistence, or sandbox escape.

**What to look for in code.**

- *Affirmative signals.*
  - Generated code runs only inside sandboxes (`mcp-run-python`, gVisor, Docker-with-no-egress, dedicated VMs).
  - Filesystem access restricted to a dedicated working directory; file diffs logged on critical paths.
  - Static analysis / linting on generated code before execution.
  - Allowlist of auto-runnable commands kept under version control; everything else requires human approval.
  - Separation of code-generation step from code-execution step with a validation gate in between.
  - No `eval()` / `exec()` of model output without taint tracking.
- *Risk signals.*
  - `eval(model_output)`, `exec(...)`, `Function(...)` constructor on LLM output.
  - `subprocess.run(...,  shell=True)` with strings interpolated from model output.
  - `pickle.loads` / `yaml.load` (without `SafeLoader`) on data that originated from a model or untrusted source.
  - Code-execution tools running as `root` or as the application's main service account.
  - Auto-install of packages (`pip install $name`) where `$name` is model-generated.
  - File-write tools that accept arbitrary absolute paths.

**Verdict rubric.**

- `Mitigated` — codegen and execution are isolated, sandboxed, non-root, with allowlists and human approval for novel commands.
- `Partial` — some sandboxing but with overly broad host access (e.g. host filesystem mounted into sandbox).
- `Exposed` — direct `eval` / `subprocess shell=True` on model output, or unsafe deserialisation of untrusted payloads.

**Mitigation guidelines.** Follow LLM05:2025 output handling; pre-production checks for vibe coding; ban `eval` in production; never run as root; isolate per-session environments; require human approval for elevated runs; static scans before execution; runtime monitoring and audit of all generation + runs.

---

## ASI06 — Memory & Context Poisoning

**Description.** Adversaries corrupt the agent's stored / retrievable context (RAG store, summaries, embeddings, long-term memory) so future reasoning, planning or tool use becomes biased, unsafe or aids exfiltration. Distinct from ASI01 (active goal hijack) — ASI06 is *persistent* corruption.

**What to look for in code.**

- *Affirmative signals.*
  - Vector stores configured with per-tenant / per-user namespaces; retrieval filters by namespace.
  - Memory writes scanned (rules + AI) for malicious / sensitive content before commit.
  - Source attribution / provenance metadata stored alongside each memory entry.
  - Trust scoring on memory entries; low-trust entries decay or expire.
  - Snapshot / rollback / version control of memory and prompt schemas.
  - Block on automatic re-ingestion of an agent's own outputs into trusted memory.
  - Encryption in transit and at rest for memory stores; least-privilege IAM on the vector DB.
- *Risk signals.*
  - Vector store queries that don't filter by tenant / user namespace.
  - RAG ingestion pipelines that accept arbitrary uploads with no content scanning.
  - Memory writes from untrusted sources (peer agents, user uploads) with no provenance tag.
  - Long-lived shared memory across users with no segmentation.
  - Auto-ingestion of agent outputs into the same store the agent retrieves from.
  - Vector DB credentials shared across all agents with full read-write rights.

**Verdict rubric.**

- `Mitigated` — namespaced memory, scanned writes, provenance + trust scores, snapshots and rollback.
- `Partial` — namespaces in place but writes unfiltered; or scanning in place but no rollback.
- `Exposed` — shared global memory, unfiltered writes from untrusted sources, no provenance.

**Mitigation guidelines.** Encrypt + least-privilege; scan memory writes; segment memory; allow only authenticated curated sources; record provenance and detect anomalies; prevent self-output re-ingestion; expire unverified memory; weight retrieval by trust + tenancy.

---

## ASI07 — Insecure Inter-Agent Communication

**Description.** Multi-agent systems coordinate via APIs, message buses and shared memory. Weak inter-agent controls (auth, integrity, confidentiality, authorization) allow attackers to intercept, manipulate, spoof or block messages — affecting transport, routing, discovery and semantic layers, including covert side channels.

**What to look for in code.**

- *Affirmative signals.*
  - End-to-end encryption (TLS / mTLS) on all inter-agent channels.
  - Per-agent credentials and mutual authentication; PKI certificate pinning.
  - Digitally signed messages with payload + context hash; signature verified before processing.
  - Nonces, session identifiers and timestamps on every message; replay protection.
  - Versioned, typed message schemas with explicit per-message audiences; reject schema down-conversion.
  - Authenticated discovery / coordination messages; verified agent registries.
- *Risk signals.*
  - Inter-agent calls over plain HTTP, unauthenticated WebSockets or unsigned message buses.
  - Agent IDs taken from request bodies without verification.
  - "Internal" calls trusted by default with no mutual auth.
  - Free-form natural language passed between agents with no schema validation.
  - No replay protection / no nonce.
  - Agent discovery from `.well-known/agent.json` or similar registry without signature verification.

**Verdict rubric.**

- `Mitigated` — mTLS + signed messages + replay protection + signed discovery.
- `Partial` — TLS but no message signing, or signing but no replay protection.
- `Exposed` — plain HTTP between agents, internal-trust shortcuts, no schema validation.
- `Not applicable` — single-agent codebase with no peer-agent calls.

**Mitigation guidelines.** Secure agent channels (mTLS + per-agent credentials); message integrity + semantic protection; agent-aware anti-replay; protocol + capability security; reduce metadata-based inference; protocol pinning and version enforcement; authenticated discovery; attested registries; typed schemas.

---

## ASI08 — Cascading Failures

**Description.** A single fault (hallucination, malicious input, corrupted tool, poisoned memory) propagates across autonomous agents, compounding into system-wide harm. ASI08 focuses on the *propagation* — the initial defect lives under ASI04/06/07. Symptoms: rapid fan-out, cross-tenant spread, oscillating retries, queue storms.

**What to look for in code.**

- *Affirmative signals.*
  - Circuit breakers between planner and executor; bulkhead patterns isolating agent groups.
  - Quotas / progress caps / blast-radius caps on agent runs.
  - Independent policy enforcement: planning and execution separated by an external policy engine.
  - Idempotency keys on all destructive operations.
  - Tamper-evident, time-stamped logs bound to cryptographic agent identities; lineage metadata on each propagated action.
  - Rate-limit + anomaly detection on agent-to-agent message rates.
- *Risk signals.*
  - Planner emits steps that the executor performs without an intermediate validation step.
  - No global rate limit on agent loops or fan-out.
  - Agents persist plans into long-term memory without TTL or rollback.
  - Auto-deploy / auto-apply pipelines triggered by agent output without staged rollout.
  - Two agents that read each other's outputs in a loop with no convergence check.

**Verdict rubric.**

- `Mitigated` — quotas, circuit breakers, planner / executor separation, lineage logs, idempotency in place.
- `Partial` — some controls but no end-to-end blast-radius bound.
- `Exposed` — no rate limits, planner→executor coupling without validation, no idempotency.

**Mitigation guidelines.** Zero-trust design with availability-failure assumption; isolation + trust boundaries (sandbox, segmentation, scoped APIs, mutual auth); just-in-time, one-time tool access with runtime checks; independent policy enforcement separating planning and execution; output validation + human gates; rate limiting + monitoring; blast-radius guardrails (quotas, circuit breakers); behavioural drift detection; digital-twin replay; tamper-evident logs.

---

## ASI09 — Human-Agent Trust Exploitation

**Description.** Agents establish trust with humans through fluency, emotional intelligence and perceived expertise. Adversaries (or misaligned designs) exploit this — using authority bias, fake explainability, anthropomorphic cues — to influence user decisions, extract secrets or steer outcomes. The agent acts as an untraceable "bad influence" whose role in the compromise is invisible to forensics.

**What to look for in code.**

- *Affirmative signals.*
  - Explicit confirmation step / "human in the loop" required for sensitive data access or risky actions.
  - Tamper-proof / append-only audit log of user queries and agent actions.
  - Risk-summary display (plain language, not model-generated rationale) before sensitive actions.
  - Provenance metadata (source identifier, timestamp, integrity hash) on agent recommendations.
  - Preview-vs-execute separation: preview blocks any network or state-changing calls; visual risk badge on high-risk recommendations.
  - Plan-divergence detection: alerts when agent action sequences deviate from approved workflow baselines.
  - User mechanism to flag suspicious / manipulative agent behaviour; lockdown trigger.
- *Risk signals.*
  - Single-prompt → irreversible action pattern (transfer, delete, deploy) with no confirmation.
  - User-facing rationales generated by the same model executing the action (self-audit).
  - Preview interactions that fire webhooks / mutations (consent laundering).
  - Persuasive / emotionally loaded language in safety-critical confirmations.
  - No provenance or source attribution shown alongside the agent's recommendation.

**Verdict rubric.**

- `Mitigated` — confirmations on sensitive actions, immutable audit log, preview-vs-execute separation, provenance + risk badges, plan-divergence detection.
- `Partial` — confirmations on some actions but not all; or audit log present but mutable.
- `Exposed` — irreversible actions auto-execute on agent recommendation without separate confirmation.

**Mitigation guidelines.** Explicit confirmations for sensitive actions; immutable logs; behavioural detection of risky executions; user-reporting + lockdown; adaptive trust calibration; content provenance + policy enforcement; preview / effect separation; human-factors UI safeguards (risk badges, warnings); plan-divergence detection.

---

## ASI10 — Rogue Agents

**Description.** Malicious or compromised agents deviate from their intended function. External compromise (prompt injection, goal hijack, supply chain) may *initiate* the divergence — ASI10 focuses on the loss of behavioural integrity once drift begins. Consequences: data exfiltration, misinformation, workflow hijacking, sabotage.

**What to look for in code.**

- *Affirmative signals.*
  - Comprehensive immutable + signed audit logs of agent actions, tool calls and inter-agent comms.
  - Trust zones with strict inter-zone communication rules; sandboxed execution environments per zone.
  - Watchdog / observer agent that validates peer behaviour and outputs.
  - Rapid containment: kill-switch + credential revocation mechanism.
  - Per-agent cryptographic identity attestation; signed behavioural manifest declaring expected capabilities, tools, goals.
  - Continuous behavioural verification against the manifest; alerts on deviation.
  - Periodic behavioural attestation / challenge tasks.
  - Agents never directly hold long-lived signing keys — orchestrator mediates signing operations.
- *Risk signals.*
  - No central audit log of agent actions, or logs only in mutable storage.
  - No mechanism to disable a specific agent without redeploy.
  - Agents share a service account with full production access.
  - No detection for an agent calling a tool outside its declared capability set.
  - Long-lived signing keys held by the agent process itself.

**Verdict rubric.**

- `Mitigated` — signed manifests, behavioural verification, kill-switch, watchdog, immutable logs.
- `Partial` — logs and isolation in place but no behavioural manifest or kill-switch.
- `Exposed` — no audit, no kill-switch, no per-agent identity.
- `Not applicable` — single-agent system with no autonomous behaviour beyond a single tool call.

**Mitigation guidelines.** Governance + immutable signed logs; isolation + trust zones; behavioural detection (watchdog agents, anomaly monitoring); containment + response (kill switches, credential revocation); identity attestation + behavioural integrity enforcement; periodic behavioural attestation with HSM/KMS-backed keys mediated by the orchestrator; recovery + reintegration with fresh attestation and human approval.

---

## How the rubric translates to severity

The skill assigns a *severity* per ASI based on the verdict and the codebase's blast radius:

| Verdict       | Default severity | Adjust **up** if … | Adjust **down** if … |
|---------------|------------------|---------------------|----------------------|
| `Exposed`     | High             | the agent has access to production data, money movement, customer PII, or RCE-capable tools | the agent runs on synthetic data only, no external integrations |
| `Partial`     | Medium           | the gap is on a high-impact action path | the gap is on a low-stakes action and other compensating controls exist |
| `Mitigated`   | Low              | (rarely raised)     | (often dropped to Informational) |
| `Unknown`     | Medium           | the missing evidence is on a high-impact path | the missing evidence is on a low-stakes path |
| `Not applicable` | —              | n/a                 | n/a                  |

`Not applicable` is the correct verdict for ASIs that depend on architecture choices the codebase has not made (e.g. ASI07 on a single-agent codebase, ASI10 on a non-autonomous LLM call). Don't pad the report with `Mitigated` for things that simply don't exist in the code.

## Detection-pattern crib sheet

Common file / pattern signals to grep for during Phase 2 (codebase discovery). These are *agentic-app fingerprints* — finding any of them upgrades the relevance of every ASI entry.

| Signal | Indicates |
|----|----|
| `from anthropic import …`, `claude_agent_sdk`, `Claude(`, `tool_choice` | Anthropic Claude API / Agent SDK |
| `openai.beta.assistants`, `Runs.create`, `tool_resources` | OpenAI Assistants / Agents |
| `from langchain`, `from langgraph`, `AgentExecutor`, `ChatPromptTemplate`, `Tool(` | LangChain / LangGraph |
| `from llama_index`, `QueryEngine`, `AgentRunner` | LlamaIndex |
| `from autogen`, `GroupChat`, `ConversableAgent` | AutoGen |
| `from crewai`, `Crew(`, `Task(`, `Agent(` | CrewAI |
| `mcp.server`, `mcp.client`, `ServerCapabilities`, `Tool(` (in MCP context), `@mcp.tool` | Model Context Protocol |
| `agent2agent`, `a2a`, `well-known/agent.json` | A2A protocol |
| `chromadb`, `pinecone`, `weaviate`, `qdrant`, `pgvector`, `Faiss` | Vector store / RAG |
| `eval(`, `exec(`, `subprocess.run(.*shell=True`, `os.system(`, `pickle.loads`, `yaml.load(` (without `SafeLoader`) | Code-execution risk surface |
| `==`, `^`, `~`, `latest` in dependency files | Pinning posture |
| `requirements.txt`, `package-lock.json`, `pnpm-lock.yaml`, `poetry.lock`, `uv.lock`, `Pipfile.lock` | Dependency manifests / lockfiles |
| `human_input`, `confirm`, `dry_run`, `--yes`, `interactive` | Confirmation patterns |
| `audit_log`, `logger`, `logging.info`, `structlog` | Logging surface |

## Source

- *OWASP Top 10 For Agentic Applications 2026* — OWASP GenAI Security Project, Agentic Security Initiative, December 2025. Plain-text extraction at `owasp-top10-source-extract.txt`.
- License: CC BY-SA 4.0.
