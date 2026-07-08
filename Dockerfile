# =============================================================================
# RetroOnto — Decision Ontology for Multi-Agent Systems
# =============================================================================
# One-click Docker image with SQLite3 + FTS5, seed data, and CLI tool.
#
# Usage:
#   docker build -t retroonto .
#   docker run --rm -it retroonto         # Shows database stats
#   docker run --rm -it retroonto /bin/sh # Interactive shell
# =============================================================================

FROM alpine:3.20

# Install dependencies: sqlite3 (with FTS5), jq for JSON processing
RUN apk add --no-cache sqlite jq bash

# Create working directory
WORKDIR /retroonto

# Copy repository contents
COPY src/schema.sql ./src/schema.sql
COPY data/seed-traces.json ./data/seed-traces.json

# Initialize database schema
RUN sqlite3 /retroonto/data/zwf-knowledge.db < src/schema.sql && \
    echo "Database schema initialized."

# ---------------------------------------------------------------------------
# Entrypoint: seeds data on first run, then shows stats
# ---------------------------------------------------------------------------
RUN printf '#!/bin/sh\n\
set -e\n\
DB=/retroonto/data/zwf-knowledge.db\n\
\n\
# Seed decision traces if table is empty\n\
COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM decision_traces;")\n\
if [ "$COUNT" -eq 0 ] && [ -f data/seed-traces.json ]; then\n\
    echo "→ Seeding decision traces from data/seed-traces.json..."\n\
    jq -c ".[]" data/seed-traces.json | while IFS= read -r row; do\n\
        event=$(echo "$row" | jq -r ".event_name // \"\" | @json")\n\
        agent=$(echo "$row" | jq -r ".agent // \"\" | @json")\n\
        errtype=$(echo "$row" | jq -r ".error_type // \"\" | @json")\n\
        context=$(echo "$row" | jq -r ".context // \"\" | @json")\n\
        decision=$(echo "$row" | jq -r ".decision_made // \"\" | @json")\n\
        rc=$(echo "$row" | jq -r ".root_cause // \"\" | @json")\n\
        corr=$(echo "$row" | jq -r ".correction // \"\" | @json")\n\
        rule=$(echo "$row" | jq -r ".rule_added // \"\" | @json")\n\
        compound=$(echo "$row" | jq -r ".learning_compound // 0")\n\
        trace=$(echo "$row" | jq -c ".trace_json // {} | @json")\n\
        sqlite3 "$DB" "\n\
            INSERT INTO decision_traces(\n\
                event_name, agent, error_type, context, decision_made,\n\
                root_cause, correction, rule_added, learning_compound, trace_json\n\
            ) VALUES(\n\
                json($event), json($agent), json($errtype), json($context),\n\
                json($decision), json($rc), json($corr), json($rule),\n\
                $compound, json($trace)\n\
            );\n\
        "\n\
    done\n\
    SEEDED=$(sqlite3 "$DB" "SELECT COUNT(*) FROM decision_traces;")\n\
    echo "→ $SEEDED decision trace(s) loaded."\n\
fi\n\
\n\
# Show database stats\n\
echo "=========================================="\n\
echo " RetroOnto · Decision Ontology Database"\n\
echo "=========================================="\n\
sqlite3 -header -column "$DB" "\n\
    SELECT '"'"'wiki_entries'"'"' AS table_name, COUNT(*) AS records FROM wiki_entries\n\
    UNION ALL\n\
    SELECT '"'"'decision_traces'"'"', COUNT(*) FROM decision_traces;\n\
"\n\
echo ""\n\
echo "Decision traces by error type:"\n\
sqlite3 -header -column "$DB" "\n\
    SELECT error_type, COUNT(*) AS cnt\n\
    FROM decision_traces\n\
    GROUP BY error_type\n\
    ORDER BY cnt DESC;\n\
"\n\
echo ""\n\
echo "FTS indexes: wiki_fts ✓  traces_fts ✓"\n\
\n\
# If a command was passed, execute it\n\
if [ $# -gt 0 ]; then\n\
    exec "$@"\n\
fi\n\
' > /retroonto/entrypoint.sh && chmod +x /retroonto/entrypoint.sh

ENTRYPOINT ["/retroonto/entrypoint.sh"]
