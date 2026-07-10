# RetroOnto Decision Ontology Specification

> *Version 1.0 | July 2026*

## 1. Overview

RetroOnto defines a **five-tier derivation chain** for capturing, analyzing, and compounding learning from multi-agent decision errors. Each trace in the ontology represents a complete lifecycle — from surface symptom through structural fix to system-wide compound learning.

The ontology is designed for **autonomous agents** as its primary consumers. Every field is structured for programmatic query, pattern matching, and automated gate checks.

## 2. Five-Tier Derivation Chain

Every RetroOnto decision trace follows this chain:

```
Tier 1: Symptom (what happened)
    ↓
Tier 2: Root Cause (why it happened)
    ↓
Tier 3: Correction (what was done to fix it)
    ↓
Tier 4: Encoded Rule (how the fix was made permanent)
    ↓
Tier 5: Compound Learning (what systemic change prevents reoccurrence)
```

### 2.1 Tier 1 — Symptom (`event_name` + `context` + `decision_made`)

The observable error or anomaly. Every trace must capture:
- **What was claimed/decided** (`decision_made`): The erroneous statement or decision
- **What was actually true** (`actual_state`): The ground truth at time of error
- **When it occurred** (`date`): When the error was made or detected
- **Which agent** (`agent`): The agent(s) involved

### 2.2 Tier 2 — Root Cause (`root_cause`)

The underlying structural or behavioral cause. Root causes are classified into categories:

| Category | Description | Example |
|---|---|---|
| `memory_failure` | Agent relied on session memory instead of querying an authoritative source | "凭 session 记忆声明 a16z 状态" |
| `insufficient_coverage` | Detection/validation system missed real errors due to under-designed rules | "v1.0 触发覆盖率仅 0.1%" |
| `source_of_truth_missing` | No single authoritative source for shared cross-agent state | "基础设施状态没有单一权威源" |
| `methodology_defect` | Rule/process designed from theory rather than data | "规则基于理论假设而非实际数据" |
| `coordination_failure` | Agents operated with inconsistent state perceptions | "不同Agent状态认知产生漂移" |

### 2.3 Tier 3 — Correction (`correction`)

The concrete action taken to resolve the current instance of the error. A correction must be:
- **Executable**: Clear enough for another agent to apply
- **Specific**: Named files, commands, or processes involved
- **Temporal**: Tied to the specific incident, not a general principle

### 2.4 Tier 4 — Encoded Rule (`rule_added`)

The **permanent guardrail** that prevents reoccurrence. A rule must be:
- **Machine-readable**: Written in the agent's SOUL.md, config file, or code
- **Triggered automatically**: Not requiring human recall or initiative
- **Anchored to evidence**: References the file/source that is the authoritative truth

Example rules:
```
SOUL.md → 🔴 Self-check (runtime-triggered): Before declaring any capital status,
force-read the tracker, compare item-by-item, attach evidence anchor.
```

### 2.5 Tier 5 — Compound Learning (`learning_compound` + `trace_json.generalization`)

The **generalized principle** extracted from the error pattern, applied across the entire system. Compound learning is the mechanism by which a single error's fix benefits all agents.

A trace is flagged as `learning_compound = 1` when:
- The same error pattern is eliminated for **all agents**, not just the one that caused it
- A **new process or protocol** is created that prevents an entire class of errors
- The fix is cross-domain (e.g., a capital-report fix generalized to all "session memory claims")

## 3. Trace Schema

### 3.1 Core Fields (SQLite `decision_traces` table)

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | INTEGER | ✓ | Auto-incrementing primary key |
| `event_name` | TEXT | ✓ | Human-readable event name (e.g., "a16z 第7次同模式错误") |
| `agent` | TEXT | ✓ | Agent that made the error (e.g., "Zeus") |
| `error_type` | TEXT | ✓ | Categorization per Tier 2 taxonomy |
| `context` | TEXT | | Full context for the decision |
| `decision_made` | TEXT | | What was erroneously decided/claimed |
| `root_cause` | TEXT | | Tier 2: Root cause analysis |
| `correction` | TEXT | | Tier 3: Immediate corrective action |
| `rule_added` | TEXT | | Tier 4: Permanent encoded rule |
| `learning_compound` | INTEGER | | 1 = compound learning achieved, 0 = isolated fix |
| `trace_json` | TEXT | | Tier 2/5: Detailed structured trace data |
| `created_at` | TEXT | | Auto-set on insert |

### 3.2 `trace_json` Sub-Schema

The `trace_json` field contains structured data that varies by error category but always includes:

```json
{
  "iterations": [
    {"date": "YYYY-MM-DD", "error": "description", "detected_by": "agent/human", "fixed": false}
  ],
  "category": "classification_tag",
  "lesson_type": "structural|case_specific",
  "generalization": "System-wide principle derived from this trace"
}
```

For compound learning traces, the `generalization` field captures the Tier 5 output.

## 4. Query & Discovery Patterns

### 4.1 Full-Text Search

RetroOnto uses SQLite FTS5 for full-text search across all trace fields:

