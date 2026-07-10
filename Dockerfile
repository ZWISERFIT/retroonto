FROM alpine:3.20

RUN apk add --no-cache bash sqlite curl

WORKDIR /opt/retroonto

COPY src/ ./src/
COPY docs/ ./docs/
COPY LICENSE .
COPY README.md .

# Initialize default schema on build
RUN mkdir -p /data && \
    sqlite3 /data/retroonto.db < docs/schema.sql && \
    chmod +x src/*.sh

VOLUME ["/data"]
LABEL org.opencontainers.image.source="https://github.com/ZWISERFIT/retroonto"
ENTRYPOINT ["/opt/retroonto/src/ferrum-gate.sh"]
CMD ["status"]
