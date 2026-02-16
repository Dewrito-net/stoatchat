# Build Stage
FROM --platform="${BUILDPLATFORM}" rust:1.92.0-slim-bookworm AS builder
USER 0:0
WORKDIR /home/rust/src

ARG TARGETARCH
ARG BUILDARCH

# Install build requirements
RUN apt-get update && \
    apt-get install -y make pkg-config && \
    if [ "${TARGETARCH}" != "${BUILDARCH}" ]; then \
        dpkg --add-architecture "${TARGETARCH}" && \
        apt-get update && \
        apt-get install -y libssl-dev:"${TARGETARCH}" ; \
    else \
        apt-get install -y libssl-dev ; \
    fi

COPY scripts/build-image-layer.sh /tmp/
RUN sh /tmp/build-image-layer.sh tools

# Build all dependencies
COPY Cargo.toml Cargo.lock ./
COPY crates/bonfire/Cargo.toml ./crates/bonfire/
COPY crates/delta/Cargo.toml ./crates/delta/
COPY crates/core/config/Cargo.toml ./crates/core/config/
COPY crates/core/database/Cargo.toml ./crates/core/database/
COPY crates/core/files/Cargo.toml ./crates/core/files/
COPY crates/core/models/Cargo.toml ./crates/core/models/
COPY crates/core/parser/Cargo.toml ./crates/core/parser/
COPY crates/core/permissions/Cargo.toml ./crates/core/permissions/
COPY crates/core/presence/Cargo.toml ./crates/core/presence/
COPY crates/core/result/Cargo.toml ./crates/core/result/
COPY crates/core/coalesced/Cargo.toml ./crates/core/coalesced/
COPY crates/core/ratelimits/Cargo.toml ./crates/core/ratelimits/
COPY crates/services/autumn/Cargo.toml ./crates/services/autumn/
COPY crates/services/january/Cargo.toml ./crates/services/january/
COPY crates/services/gifbox/Cargo.toml ./crates/services/gifbox/
COPY crates/daemons/crond/Cargo.toml ./crates/daemons/crond/
COPY crates/daemons/pushd/Cargo.toml ./crates/daemons/pushd/
COPY crates/daemons/voice-ingress/Cargo.toml ./crates/daemons/voice-ingress/
RUN sh /tmp/build-image-layer.sh deps

# Build all apps
COPY crates ./crates
RUN sh /tmp/build-image-layer.sh apps

# Helper for uname
FROM debian:12-slim AS debian

# Final images
FROM gcr.io/distroless/cc-debian12:nonroot AS base
COPY --from=builder /home/rust/src/target/release/ /usr/local/bin/

FROM gcr.io/distroless/cc-debian12:nonroot AS api
COPY --from=builder /home/rust/src/target/release/revolt-delta ./
COPY --from=debian /usr/bin/uname /usr/bin/uname
EXPOSE 14702
ENV ROCKET_ADDRESS=0.0.0.0
USER nonroot
CMD ["./revolt-delta"]

FROM gcr.io/distroless/cc-debian12:nonroot AS events
COPY --from=builder /home/rust/src/target/release/revolt-bonfire ./
COPY --from=debian /usr/bin/uname /usr/bin/uname
EXPOSE 14703
USER nonroot
CMD ["./revolt-bonfire"]

FROM gcr.io/distroless/cc-debian12:nonroot AS file-server
COPY --from=builder /home/rust/src/target/release/revolt-autumn ./
COPY --from=mwader/static-ffmpeg:7.0.2 /ffmpeg /usr/local/bin/
COPY --from=mwader/static-ffmpeg:7.0.2 /ffprobe /usr/local/bin/
COPY --from=debian /usr/bin/uname /usr/bin/uname
EXPOSE 14704
USER nonroot
CMD ["./revolt-autumn"]

FROM gcr.io/distroless/cc-debian12:nonroot AS proxy
COPY --from=builder /home/rust/src/target/release/revolt-january ./
COPY --from=mwader/static-ffmpeg:7.0.2 /ffmpeg /usr/local/bin/
COPY --from=mwader/static-ffmpeg:7.0.2 /ffprobe /usr/local/bin/
COPY --from=debian /usr/bin/uname /usr/bin/uname
EXPOSE 14705
USER nonroot
CMD ["./revolt-january"]

FROM gcr.io/distroless/cc-debian12:nonroot AS gifbox
COPY --from=builder /home/rust/src/target/release/revolt-gifbox ./
EXPOSE 14706
USER nonroot
CMD ["./revolt-gifbox"]

FROM gcr.io/distroless/cc-debian12:nonroot AS crond
COPY --from=builder /home/rust/src/target/release/revolt-crond ./
USER nonroot
CMD ["./revolt-crond"]

FROM gcr.io/distroless/cc-debian12:nonroot AS pushd
COPY --from=builder /home/rust/src/target/release/revolt-pushd ./
COPY --from=debian /usr/bin/uname /usr/bin/uname
USER nonroot
CMD ["./revolt-pushd"]

FROM gcr.io/distroless/cc-debian12:nonroot AS voice-ingress
COPY --from=builder /home/rust/src/target/release/revolt-voice-ingress ./
COPY --from=debian /usr/bin/uname /usr/bin/uname
USER nonroot
CMD ["./revolt-voice-ingress"]
