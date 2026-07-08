# RetroOnto — A Decision Ontology for Multi-Agent Systems

> *Every error in multi-agent coordination compounds into positive ROI — if you have an ontology to capture it.*

## What Problem Does RetroOnto Solve?

Multi-agent systems produce thousands of decisions daily. Most of these decisions are ephemeral — made, executed, forgotten. When an error repeats across agents, it's rarely caught until someone manually connects the dots. The result is **fragmented decision traces, repeated same-pattern errors, and no structured mechanism for collective learning**.

RetroOnto provides:

- A **five-tier derivation chain** that traces every error from surface symptom → root cause → correction → encoded rule → compound learning
- **Full-text search** across all decision traces and organizational wiki entries (via SQLite FTS5)
- An **output gate protocol** that checks every agent output against the ontology before delivery
- A **seed dataset** of 3 real, de-identified decision traces from multi-agent autonomous operations

## Quickstart

### Option A: Docker (recommended)

```bash
docker run --rm -it retroonto:latest stats
```

This will pull the latest image, initialize the database with FTS5 indexes and seed data, and display statistics of the knowledge base.

### Option B: CLI (no Docker)

```bash
# Requirements: sqlite3 (with FTS5 support, built-in since 3.9.0)
sqlite3 zwf-knowledge.db < src/schema.sql
sqlite3 zwf-knowledge.db -cmd ".import --json data/seed-traces.json decision_traces" ".quit"
sqlite3 zwf-knowledge.db "SELECT COUNT(*) AS decision_traces_loaded FROM decision_traces;"
```

### Option C: With zwf-memory.sh CLI

```bash
# After initializing the database
bash zwf-memory.sh stats          # View database statistics
bash zwf-memory.sh search "error" # Full-text search across all traces
```

## Repository Structure

```
retroonto-repo/
├── README.md               # This file
├── LICENSE                 # MIT License
├── data/
│   └── seed-traces.json    # 3 de-identified decision traces
├── src/
│   └── schema.sql          # SQL schema (SQLite, FTS5, triggers)
├── docs/
│   └── ontology-spec.md    # RetroOnto decision ontology specification
├── Dockerfile              # One-click Docker setup
└── docker-compose.yml      # Docker Compose configuration
```

## Data Sources

The seed traces are from 120+ days of real multi-agent autonomous operations. All traces have been de-identified — no personal data, financial data, or internal agent communications are included. The dataset captures three categories of structural errors:

1. **Memory failure**: Agent relying on session memory instead of querying an authoritative source
2. **Methodology defect**: Rule systems designed from theory rather than actual data
3. **Systemic deficiency**: Missing single source of truth for cross-agent shared state

## Relationship to ZWISERFIT

RetroOnto is built and maintained by the team behind ZWISERFIT — an AI-native fitness company that operates autonomous agent systems at production scale. The ontology and tooling emerged organically from the operational experience of managing real multi-agent coordination failures. RetroOnto is open-source and independent of any ZWISERFIT product or service.

## License

MIT — see [LICENSE](./LICENSE).

## Citation

```bibtex
@software{retroonto2026,
  title = {RetroOnto: A Decision Ontology for Multi-Agent Systems},
  year = {2026},
  url = {https://github.com/zwiserfit/retroonto}
}
```
