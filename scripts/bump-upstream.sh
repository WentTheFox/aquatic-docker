#!/usr/bin/env bash
# Move the pinned upstream aquatic commit (Dockerfile AQUATIC_REF). Shows what changed since the pin so you can READ it first.
#   scripts/bump-upstream.sh            show the new upstream commits and the files they touch, change nothing
#   scripts/bump-upstream.sh <sha>      pin <sha> (full or abbreviated), rebuild locally, run tests/smoke.sh, commit (no push)
set -euo pipefail
cd "$(dirname "$0")/.."
PIN="$(sed -n 's/^ARG AQUATIC_REF=//p' Dockerfile | head -n1)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
git clone --quiet https://github.com/greatest-ape/aquatic "$W/up"
NEW="${1:+$(git -C "$W/up" rev-parse "$1")}"; NEW="${NEW:-$(git -C "$W/up" rev-parse origin/HEAD)}"
if [ "$PIN" = "$NEW" ]; then echo "already on upstream HEAD ($PIN)"; exit 0; fi
echo "pinned $PIN"; echo "target $NEW"; echo
git -C "$W/up" log --format='%h %ad %s' --date=short "$PIN..$NEW" | head -50
echo; git -C "$W/up" diff --stat "$PIN..$NEW" -- . ':!*.md' ':!documents' | tail -25
echo; echo "dependency changes:"; git -C "$W/up" diff "$PIN..$NEW" -- Cargo.lock | grep -E '^[+-]name|^[+-]version' | head -30 || true
[ -n "${1:-}" ] || { echo; echo "review the above, then: scripts/bump-upstream.sh $NEW"; exit 0; }
sed -i "s/^ARG AQUATIC_REF=.*/ARG AQUATIC_REF=$NEW/" Dockerfile
docker build -t aquatic-docker:bump .
tests/smoke.sh aquatic-docker:bump
git add Dockerfile && git commit -q -m "chore: bump pinned aquatic to ${NEW:0:7}" && echo "committed; push when you are happy"
