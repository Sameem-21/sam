#!/bin/bash
set -euo pipefail

# === INPUTS ===
MODE="$1"
IMAGE_NAME="$2"
IMAGE_TAG="$3"
DOCKERHUB_IMAGE="${4:-}"
GIT_REPO="${5:-}"
REPO_NAME="$6"

# === CONFIG ===
REGION="ap-south-1"
ACCOUNT_ID="588082971984"
ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME"

echo "Deployment Mode: $MODE"
echo "Image: $IMAGE_NAME:$IMAGE_TAG"
echo "Target ECR Repo: $REPO_NAME"

# === AUTH TO ECR ===
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

# === CREATE ECR REPO IF MISSING ===
if ! aws ecr describe-repositories --repository-names "$REPO_NAME" --region "$REGION" > /dev/null 2>&1; then
  echo "Creating ECR repository: $REPO_NAME"
  aws ecr create-repository --repository-name "$REPO_NAME" --region "$REGION"
fi

# === BUILD FROM DOCKERFILE ===
if [ "$MODE" == "dockerfile" ]; then
  echo "Cloning repo: $GIT_REPO"
  git clone "$GIT_REPO"
  cd "$(basename "$GIT_REPO" .git)"
  docker build -f "./Dockerfile" -t "$IMAGE_NAME:$IMAGE_TAG" .
fi

# === PULL FROM DOCKER HUB ===
if [ "$MODE" == "dockerhub" ]; then
  if [[ "$DOCKERHUB_IMAGE" != *:* ]]; then
    DOCKERHUB_IMAGE="$DOCKERHUB_IMAGE:latest"
  fi
  echo "Pulling Docker Hub image: $DOCKERHUB_IMAGE"
  docker pull "$DOCKERHUB_IMAGE"
  docker tag "$DOCKERHUB_IMAGE" "$IMAGE_NAME:$IMAGE_TAG"
fi

# === VERIFY LOCAL IMAGE ===
if [ "$MODE" == "local" ]; then
  echo "Checking local image: $IMAGE_NAME:$IMAGE_TAG"
  if ! docker image inspect "$IMAGE_NAME:$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Local image '$IMAGE_NAME:$IMAGE_TAG' not found."
    exit 1
  fi
fi

# === TAG & PUSH TO ECR ===
echo "Tagging image for ECR: $ECR_URI:$IMAGE_TAG"
docker tag "$IMAGE_NAME:$IMAGE_TAG" "$ECR_URI:$IMAGE_TAG"

echo "Pushing image to ECR..."
docker push "$ECR_URI:$IMAGE_TAG"

DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "$ECR_URI:$IMAGE_TAG")
echo "Pushed image digest: $DIGEST"
