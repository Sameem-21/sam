#!/bin/bash
set -e

echo "Select deployment mode:"
echo "  dockerfile - Build from Dockerfile in Git repo"
echo "  dockerhub  - Pull image from Docker Hub"
echo "  local      - Use existing local image"
read -p "Enter mode: " MODE

# === INPUTS ===
read -p "Enter image name (e.g., my-app): " IMAGE_NAME
read -p "Enter image tag (e.g., v1.0.0): " IMAGE_TAG


if [ "$MODE" == "dockerhub" ]; then
  read -p "Enter Docker Hub image (e.g., nginx:latest): " DOCKERHUB_IMAGE

fi

if [ "$MODE" == "dockerfile" ]; then
  read -p "Enter Git repo URL: " GIT_REPO
fi

read -p "Enter ECR repository name: " REPO_NAME

# === CONFIG ===
REGION="ap-south-1"
ACCOUNT_ID="588082971984"
ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME"

# === AUTH TO ECR ===
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

# === CREATE ECR REPO IF MISSING ===
if ! aws ecr describe-repositories --repository-names "$REPO_NAME" --region "$REGION" > /dev/null 2>&1; then
  echo "🛠️ Creating ECR repository: $REPO_NAME"
  aws ecr create-repository --repository-name "$REPO_NAME" --region "$REGION"
fi

# === BUILD FROM DOCKERFILE ===
if [ "$MODE" == "dockerfile" ]; then
  git clone "$GIT_REPO"
  cd "$(basename "$GIT_REPO" .git)"
  docker build -f "./Dockerfile" -t "$IMAGE_NAME" .
fi

# === PULL FROM DOCKER HUB ===
if [ "$MODE" == "dockerhub" ]; then
  docker pull "$DOCKERHUB_IMAGE"
  docker tag "$DOCKERHUB_IMAGE" "$IMAGE_NAME:$IMAGE_TAG"
fi

# === VERIFY LOCAL IMAGE ===
if [ "$MODE" == "local" ]; then
  if ! docker image inspect "$IMAGE_NAME:$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Local image '$IMAGE_NAME:$IMAGE_TAG' not found."
    exit 1
  fi
fi

# === TAG & PUSH TO ECR ===
docker tag "$IMAGE_NAME:$IMAGE_TAG" "$ECR_URI:$IMAGE_TAG"
docker push "$ECR_URI:$IMAGE_TAG"
