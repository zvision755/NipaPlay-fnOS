# Pinned official Debian base; no window or display server.
FROM debian:bookworm-slim@sha256:7c7b2c966bc9ee8cedfeef67e0e279108992c77681fa595db4a9d65c06ccc587 AS system
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl ffmpeg sqlite3 libsqlite3-0 libfontconfig1 \
    libglib2.0-0 libgl1 libegl1 libatomic1 \
    && ln -s "$(find /usr/lib -name libsqlite3.so.0 -print -quit)" /usr/local/lib/libsqlite3.so \
    && ldconfig && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 nipaplay && useradd --uid 10001 --gid 10001 --no-create-home nipaplay

FROM system AS sdk
ARG FLUTTER_REVISION=ee80f08bbf97172ec030b8751ceab557177a34a6
ARG FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
ENV FLUTTER_ROOT=/opt/flutter PATH=/opt/flutter/bin:$PATH PUB_CACHE=/opt/pub-cache \
    FLUTTER_SUPPRESS_ANALYTICS=true CI=true
ENV FLUTTER_STORAGE_BASE_URL=$FLUTTER_STORAGE_BASE_URL
RUN apt-get update && apt-get install -y --no-install-recommends git unzip xz-utils \
    && rm -rf /var/lib/apt/lists/*
COPY --from=flutter_source /flutter /opt/flutter
RUN test "$(git -C /opt/flutter rev-parse HEAD)" = "$FLUTTER_REVISION" \
    && flutter precache --web

FROM rust:1.93.0-slim-bookworm@sha256:776861219cd851131c1cec3bbd7cbeb16b99a794048097eb69ad9682a8ed0d57 AS rust-build
RUN apt-get update && apt-get install -y --no-install-recommends build-essential pkg-config cmake \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app/rust
COPY rust/ ./
COPY assets/subfont.ttf /app/assets/subfont.ttf
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/app/rust/target \
    cargo build --locked --release --lib \
    && cargo test --locked --release --lib api::file_scan::tests \
    && cp target/release/librust_lib_nipaplay.so /tmp/librust_lib_nipaplay.so

FROM sdk AS development
WORKDIR /app
COPY --from=pub_dependencies / /opt/pub-cache/
RUN chmod -R a+rX /opt/pub-cache
COPY . .
COPY --from=rust-build /tmp/librust_lib_nipaplay.so /app/rust/target/release/librust_lib_nipaplay.so
RUN mkdir -p assets/web && touch assets/web/.gitkeep \
    && flutter pub get --offline --enforce-lockfile \
    && scripts/compile_fnos_server.sh \
    && mkdir -p /opt/headless-engine \
    && engine="$(find /opt/flutter/bin/cache/artifacts/engine -mindepth 2 -maxdepth 2 -name flutter_tester -print -quit)" \
    && cp "$engine" "$(dirname "$engine")/icudtl.dat" /opt/headless-engine/
ENV NIPAPLAY_DATA_DIR=/data NIPAPLAY_BIND_ADDRESS=0.0.0.0 NIPAPLAY_PORT=1180
ARG SOURCE_REVISION=uncommitted
ARG SOURCE_DIGEST=unknown
ENV NIPAPLAY_SOURCE_REVISION=$SOURCE_REVISION NIPAPLAY_SOURCE_DIGEST=$SOURCE_DIGEST
CMD ["scripts/run_fnos_server.sh", "--compile"]

FROM development AS web-build
RUN scripts/build_fnos_web.sh

FROM system AS production
WORKDIR /app
COPY --from=development /opt/headless-engine /opt/headless-engine
COPY --from=development /app/build/fnos/server.dill /app/build/fnos/server.dill
COPY --from=rust-build /tmp/librust_lib_nipaplay.so /app/rust/target/release/librust_lib_nipaplay.so
COPY --from=web-build /app/build/web /app/build/web
COPY scripts/run_fnos_server.sh /app/scripts/run_fnos_server.sh
COPY LICENSE /app/LICENSE
ARG SOURCE_REVISION=uncommitted
ARG SOURCE_DIGEST=unknown
LABEL org.opencontainers.image.source="https://github.com/AimesSoft/NipaPlay-Reload" \
      org.opencontainers.image.revision=$SOURCE_REVISION \
      io.nipaplay.source-digest=$SOURCE_DIGEST
ENV NIPAPLAY_DATA_DIR=/data NIPAPLAY_WEB_ROOT=/app/build/web \
    NIPAPLAY_PORT=1180 NIPAPLAY_BIND_ADDRESS=0.0.0.0 \
    NIPAPLAY_ENGINE=/opt/headless-engine/flutter_tester \
    NIPAPLAY_SOURCE_REVISION=$SOURCE_REVISION NIPAPLAY_SOURCE_DIGEST=$SOURCE_DIGEST
USER 10001:10001
EXPOSE 1180
HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=6 CMD curl -fsS http://127.0.0.1:1180/healthz >/dev/null || exit 1
CMD ["scripts/run_fnos_server.sh"]