```sql
-- Search decision traces
SELECT d.id, d.event_name, d.agent, d.error_type,
       substr(d.root_cause,1,80) AS root_cause,
       d.learning_compound, d.created_at
FROM traces_fts f JOIN decision_traces d ON f.rowid = d.id
WHERE traces_fts MATCH 'memory_failure';

-- Search organizational wiki
SELECT w.id, w.category, w.source_agent,
       substr(w.content,1,80) AS snippet
FROM wiki_fts f JOIN wiki_entries w ON f.rowid = w.id
WHERE wiki_fts MATCH 'source_of_truth';
```

### 4.2 Pattern Queries

```sql
-- Find all compound learnings (Tier 5 achieved)
SELECT event_name, agent, error_type, correction
FROM decision_traces
WHERE learning_compound = 1;

-- Find recurring error patterns
SELECT error_type, COUNT(*) AS occurrences,
       COUNT(DISTINCT agent) AS agents_involved
FROM decision_traces
GROUP BY error_type
ORDER BY occurrences DESC;

-- Find errors by category with generalization
SELECT event_name, trace_json ->> '$.generalization' AS generalization
FROM decision_traces
WHERE learning_compound = 1;
```

## 5. Output Gate Protocol

The output gate is a mandatory check that runs before any agent output is delivered:

```
1. Is the output making any factual claim about external/system state?
   → YES: Check wiki_entries for relevant category. If no entry found, flag.
2. Is the output a decision?
   → YES: Check decision_traces for similar error_type patterns. If match > 0.7, flag.
3. Is the output referencing infrastructure state?
   → YES: Force-read infrastructure-status.json. Verify consistency.
4. Was a check performed?
   → Log to gate_log with passed=1 or passed=0.
```

## 6. Data Provenance

All decision traces must include:

- **Agent identity**: Which agent made/reported the error
- **Detection mechanism**: How was the error discovered (human report, automated check, cross-validation)
- **Correction authority**: Who validated the correction (human, senior agent, consensus)
- **Timeline**: First occurrence, last occurrence, correction date

## 7. Schema Versioning

- Current schema version: **v1.0**
- Backward compatibility: New fields are added as nullable columns; existing FTS indexes are rebuilt on migration
- Migration path: Incremental schema updates via `ALTER TABLE`; FTS triggers auto-sync

## 8. Academic Anchors

RetroOnto's core architecture — behavioral sequence compression → structured representation → governance enforcement — is independently validated by parallel research in user behavior modeling.

### 8.1 USER-LLM: Behavioral Sequence Compression (Google Research, 2024)

**Paper:** *User-LLM: Efficient LLM Contextualization with User Embeddings* (Ning et al., arxiv 2402.13598)

**Key insight:** Raw user interaction sequences cannot be efficiently fed to LLMs as text prompts — they must be compressed into a distinct representation ("fifth modality") that preserves temporal signal while discarding noise. The user encoder compresses entire interaction histories into fixed-dimension embeddings, achieving 78.1× inference speedup.

**Parallel to RetroOnto:** RetroOnto applies the same behavioral compression paradigm to *agent* decision sequences. Instead of embedding vectors, RetroOnto compresses decision traces into *structured rules* (Tier 4) and *generalized principles* (Tier 5) — achieving constant-time governance checks at output time via SQL FTS and grep-based gate scanning.

| Dimension | USER-LLM | RetroOnto |
|---|---|---|
| Behavioral subject | Human users | Autonomous agents |
| Sequence source | Clicks, searches, media consumption | Decisions, errors, corrections |
| Compression target | Embedding vectors (cross-attention) | Structured rules + SQL FTS indexes |
| Temporal signal | User interest drift | Error compound patterns |
| Inference efficiency | 78.1× vs text-prompt | O(1) gate scan vs o(n) manual review |
| End goal | Personalized LLM responses | Autonomous agent governance |

**RetroOnto's parallel claim:**
> "We treat multi-agent decision traces as a distinct modality for organizational learning — where USER-LLM compresses human behavior for personalization, RetroOnto compresses agent behavior for governance."

### 8.2 Multi-Agent Governance Gap

Existing multi-agent frameworks (LangChain, CrewAI, AutoGen) address task routing, communication protocols, and tool sharing — but none provide a structured mechanism for **decision governance**: the ability to encode agent errors as permanent, machine-readable rules that prevent reoccurrence across the entire agent fleet.

RetroOnto fills this gap with the **Agent Decision Governance Layer**. It is not a task orchestrator — it is a governance audit trail that sits alongside any multi-agent runtime.

## References

- [SQLite FTS5 Documentation](https://www.sqlite.org/fts5.html)
- [src/schema.sql](../src/schema.sql) — Canonical schema definition
- [data/seed-traces.json](../data/seed-traces.json) — Example traces following this ontology
- [USER-LLM: Efficient LLM Contextualization with User Embeddings](https://arxiv.org/abs/2402.13598) — Ning et al., Google Research (2024)
- [RetroOnto Capital Narrative v1.0](https://github.com/zwiserfit/retroonto) — Trust signal density positioning
