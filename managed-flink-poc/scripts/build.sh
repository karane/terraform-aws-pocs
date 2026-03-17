#!/usr/bin/env bash
# Build the Flink fat JAR using Docker
# Run this before the first `terraform apply`and whenever you want to
# rebuild without redeploying.
#
# Output: flink-job/target/flink-sensor-job-1.0.jar
#
# Usage:
#   bash scripts/build.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "==> Building Flink job JAR (Docker + Maven)..."
docker run --rm \
  -v "${PROJECT_ROOT}/flink-job":/workspace \
  -v "${HOME}/.m2":/root/.m2 \
  -w /workspace \
  maven:3.9-eclipse-temurin-11 \
  mvn package -q -DskipTests

echo "==> Done: ${PROJECT_ROOT}/flink-job/target/flink-sensor-job-1.0.jar"
