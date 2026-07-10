# RetroOnto Ontology Specification v1.0

## Five-Tier Derivation Chain

RetroOnto models every agent decision through a five-tier ontology:

### E0 — Raw Event
The unprocessed observation. What happened, when, and which agent.

**Fields:** `event_id`, `timestamp`, `source_agent`, `raw_description`, `event_type`

### E1 — Classification
Categorization of the event into a failure/success type.

**Categories:**
- `infrastructure` — Network, hardware, system failures
- `coordination` — Inter-agent communication, handoff, dependency failures
- `cognitive` — Hallucination, memory mismatch, reasoning errors

**Severity:**
- `🔴` — Fatal: System halt, data loss, cascading failures
- `🟡` — Critical: Degraded operation, incorrect output, wasted tokens
- `🟢` — Minor: Inefficiency, style issues, non-functional concerns

### E2 — Derivation Chain
The causal chain. How did this happen?

A sequence of:
1. Precondition (what state was the system in?)
2. Trigger (what specific action/event started this?)
3. Propagation (how did the error travel through the system?)
4. Detection (how/when was it caught?)

### E3 — Resolution
The corrective action taken.

**Resolution types:**
- `auto_gate` — Blocked by runtime gate before reaching output
- `agent_self_correct` — Agent identified and fixed its own error
- `peer_review` — Another agent caught and corrected this
- `human_intervention` — Human operator corrected the output
- `system_heal` — Automated healing protocol restored state

### E4 — Encoded Rule
The permanent prevention mechanism.

**Rule types:**
- `executable` — Shell script or gate command that auto-checks
- `constitutional` — Agent SOUL.md / AGENTS.md amendment
- `process` — Workflow or sequence change
- `infrastructure` — System config, cron, or service change

## Archive Layout

```
archive/
├── errors/
│   ├── infrastructure/
│   ├── coordination/
│   └── cognitive/
├── successes/
│   ├── infrastructure/
│   ├── coordination/
│   └── cognitive/
├── patterns/
│   └── (cross-case abstractions)
└── curated/
    └── (verified high-confidence entries)
```

## Constraint Format

```yaml
constraint:
  id: C-XXX
  name: constraint-name
  description: "What this constraint prevents"
  source: ERR-XXX
  type: executable|manual|pattern
  check: "Command or condition to verify"
  severity: 🔴|🟡|🟢
```

## Knowledge Ring Writeback

Encoded constraints are written to a shared permanent knowledge layer. The writeback is idempotent and includes:

- Source trace ID
- Original error description
- Encoded constraint
- Timestamp
- Written by which agent
