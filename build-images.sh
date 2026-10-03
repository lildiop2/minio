#!/usr/bin/env bash
# ==============================================================================
# Script: build-images.sh
# Purpose: Build custom MinIO container images from source for GHCR
# ==============================================================================

set -euo pipefail

IMAGE_REPO="${IMAGE_REPO:-ghcr.io/lildiop2/minio}"
HOMELAB_RELEASE="RELEASE.2025-04-22T22-12-26Z"
HOMELAB_COMMIT="0d7408fc9969caf07de6a8c3a84f9fbb10a6739e"
LATEST_RELEASE="RELEASE.2025-10-15T17-29-55Z"
LATEST_COMMIT="9e49d5e7a648f00e26f2246f4dc28e6b07f8c84a"

PUSH=false
ACTION="all"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --all            Build both the homelab version ($HOMELAB_RELEASE) and latest ($LATEST_RELEASE) (default)
  --homelab        Build only the homelab version ($HOMELAB_RELEASE)
  --latest         Build only the latest version ($LATEST_RELEASE)
  --push           Push built images to $IMAGE_REPO
  -h, --help       Show this help message

Examples:
  $0 --all
  $0 --all --push
  $0 --homelab
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)
            ACTION="all"
            shift
            ;;
        --homelab)
            ACTION="homelab"
            shift
            ;;
        --latest)
            ACTION="latest"
            shift
            ;;
        --push)
            PUSH=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

build_latest() {
    echo "==> Building Latest MinIO (${LATEST_RELEASE})..."
    docker build \
        -t "${IMAGE_REPO}:${LATEST_RELEASE}" \
        -t "${IMAGE_REPO}:latest" \
        --build-arg RELEASE="${LATEST_RELEASE}" \
        --build-arg COMMIT_ID="${LATEST_COMMIT}" \
        -f Dockerfile .

    echo "==> Latest image built successfully:"
    echo "    - ${IMAGE_REPO}:${LATEST_RELEASE}"
    echo "    - ${IMAGE_REPO}:latest"
}

build_homelab() {
    echo "==> Building Homelab MinIO (${HOMELAB_RELEASE})..."
    local TMP_DIR
    TMP_DIR="$(mktemp -d -t minio-worktree-XXXXXX)"

    git worktree add --detach "$TMP_DIR" "$HOMELAB_RELEASE" >/dev/null
    cp "$REPO_ROOT/Dockerfile" "$TMP_DIR/Dockerfile"

    pushd "$TMP_DIR" >/dev/null
    docker build \
        -t "${IMAGE_REPO}:${HOMELAB_RELEASE}" \
        --build-arg RELEASE="${HOMELAB_RELEASE}" \
        --build-arg COMMIT_ID="${HOMELAB_COMMIT}" \
        -f Dockerfile .
    popd >/dev/null

    git worktree remove --force "$TMP_DIR" >/dev/null 2>&1 || rm -rf "$TMP_DIR"

    echo "==> Homelab image built successfully:"
    echo "    - ${IMAGE_REPO}:${HOMELAB_RELEASE}"
}

case "$ACTION" in
    all)
        build_latest
        build_homelab
        ;;
    homelab)
        build_homelab
        ;;
    latest)
        build_latest
        ;;
esac

if [ "$PUSH" = true ]; then
    echo "==> Pushing images to registry: ${IMAGE_REPO}..."
    if [ "$ACTION" = "all" ] || [ "$ACTION" = "homelab" ]; then
        docker push "${IMAGE_REPO}:${HOMELAB_RELEASE}"
    fi
    if [ "$ACTION" = "all" ] || [ "$ACTION" = "latest" ]; then
        docker push "${IMAGE_REPO}:${LATEST_RELEASE}"
        docker push "${IMAGE_REPO}:latest"
    fi
    echo "==> All images pushed successfully!"
fi

echo "==> Done!"
