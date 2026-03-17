#!/usr/bin/env bash
# Re-deploy a new version of the Flink JAR without touching Terraform.
# Use this for every JAR update after the initial `terraform apply`.
#
# Usage:
#   bash scripts/build_and_upload.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "==> Reading Terraform outputs..."
BUCKET=$(terraform -chdir="${PROJECT_ROOT}" output -raw s3_bucket_name)
JAR_KEY=$(terraform -chdir="${PROJECT_ROOT}" output -raw jar_s3_key)
APP_NAME=$(terraform -chdir="${PROJECT_ROOT}" output -raw application_name)
JAR_PATH="${PROJECT_ROOT}/flink-job/target/flink-sensor-job-1.0.jar"

echo "    Application : ${APP_NAME}"
echo "    S3 bucket   : ${BUCKET}"
echo "    S3 key      : ${JAR_KEY}"

echo ""
bash "${SCRIPT_DIR}/build.sh"

STATUS=$(aws kinesisanalyticsv2 describe-application \
  --application-name "${APP_NAME}" \
  --query "ApplicationDetail.ApplicationStatus" \
  --output text)

echo ""
echo "==> Application status: ${STATUS}"

if [[ "${STATUS}" == "RUNNING" ]]; then
  echo "==> Stopping application..."
  aws kinesisanalyticsv2 stop-application \
    --application-name "${APP_NAME}" \
    --force

  echo -n "    Waiting for READY"
  while true; do
    STATUS=$(aws kinesisanalyticsv2 describe-application \
      --application-name "${APP_NAME}" \
      --query "ApplicationDetail.ApplicationStatus" \
      --output text)
    [[ "${STATUS}" == "READY" ]] && break
    echo -n "."
    sleep 5
  done
  echo " done"
fi

echo ""
echo "==> Uploading JAR to s3://${BUCKET}/${JAR_KEY} ..."
aws s3 cp "${JAR_PATH}" "s3://${BUCKET}/${JAR_KEY}"

echo ""
echo "==> Updating application code (bumping version to invalidate JAR cache)..."
CURRENT_VERSION=$(aws kinesisanalyticsv2 describe-application \
  --application-name "${APP_NAME}" \
  --query "ApplicationDetail.ApplicationVersionId" \
  --output text)

aws kinesisanalyticsv2 update-application \
  --application-name "${APP_NAME}" \
  --current-application-version-id "${CURRENT_VERSION}" \
  --application-configuration-update "{
    \"ApplicationCodeConfigurationUpdate\": {
      \"CodeContentTypeUpdate\": \"ZIPFILE\",
      \"CodeContentUpdate\": {
        \"S3ContentLocationUpdate\": {
          \"BucketARNUpdate\": \"arn:aws:s3:::${BUCKET}\",
          \"FileKeyUpdate\": \"${JAR_KEY}\"
        }
      }
    }
  }" > /dev/null

echo ""
echo "==> Starting application..."
aws kinesisanalyticsv2 start-application \
  --application-name "${APP_NAME}" \
  --run-configuration '{"FlinkRunConfiguration":{"AllowNonRestoredState":true}}'

echo -n "    Waiting for RUNNING"
while true; do
  STATUS=$(aws kinesisanalyticsv2 describe-application \
    --application-name "${APP_NAME}" \
    --query "ApplicationDetail.ApplicationStatus" \
    --output text)
  [[ "${STATUS}" == "RUNNING" ]] && break
  echo -n "."
  sleep 5
done
echo " done"

echo ""
echo "==> Application is RUNNING with the new JAR."
