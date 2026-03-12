#!/bin/bash
set -e

REGION="us-east-2"
REPO_URL=$(terraform output -raw ecr_repository_url)

# Capture the active Docker host before overriding DOCKER_CONFIG (preserves context socket)
DOCKER_HOST=$(docker context inspect --format '{{.Endpoints.docker.Host}}')
export DOCKER_HOST

# Use a temporary Docker config to avoid credential store issues (e.g. pass not initialized)
DOCKER_CONFIG=$(mktemp -d)
export DOCKER_CONFIG

# trap is like defer in golang
trap 'rm -rf "$DOCKER_CONFIG"' EXIT 

echo "Logging in to ECR..."
ECR_PASSWORD=$(aws ecr get-login-password --region $REGION)
AUTH=$(echo -n "AWS:$ECR_PASSWORD" | base64 -w 0)
cat > "$DOCKER_CONFIG/config.json" <<EOF
{
  "auths": {
    "$REPO_URL": {
      "auth": "$AUTH"
    }
  }
}
EOF
echo "Login successful."

echo "Building image..."
docker build -t $REPO_URL:latest app/

echo "Pushing image..."
docker push $REPO_URL:latest

echo "Done. Image pushed to $REPO_URL:latest"
