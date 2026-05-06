#!/usr/bin/env bash
# upload.sh — push static assets (web bundle, desktop binaries, mobile builds) to a CDN/object store.
#
# Discipline: NEVER upload {{name}} artifacts via raw `gsutil`/`aws s3`/`scp`
# commands. All uploads route through this script so the artifacts, paths,
# and cache rules are deterministic.
#
# Usage:
#   bash scripts/upload.sh <kind> <env>
#
# Kinds:
#   web      — Dioxus web bundle (WASM + JS + assets) → CDN/object store
#   desktop  — desktop release binaries → release bucket
#   mobile   — mobile release builds → app store / TestFlight upload
#
# Required env vars:
#   GCS_BUCKET           — destination bucket (or your CDN's equivalent)
#   GCS_PREFIX           — path prefix inside the bucket (e.g. "{{name}}/web")
#   CDN_INVALIDATE_PATHS — optional: comma-separated paths to invalidate after upload

set -euo pipefail

KIND="${1:?usage: upload.sh <web|desktop|mobile> <staging|prod>}"
ENV="${2:?usage: upload.sh <web|desktop|mobile> <staging|prod>}"

case "$ENV" in
  staging|prod) ;;
  *) echo "upload.sh: env must be staging|prod, got: $ENV" >&2; exit 2 ;;
esac

git diff --quiet || { echo "upload.sh: working tree dirty — commit first" >&2; exit 1; }
GIT_SHA="$(git rev-parse --short HEAD)"
DEST="gs://${GCS_BUCKET:?}/${GCS_PREFIX:?}/$ENV/$GIT_SHA"

echo "upload.sh: $KIND artifacts → $DEST"

case "$KIND" in
  web)
    echo "upload.sh: building Dioxus web bundle"
    dx build --platform web --release
    # TODO: configure your destination. Example with gsutil:
    #   gsutil -m -h "Cache-Control:public,max-age=31536000,immutable" rsync -r dist/ "$DEST/"
    #   (then upload index.html separately with Cache-Control: no-cache)
    ;;
  desktop)
    echo "upload.sh: building desktop release"
    cargo build -p desktop --release
    # TODO: tar + gsutil cp to release bucket
    ;;
  mobile)
    echo "upload.sh: building mobile release (best-effort)"
    dx build --platform mobile --release
    # TODO: app store / TestFlight upload (fastlane, eas, etc.)
    ;;
  *)
    echo "upload.sh: unknown kind: $KIND (web|desktop|mobile)" >&2
    exit 2
    ;;
esac

# Optional CDN invalidate.
if [ -n "${CDN_INVALIDATE_PATHS:-}" ]; then
  echo "upload.sh: invalidating CDN paths: $CDN_INVALIDATE_PATHS"
  # TODO: gcloud compute url-maps invalidate-cdn-cache, or your CDN equivalent
fi

echo "upload.sh: ✓ $KIND @$GIT_SHA uploaded to $ENV ($DEST)"
