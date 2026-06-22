#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLIENT_DIR="$ROOT_DIR/client"
PROFILE="${AWS_PROFILE:-narkshar-publisher}"
REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --profile "$PROFILE" --query Account --output text)}"
BUCKET="${S3_BUCKET:-narkshar-client-assets-$ACCOUNT_ID}"
BASE_URL="https://$BUCKET.s3.$REGION.amazonaws.com/"

"$ROOT_DIR/scripts/generate-manifest.sh" "${1:-}"

aws s3 sync "$CLIENT_DIR" "s3://$BUCKET/client/" \
  --profile "$PROFILE" \
  --region "$REGION" \
  --exclude 'manifest.json' \
  --cache-control 'public,max-age=31536000,immutable'

aws s3 cp "$CLIENT_DIR/manifest.json" "s3://$BUCKET/client/manifest.json" \
  --profile "$PROFILE" \
  --region "$REGION" \
  --cache-control 'no-cache' \
  --content-type 'application/json'

cat <<EOF
Uploaded Narkshar client payload.
Manifest URL: ${BASE_URL}client/manifest.json

Set this for local launcher testing when using a non-default bucket:
export NARKSHAR_ASSET_BASE_URL="$BASE_URL"
EOF
