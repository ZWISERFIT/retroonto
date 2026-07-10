# RetroOnto — Decision Ontology for Multi-Agent Systems

> **Git tells you how code changed. RetroOnto tells you how your agents decided — and prevents them from making the same mistake twice.**

RetroOnto is an open-source **decision archive and governance system** for multi-agent AI deployments. It records every agent decision, auto-classifies failures, derives permanent prevention rules, and gates future agent outputs against known mistakes.

## Why?

When a single AI agent makes a mistake, you fix the prompt. When **multiple agents** make 200+ decisions daily across weeks of autonomous operation, the failure mode isn't a bad prompt — it's **error compounding**.

Agent A misclassifies a result → Agent B builds strategy on false data → Agent C executes bad strategy → By the time a human notices, the compound error has cost 10× the original mistake.

**RetroOnto breaks this chain.**

## Architecture

```
Raw Event → Classification → Derivation Chain → Resolution → Encoded Rule
```

| Tier | What | Example |
|:-----|:-----|:--------|
| **E0** | Raw event | "Agent reports VC status as pending" |
| **E1** | Classification | Memory failure (didn't check source of truth before output) |
| **E2** | Derivation chain | Checked memory → found cached state → missed recent update |
| **E3** | Resolution | Gate intercepts → cross-references tracker → corrects |
| **E4** | Encoded rule | "Capital status output MUST read source of truth first" |

Each tier is queryable via FTS5 full-text search. The entire system runs on a **single SQLite database** — no vector DB, no external service, no cloud dependency.

## Core Components

### 1. Archive — Immutable Experience Database

Structured error/success entries with YAML frontmatter:

```yaml
---
id: ERR-001
type: error
category: infrastructure
severity: 🔴
status: active
created: 2026-07-10
source_agent: supervisor
verified_by: audit
---
```

Organized into `errors/`, `successes/`, `patterns/`, and `curated/` — a Wiki-like structure mirroring the LLM Wiki paradigm.

### 2. Trace Chain — Capture → Archive → Constrain

| Script | Priority | Function |
|:-------|:---------|:---------|
| `trace.sh` | P0 | Capture failure event → Archive + broadcast |
| `writeback.sh` | P1 | Pattern → permanent knowledge ring |
| `constraint-gen.sh` | P2 | Pattern matching → auto-constraint generation |

### 3. Ferrum Gate — Runtime Constraint Execution

Executable constraints that pre-check agent outputs against known failure patterns:

```
ferrum-gate → scans output → checks constraints → PASS/BLOCK
```

### 4. Knowledge Ring — Cross-Agent Immune System

Encoded constraints auto-write to a permanent knowledge layer shared across all agents. Each mistake makes the entire system permanently smarter — the AI equivalent of herd immunity.

## Quick Start

```bash
git clone https://github.com/ZWISERFIT/retroonto.git
cd retroonto

# Initialize the archive
sqlite3 retroonto.db < docs/schema.sql

# Run your first trace
./src/trace.sh --type error --category infrastructure --desc "Your description"

# Check constraints
./src/ferrum-gate.sh list
```

### Docker

```bash
docker build -t retroonto .
docker run -v $(pwd)/data:/data retroonto
```

## The Academic Anchor

RetroOnto extends the behavioral sequence paradigm described in:
- **USER-LLM** (Google Research, arXiv 2402.13598, 2024) — User behavior compression → LLM injection
- **Agent-as-a-Service** (Microsoft, arXiv 2307.07978) — Multi-agent governance patterns
- **Decision Transformer** (Chen et al., 2021) — Decision sequence modeling

Where these papers describe the theory, RetroOnto provides a production implementation for multi-agent governance.

## Use Cases

- **Multi-agent teams**: Prevent error compounding across autonomous agents
- **AI pipeline governance**: Gate model outputs against known failure patterns
- **Agent observability**: Query what any agent decided, when, and why
- **Post-mortem automation**: Every failure auto-generates a permanent prevention rule

## Roadmap

- [x] Archive system (errors/successes/patterns)
- [x] Trace chain (capture → constrain → writeback)
- [x] Ferrum gate (runtime constraint execution)
- [x] Knowledge ring (cross-agent immune writeback)
- [ ] CLI v1.0 (zwf-memory.sh)
- [ ] Docker one-command start
- [ ] Web dashboard
- [ ] API server
- [ ] Community constraint marketplace

## License

MIT

## Related

- [USER-LLM: Large Language Models as User Agents](https://arxiv.org/abs/2402.13598)
- [Decision Transformer](https://arxiv.org/abs/2106.01345)
- [LLM Wiki paradigm](https://gist.github.com/karpathy/2560834d95e3fe5e1b74de1f022541b2)
