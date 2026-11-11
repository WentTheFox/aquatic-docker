# aquatic-docker

Container image of [aquatic_udp](https://github.com/greatest-ape/aquatic) (Apache-2.0), a BitTorrent UDP tracker written in Rust,
built from a **pinned upstream commit** (`AQUATIC_REF` in the `Dockerfile`) into a distroless non-root image
(`ghcr.io/wentthefox/aquatic-docker:sha-<7 hex>`, amd64 + arm64). It replaces the old opentracker on vinyl.

- Private tracker: `config/aquatic.toml` sets the access list to `mode = "allow"`, so only info hashes in the access list are served.
  The list is a text file of 40-character hex info hashes, read on start and when the process receives `SIGUSR1`.
- UDP only. (`aquatic_http` uses io_uring, which the default container seccomp profile blocks.)
- Runs as uid 65532, no shell, no capabilities needed. The cluster deployment lives in the Rathalos repo (`base/tracker`).
- Bumping the pin: read the upstream diff, change `AQUATIC_REF`, push to `main`. The `audit` workflow checks the pinned dependencies
  against RustSec every week.

Local check:

    docker build -t aquatic-docker .
    docker run --rm -p 42069:42069/udp -v ./config/aquatic.toml:/etc/aquatic/aquatic.toml:ro -v ./access-list.txt:/etc/aquatic/access-list.txt:ro aquatic-docker

## License

The packaging in this repository (Dockerfile, configuration, scripts, workflows) is MIT licensed, see `LICENSE`.
aquatic itself, which the image contains, is Apache-2.0 by its authors: see `LICENSE-aquatic` and `NOTICE`.
