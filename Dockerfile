FROM rust:1.75.0-slim-bullseye as builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y \
    git \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy project files
COPY . .

# Build the project
RUN rustup target add wasm32-unknown-unknown
RUN cargo build --target wasm32-unknown-unknown --release

FROM debian:bullseye-slim

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install substreams CLI
RUN curl -L https://github.com/streamingfast/substreams/releases/download/v1.4.0/substreams_linux_x86_64.tar.gz | tar xz && \
    mv substreams /usr/local/bin/

# Copy compiled wasm and config files
COPY --from=builder /app/target/wasm32-unknown-unknown/release/solana_clickhouse.wasm ./target/wasm32-unknown-unknown/release/
COPY --from=builder /app/substreams.yaml ./
COPY --from=builder /app/schema.sql ./
COPY --from=builder /app/token.sh ./

RUN chmod +x /app/token.sh

ENV RUST_LOG=info

CMD ["substreams-sink-sql", "run", "${DSN}", "substreams.yaml", "${START_SLOT}", "--undo-buffer-size", "300"]