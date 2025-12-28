#!/bin/bash
set -e

export CI=true

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

# Build Flutter apps
echo "Building artisan Flutter app..."
cd artisan
flutter build web --release --pwa-strategy none --base-href="${ARTISAN_BASE_HREF}" --dart-define=APP_VERSION="${VERSION}"
cd ..

echo "Building client Flutter app..."
cd client
flutter build web --release --pwa-strategy none --base-href="${CLIENT_BASE_HREF}" --dart-define=APP_VERSION="${VERSION}"
cd ..

# Backend
echo "Building backend image..."
podman build --platform ${PLATFORM} --build-arg APP_VERSION="${VERSION}" -t ${REGISTRY}/ibakery-backend:${VERSION} ./backend

# Artisan
echo "Building artisan image..."
podman build --platform ${PLATFORM} -f Dockerfile.flutter --build-arg BUILD_DIR=artisan/build/web --build-arg BASE_HREF="${ARTISAN_BASE_HREF}" -t ${REGISTRY}/ibakery-artisan:${VERSION} .

# Client
echo "Building client image..."
podman build --platform ${PLATFORM} -f Dockerfile.flutter --build-arg BUILD_DIR=client/build/web --build-arg BASE_HREF="${CLIENT_BASE_HREF}" -t ${REGISTRY}/ibakery-client:${VERSION} .

# Push
echo "Pushing images..."
podman push ${REGISTRY}/ibakery-backend:${VERSION}
podman push ${REGISTRY}/ibakery-artisan:${VERSION}
podman push ${REGISTRY}/ibakery-client:${VERSION}

echo "Done! Pushed version: ${VERSION}"
