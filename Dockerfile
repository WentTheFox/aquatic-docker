# syntax=docker/dockerfile:1

# aquatic_udp (https://github.com/greatest-ape/aquatic, Apache-2.0), a BitTorrent UDP tracker written in Rust, built from a PINNED
# upstream commit (never a moving branch) into a distroless, non-root runtime image. There is no HTTP tracker here on purpose:
# aquatic_http needs io_uring, which the default container seccomp profile blocks.
#
# Bump AQUATIC_REF on purpose (read the upstream diff first). The build fails if the checkout is not exactly that commit.
ARG AQUATIC_REF=a2ddc4b323c5aaf844ce32b655b0ffc8c4836cde

FROM rust:1-bookworm AS build
ARG AQUATIC_REF
WORKDIR /src
RUN git clone --quiet https://github.com/greatest-ape/aquatic . \
 && git checkout --quiet --detach "$AQUATIC_REF" \
 && test "$(git rev-parse HEAD)" = "$AQUATIC_REF"
# Override: upstream's lockfile has anyhow 1.0.102 (RUSTSEC-2026-0190, unsound Error::downcast_mut, fixed in 1.0.103) and its newest commit
# has not bumped it yet. Update ONLY that crate: the build fails unless exactly one package changed version (one - and one + `version` line)
# and no other kind of line in Cargo.lock moved. Drop this step once upstream's lockfile has anyhow >= 1.0.103 (the step fails with that
# message when the locked version is not 1.0.102, and so does the audit workflow's copy of it).
RUN test "$(awk '/^name = "anyhow"$/{getline; print}' Cargo.lock)" = 'version = "1.0.102"' || { echo "upstream no longer locks anyhow 1.0.102: remove the anyhow override"; exit 1; } \
 && cargo update -p anyhow --precise 1.0.103 \
 && test "$(git diff -U0 Cargo.lock | grep -c -E '^[+-]version = ')" = 2 \
 && test "$(git diff -U0 Cargo.lock | grep -E '^[+-][^+-]' | grep -v -E '^[+-](version|checksum) = ' | wc -l)" = 0 \
 && git diff --stat Cargo.lock
# --locked: exactly the dependency versions upstream committed (apart from the anyhow override above). No native-CPU flags (the image must run on any amd64/arm64 host).
# --no-default-features --features mimalloc: drops the optional Prometheus exporter (we never enable it), which takes the hyper/h2/tokio
# HTTP stack and 60+ crates out of a binary that parses untrusted UDP packets (186 -> 122 crates; RustSec flagged h2 and crossbeam-epoch there).
RUN cargo build --release --locked -p aquatic_udp --no-default-features --features mimalloc

FROM gcr.io/distroless/cc-debian12:nonroot AS runtime
COPY --from=build /src/target/release/aquatic_udp /usr/local/bin/aquatic_udp
COPY --from=build /src/LICENSE /usr/share/doc/aquatic/LICENSE
# The config and the access list are mounted by the deployment (/etc/aquatic/aquatic.toml, /etc/aquatic/access-list.txt).
USER 65532:65532
ENTRYPOINT ["/usr/local/bin/aquatic_udp"]
CMD ["-c", "/etc/aquatic/aquatic.toml"]
