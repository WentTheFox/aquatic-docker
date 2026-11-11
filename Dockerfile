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
# --locked: exactly the dependency versions upstream committed. No native-CPU flags (the image must run on any amd64/arm64 host).
RUN cargo build --release --locked -p aquatic_udp

FROM gcr.io/distroless/cc-debian12:nonroot AS runtime
COPY --from=build /src/target/release/aquatic_udp /usr/local/bin/aquatic_udp
COPY --from=build /src/LICENSE /usr/share/doc/aquatic/LICENSE
# The config and the access list are mounted by the deployment (/etc/aquatic/aquatic.toml, /etc/aquatic/access-list.txt).
USER 65532:65532
ENTRYPOINT ["/usr/local/bin/aquatic_udp"]
CMD ["-c", "/etc/aquatic/aquatic.toml"]
