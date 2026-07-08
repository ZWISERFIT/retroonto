-- =============================================================================
-- RetroOnto Schema — SQLite with FTS5
-- =============================================================================
-- This schema defines the ZWF (Zkittle-s-World Framework) unified knowledge
-- infrastructure for multi-agent decision tracing and organizational memory.
--
-- Tables:
--   wiki_entries      — Organizational wiki with FTS5 full-text search
--   decision_traces   — Decision ontology traces (the core RetroOnto dataset)
--   query_log         — Audit log of all queries made by agents
--   gate_log          — Output gate protocol records
--
-- Virtual Tables (FTS5):
--   wiki_fts          — Full-text index over wiki_entries
--   traces_fts        -- Full-text index over decision_traces
-- =============================================================================

-- ---------------------------------------------------------------------------
-- wiki_entries: Organizational wiki — facts, rules, operational knowledge
-- ---------------------------------------------------------------------------
CREATE TABLE wiki_entries (
    id INTEGER PRIMARY KEY,
    category TEXT NOT NULL,
    content TEXT NOT NULL,
    source_agent TEXT NOT NULL,
    source_session TEXT,
    verified_by TEXT,
    confidence REAL DEFAULT 1.0,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT
);

-- ---------------------------------------------------------------------------
-- decision_traces: The core RetroOnto table — 5-tier decision ontology traces
-- ---------------------------------------------------------------------------
CREATE TABLE decision_traces (
    id INTEGER PRIMARY KEY,
    event_name TEXT NOT NULL,
    agent TEXT NOT NULL,
    error_type TEXT NOT NULL,
    context TEXT,
    decision_made TEXT,
    root_cause TEXT,
    correction TEXT,
    rule_added TEXT,
    learning_compound INTEGER DEFAULT 0,
    trace_json TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

-- ---------------------------------------------------------------------------
-- query_log: Audit trail for all queries (for monitoring & analysis)
-- ---------------------------------------------------------------------------
CREATE TABLE query_log (
    id INTEGER PRIMARY KEY,
    agent TEXT NOT NULL,
    query TEXT NOT NULL,
    hit_table TEXT,
    hit_count INTEGER,
    timestamp TEXT DEFAULT (datetime('now'))
);

-- ---------------------------------------------------------------------------
-- gate_log: Output gate protocol — every agent output checked against ontology
-- ---------------------------------------------------------------------------
CREATE TABLE gate_log (
    id INTEGER PRIMARY KEY,
    agent TEXT NOT NULL,
    output_file TEXT NOT NULL,
    confidence_score REAL,
    checked_wiki BOOLEAN,
    checked_retroonto BOOLEAN,
    violations TEXT,
    passed BOOLEAN,
    timestamp TEXT DEFAULT (datetime('now'))
);

-- ---------------------------------------------------------------------------
-- FTS5 Indexes
-- ---------------------------------------------------------------------------

-- wiki_fts: Full-text search over wiki_entries
CREATE VIRTUAL TABLE wiki_fts USING fts5(
    content, category, source_agent,
    content=wiki_entries, content_rowid=id,
    tokenize='unicode61'
);

-- traces_fts: Full-text search over decision_traces
CREATE VIRTUAL TABLE traces_fts USING fts5(
    event_name, error_type, root_cause, correction, rule_added,
    content=decision_traces, content_rowid=id,
    tokenize='unicode61'
);

-- ---------------------------------------------------------------------------
-- Triggers: Keep FTS indexes in sync with content tables
-- ---------------------------------------------------------------------------

-- wiki_entries → wiki_fts sync
CREATE TRIGGER wiki_ai AFTER INSERT ON wiki_entries BEGIN
    INSERT INTO wiki_fts(rowid, content, category, source_agent)
    VALUES (new.id, new.content, new.category, new.source_agent);
END;

CREATE TRIGGER wiki_ad AFTER DELETE ON wiki_entries BEGIN
    INSERT INTO wiki_fts(wiki_fts, rowid, content, category, source_agent)
    VALUES('delete', old.id, old.content, old.category, old.source_agent);
END;

CREATE TRIGGER wiki_au AFTER UPDATE ON wiki_entries BEGIN
    INSERT INTO wiki_fts(wiki_fts, rowid, content, category, source_agent)
    VALUES('delete', old.id, old.content, old.category, old.source_agent);
    INSERT INTO wiki_fts(rowid, content, category, source_agent)
    VALUES (new.id, new.content, new.category, new.source_agent);
END;

-- decision_traces → traces_fts sync
CREATE TRIGGER traces_ai AFTER INSERT ON decision_traces BEGIN
    INSERT INTO traces_fts(rowid, event_name, error_type, root_cause, correction, rule_added)
    VALUES (new.id, new.event_name, new.error_type, new.root_cause, new.correction, new.rule_added);
END;

CREATE TRIGGER traces_ad AFTER DELETE ON decision_traces BEGIN
    INSERT INTO traces_fts(traces_fts, rowid, event_name, error_type, root_cause, correction, rule_added)
    VALUES('delete', old.id, old.event_name, old.error_type, old.root_cause, old.correction, old.rule_added);
END;

CREATE TRIGGER traces_au AFTER UPDATE ON decision_traces BEGIN
    INSERT INTO traces_fts(traces_fts, rowid, event_name, error_type, root_cause, correction, rule_added)
    VALUES('delete', old.id, old.event_name, old.error_type, old.root_cause, old.correction, old.rule_added);
    INSERT INTO traces_fts(rowid, event_name, error_type, root_cause, correction, rule_added)
    VALUES (new.id, new.event_name, new.error_type, new.root_cause, new.correction, new.rule_added);
END;
