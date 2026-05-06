#!/usr/bin/env bash
# deploy.sh — single entry point for shipping {{name}} to a server.
#
# Discipline: NEVER deploy {{name}} via raw `cargo`, `docker`, or `gcloud`
# commands typed into a shell. All deploy paths go through this script so
# the steps are deterministic, reviewable, and reproducible across machines.
#
# Usage:
#   bash scripts/deploy.sh <env> [--skip-migrate] [--skip-build]
#
# Environments:
#   staging   — staging Cloud Run / staging Cloud SQL
#   prod      — production Cloud Run / production Cloud SQL
#
# Required env vars (set in your shell or via 1Password / GCP Secret Manager):
#   GCP_PROJECT_ID   — target GCP project
#   GCP_REGION       — e.g. europe-north1
#   CLOUD_RUN_SERVICE — service name in Cloud Run
#   ARTIFACT_REGISTRY_REPO — Artifact Registry repo for the image
#   DATABASE_URL     — Cloud SQL connection string (postgres://…) for migrations
#
# This script is a STARTING POINT — wire your actual hosting (Cloud Run,
# GKE, Fly, Render, raw VM) where the placeholder blocks are. The structure
# is fixed; the host-specific commands are the part you fill in.

set -euo pipefail

ENV="${1:?usage: deploy.sh <staging|prod> [--skip-migrate] [--skip-build]}"
shift || true

SKIP_MIGRATE=0
SKIP_BUILD=0
for arg in "$@"; do
  case "$arg" in
    --skip-migrate) SKIP_MIGRATE=1 ;;
    --skip-build)   SKIP_BUILD=1 ;;
    *) echo "deploy.sh: unknown flag: $arg" >&2; exit 2 ;;
  esac
done

case "$ENV" in
  staging|prod) ;;
  *) echo "deploy.sh: env must be staging|prod, got: $ENV" >&2; exit 2 ;;
esac

# 1. Pre-flight: clean tree, on main (or release branch), tools present.
git diff --quiet || { echo "deploy.sh: working tree dirty — commit or stash first" >&2; exit 1; }
GIT_SHA="$(git rev-parse --short HEAD)"
GIT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
echo "deploy.sh: shipping {{name}} @$GIT_SHA from branch $GIT_BRANCH to $ENV"

for tool in cargo gcloud docker; do
  command -v "$tool" >/dev/null 2>&1 || { echo "deploy.sh: $tool not on PATH" >&2; exit 1; }
done

# 2. Audit gate — never deploy a workspace that fails CI locally.
echo "deploy.sh: running just audit..."
just audit

# 3. Build container image.
if [ "$SKIP_BUILD" -eq 0 ]; then
  IMAGE_TAG="${GCP_REGION:?}-docker.pkg.dev/${GCP_PROJECT_ID:?}/${ARTIFACT_REGISTRY_REPO:?}/{{name}}-server:$GIT_SHA"
  echo "deploy.sh: building $IMAGE_TAG"
  # TODO: replace with your actual build. Two common patterns:
  #   (a) Dockerfile in repo root, multi-stage cargo build → distroless
  #   (b) cargo build --release + custom buildpack
  docker build -t "$IMAGE_TAG" .
  echo "deploy.sh: pushing $IMAGE_TAG"
  docker push "$IMAGE_TAG"
fi

# 4. Run migrations against the target database.
if [ "$SKIP_MIGRATE" -eq 0 ]; then
  echo "deploy.sh: running sqlx migrations against $ENV database"
  # TODO: configure DATABASE_URL for $ENV (Cloud SQL Auth Proxy + IAM token).
  # Example via Cloud SQL Auth Proxy:
  #   cloud-sql-proxy --port 5433 "$GCP_PROJECT_ID:$GCP_REGION:$DB_INSTANCE" &
  #   PROXY_PID=$!
  #   trap 'kill $PROXY_PID' EXIT
  #   DATABASE_URL="postgres://app@127.0.0.1:5433/{{name}}?sslmode=disable" sqlx migrate run
  sqlx migrate run
fi

# 5. Roll out the new revision.
echo "deploy.sh: deploying $IMAGE_TAG to Cloud Run service ${CLOUD_RUN_SERVICE:?}"
# TODO: replace with your actual deploy. Common patterns:
#   gcloud run deploy "$CLOUD_RUN_SERVICE" --image "$IMAGE_TAG" --region "$GCP_REGION" --project "$GCP_PROJECT_ID"
#   kubectl set image deployment/{{name}}-server server="$IMAGE_TAG"
#   flyctl deploy --image "$IMAGE_TAG"

# 6. Smoke check.
echo "deploy.sh: post-deploy smoke check"
# TODO: curl the health endpoint, expect 200.
#   curl -fsS "https://${CLOUD_RUN_SERVICE}.run.app/healthz" >/dev/null

echo "deploy.sh: ✓ {{name}} @$GIT_SHA shipped to $ENV"
