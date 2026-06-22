#!/usr/bin/env bash
set -euo pipefail

PROFILE="${AWS_PROFILE:-narkshar-publisher}"
REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --profile "$PROFILE" --query Account --output text)}"
BUCKET="${S3_BUCKET:-narkshar-client-assets-$ACCOUNT_ID}"

if aws s3api head-bucket --profile "$PROFILE" --bucket "$BUCKET" >/dev/null 2>&1; then
  printf 'Bucket already exists: %s\n' "$BUCKET"
else
  if [[ "$REGION" == "us-east-1" ]]; then
    aws s3api create-bucket --profile "$PROFILE" --region "$REGION" --bucket "$BUCKET"
  else
    aws s3api create-bucket \
      --profile "$PROFILE" \
      --region "$REGION" \
      --bucket "$BUCKET" \
      --create-bucket-configuration "LocationConstraint=$REGION"
  fi
fi

aws s3api put-bucket-ownership-controls \
  --profile "$PROFILE" \
  --bucket "$BUCKET" \
  --ownership-controls '{
    "Rules": [
      { "ObjectOwnership": "BucketOwnerEnforced" }
    ]
  }'

aws s3api put-public-access-block \
  --profile "$PROFILE" \
  --bucket "$BUCKET" \
  --public-access-block-configuration '{
    "BlockPublicAcls": true,
    "IgnorePublicAcls": true,
    "BlockPublicPolicy": false,
    "RestrictPublicBuckets": false
  }'

policy="$(mktemp)"
trap 'rm -f "$policy"' EXIT

cat > "$policy" <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadObjectsOnly",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::$BUCKET/*"
    }
  ]
}
JSON

aws s3api put-bucket-policy \
  --profile "$PROFILE" \
  --bucket "$BUCKET" \
  --policy "file://$policy"

cat <<EOF
Bucket configured: $BUCKET
Public base URL: https://$BUCKET.s3.$REGION.amazonaws.com/

Anonymous users can read exact object URLs only.
Anonymous users cannot list the bucket and cannot write objects.
EOF
