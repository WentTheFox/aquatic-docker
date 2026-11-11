#!/usr/bin/env bash
# Smoke test of a built image, run in CI before the sha- tag exists and by hand: starts the tracker the way the cluster does (read-only
# root, no capabilities, non-root), then checks a real BitTorrent UDP announce for a listed hash (accepted), an unlisted one (refused),
# a hash added later + SIGUSR1 (accepted without a restart) and that garbage packets do not kill it.
#   tests/smoke.sh <image>
set -euo pipefail
IMAGE="${1:?usage: tests/smoke.sh <image>}"; HERE="$(cd "$(dirname "$0")" && pwd)"; NAME="aquatic-smoke-$$"; PORT="${PORT:-42070}"
TMP="$(mktemp -d)"; cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; rm -rf "$TMP"; }; trap cleanup EXIT
A=$(printf 'a%.0s' {1..40}); B=$(printf 'b%.0s' {1..40}); C=$(printf 'c%.0s' {1..40})
echo "$A" > "$TMP/access-list.txt"
docker run -d --name "$NAME" --read-only --cap-drop ALL --security-opt no-new-privileges -p "127.0.0.1:$PORT:42069/udp" \
  -v "$HERE/../config/aquatic.toml:/etc/aquatic/aquatic.toml:ro" -v "$TMP/access-list.txt:/etc/aquatic/access-list.txt:ro" "$IMAGE" >/dev/null
sleep 2
ann() { python3 "$HERE/announce.py" "$PORT" "$1"; }
ok=0; fail() { echo "FAIL: $*"; docker logs "$NAME" 2>&1 | tail -20; exit 1; }
[[ "$(ann "$A")" == OK* ]]            || fail "listed hash was not accepted"
[[ "$(ann "$B")" == *"not allowed"* ]] || fail "unlisted hash was not refused"
echo "$B" >> "$TMP/access-list.txt"; docker kill -s USR1 "$NAME" >/dev/null; sleep 1
[[ "$(ann "$B")" == OK* ]]            || fail "hash added + SIGUSR1 was not accepted"
python3 -c "
import socket;s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
for n in (1,7,16,98,500): s.sendto(b'\x00'*n,('127.0.0.1',$PORT))
s.sendto(b'GET / HTTP/1.1\r\n\r\n',('127.0.0.1',$PORT))"
sleep 1; [[ "$(docker inspect -f '{{.State.Running}}' "$NAME")" == true ]] || fail "garbage packets killed the tracker"
[[ "$(ann "$C")" == *"not allowed"* ]] || fail "tracker stopped answering after garbage packets"
echo "smoke test passed"
