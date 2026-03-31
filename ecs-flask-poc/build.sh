#!/bin/bash
set -eo pipefail

ECR_URL=$(terraform output -raw ecr_repository_url)
REGION=$(aws configure get region 2>/dev/null || echo "us-east-2")

DOCKER_CONFIG_DIR=$(mktemp -d)
trap "rm -rf \"$DOCKER_CONFIG_DIR\"" EXIT

# Preserve the active Docker context so the daemon socket is reachable
CURRENT_CONTEXT=$(docker context show 2>/dev/null || echo "default")
if [ -d "$HOME/.docker/contexts" ]; then
  cp -r "$HOME/.docker/contexts" "$DOCKER_CONFIG_DIR/contexts"
fi

echo "Authenticating with ECR..."
ECR_PASSWORD=$(aws ecr get-login-password --region "$REGION")
AUTH=$(echo -n "AWS:$ECR_PASSWORD" | base64 -w 0)
cat > "$DOCKER_CONFIG_DIR/config.json" <<EOF
{
  "currentContext": "$CURRENT_CONTEXT",
  "auths": {
    "$ECR_URL": {
      "auth": "$AUTH"
    }
  }
}
EOF

echo "Building image..."
DOCKER_CONFIG="$DOCKER_CONFIG_DIR" docker build -t "$ECR_URL:latest" ./app

echo "Pushing image..."
DOCKER_CONFIG="$DOCKER_CONFIG_DIR" docker push "$ECR_URL:latest"

echo "Done -- image pushed to $ECR_URL:latest"
