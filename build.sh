#!/bin/bash
set -e

REGISTRY="docker.io/jabbas"
VERSION="${1:-latest}"
PLATFORM="linux/amd64"

# Base paths for Flutter apps
ARTISAN_BASE_HREF="${ARTISAN_BASE_HREF:-/artisan/}"
CLIENT_BASE_HREF="${CLIENT_BASE_HREF:-/}"

echo "Building version: ${VERSION}"
echo "Artisan base href: ${ARTISAN_BASE_HREF}"
echo "Client base href: ${CLIENT_BASE_HREF}"

# Update Helm chart appVersions
echo "Updating Helm charts appVersion to ${VERSION}..."
sed -i '' "s/^appVersion:.*/appVersion: \"${VERSION}\"/" helm/charts/backend/Chart.yaml
sed -i '' "s/^appVersion:.*/appVersion: \"${VERSION}\"/" helm/charts/artisan/Chart.yaml
sed -i '' "s/^appVersion:.*/appVersion: \"${VERSION}\"/" helm/charts/client/Chart.yaml

# Backend
echo "Building backend..."
podman build --platform ${PLATFORM} --build-arg APP_VERSION="${VERSION}" -t ${REGISTRY}/ibakery-backend:${VERSION} ./backend

# Artisan
echo "Building artisan..."
podman build --platform ${PLATFORM} --build-arg BASE_HREF="${ARTISAN_BASE_HREF}" --build-arg APP_VERSION="${VERSION}" -t ${REGISTRY}/ibakery-artisan:${VERSION} ./artisan

# Client
echo "Building client..."
podman build --platform ${PLATFORM} --build-arg BASE_HREF="${CLIENT_BASE_HREF}" --build-arg APP_VERSION="${VERSION}" -t ${REGISTRY}/ibakery-client:${VERSION} ./client

# Push
echo "Pushing images..."
podman push ${REGISTRY}/ibakery-backend:${VERSION}
podman push ${REGISTRY}/ibakery-artisan:${VERSION}
podman push ${REGISTRY}/ibakery-client:${VERSION}

echo "Done! Pushed version: ${VERSION}"
