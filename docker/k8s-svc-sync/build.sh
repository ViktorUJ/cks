#!/usr/bin/env bash
set -euo pipefail

latest_commit_hash=$(git rev-parse --short HEAD)

# ---------- parse CLI ----------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --release) release="$2"; shift ;;
    *) ;;
  esac
  shift
done
release=${release:-dev}
echo "*** release = ${release}"

# ---------- cross-build binaries ----------
build_cross_binaries() {
  echo "=== Starting cross-compilation inside Docker ==="
  mkdir -p dist

  docker run --rm \
    -v "$(pwd)":/app \
    -w /app/app \
    golang:alpine \
    sh -c "
      apk add --no-cache git
      go mod tidy

      CGO_ENABLED=0 GOOS=linux   GOARCH=amd64 go build -ldflags='-w -s' -o ../dist/ping-pong-linux-amd64   app.go
      CGO_ENABLED=0 GOOS=linux   GOARCH=arm64 go build -ldflags='-w -s' -o ../dist/ping-pong-linux-arm64   app.go
      CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build -ldflags='-w -s' -o ../dist/ping-pong-windows-amd64.exe app.go
      CGO_ENABLED=0 GOOS=windows GOARCH=arm64 go build -ldflags='-w -s' -o ../dist/ping-pong-windows-arm64.exe app.go
    "

  pushd app >/dev/null
    go mod tidy
    CGO_ENABLED=1 GOOS=darwin GOARCH=amd64 go build -ldflags='-w -s' -o ../dist/ping-pong-darwin-amd64 app.go
    CGO_ENABLED=1 GOOS=darwin GOARCH=arm64 go build -ldflags='-w -s' -o ../dist/ping-pong-darwin-arm64 app.go
  popd >/dev/null
  chmod +x dist/ping-pong-darwin-*
  echo "=== Cross-compilation finished (./dist) ==="
}

# ---------- main switch ----------
case $release in
  bin)
    build_cross_binaries
    ;;
  bin_deploy)
    aws s3 cp ./dist s3://sre-platform.aws-guru.com/download/pingpong/ --recursive --profile deploy
    aws cloudfront create-invalidation --distribution-id E1HF54QM48F9SB --paths "/download/pingpong/*" --profile deploy
    ;;

  scratch)
    rm -rf "${DOCKER_CONFIG:-$HOME/.docker}/manifests"
    docker buildx build --platform linux/arm64 --load -t viktoruj/k8s-svc-sync:${latest_commit_hash}-arm64 .
    docker buildx build --platform linux/amd64 --load -t viktoruj/k8s-svc-sync:${latest_commit_hash}-amd64 .
    docker push viktoruj/k8s-svc-sync:${latest_commit_hash}-arm64
    docker push viktoruj/k8s-svc-sync:${latest_commit_hash}-amd64
    docker manifest create viktoruj/k8s-svc-sync:${latest_commit_hash} \
      viktoruj/k8s-svc-sync:${latest_commit_hash}-arm64 \
      viktoruj/k8s-svc-sync:${latest_commit_hash}-amd64
    docker manifest push viktoruj/k8s-svc-sync:${latest_commit_hash}

    echo "*** do release"
    docker manifest rm viktoruj/k8s-svc-sync:latest || true
    docker manifest create viktoruj/k8s-svc-sync:latest \
      viktoruj/k8s-svc-sync:${latest_commit_hash}-arm64 \
      viktoruj/k8s-svc-sync:${latest_commit_hash}-amd64
    docker manifest push viktoruj/k8s-svc-sync:latest
    ;;

  alpine)
    echo "*** do release alpine"
    rm -rf "${DOCKER_CONFIG:-$HOME/.docker}/manifests"
    docker buildx build --platform linux/arm64 --load -t viktoruj/k8s-svc-sync:${latest_commit_hash}-arm64-alpine -f Dockerfile_alpine .
    docker buildx build --platform linux/amd64 --load -t viktoruj/k8s-svc-sync:${latest_commit_hash}-amd64-alpine -f Dockerfile_alpine .
    docker push viktoruj/k8s-svc-sync:${latest_commit_hash}-arm64-alpine
    docker push viktoruj/k8s-svc-sync:${latest_commit_hash}-amd64-alpine
    docker manifest create viktoruj/k8s-svc-sync:${latest_commit_hash}-alpine \
      viktoruj/k8s-svc-sync:${latest_commit_hash}-arm64-alpine \
      viktoruj/k8s-svc-sync:${latest_commit_hash}-amd64-alpine
    docker manifest push viktoruj/k8s-svc-sync:${latest_commit_hash}-alpine

    docker manifest rm viktoruj/k8s-svc-sync:alpine || true
    docker manifest create viktoruj/k8s-svc-sync:alpine \
      viktoruj/k8s-svc-sync:${latest_commit_hash}-arm64-alpine \
      viktoruj/k8s-svc-sync:${latest_commit_hash}-amd64-alpine
    docker manifest push viktoruj/k8s-svc-sync:alpine
    ;;

  debug)
    echo "*** do release debug"
    rm -rf "${DOCKER_CONFIG:-$HOME/.docker}/manifests"
    docker buildx build --platform linux/arm64 --load -t viktoruj/k8s-svc-sync:${latest_commit_hash}-arm64-debug -f Dockerfile_debug_arm .
    docker buildx build --platform linux/amd64 --load -t viktoruj/k8s-svc-sync:${latest_commit_hash}-amd64-debug -f Dockerfile_debug_x86 .
    docker push viktoruj/k8s-svc-sync:${latest_commit_hash}-arm64-debug
    docker push viktoruj/k8s-svc-sync:${latest_commit_hash}-amd64-debug
    docker manifest create viktoruj/k8s-svc-sync:${latest_commit_hash}-debug \
      viktoruj/k8s-svc-sync:${latest_commit_hash}-arm64-debug \
      viktoruj/k8s-svc-sync:${latest_commit_hash}-amd64-debug
    docker manifest push viktoruj/k8s-svc-sync:${latest_commit_hash}-debug

    docker manifest rm viktoruj/k8s-svc-sync:debug || true
    docker manifest create viktoruj/k8s-svc-sync:debug \
      viktoruj/k8s-svc-sync:${latest_commit_hash}-arm64-debug \
      viktoruj/k8s-svc-sync:${latest_commit_hash}-amd64-debug
    docker manifest push viktoruj/k8s-svc-sync:debug
    ;;

  dev|*)
    rm -rf "${DOCKER_CONFIG:-$HOME/.docker}/manifests"
    docker buildx build --platform linux/arm64 --load -t viktoruj/k8s-svc-sync:${latest_commit_hash}-arm64 .
    docker buildx build --platform linux/amd64 --load -t viktoruj/k8s-svc-sync:${latest_commit_hash}-amd64 .
    docker push viktoruj/k8s-svc-sync:${latest_commit_hash}-arm64
    docker push viktoruj/k8s-svc-sync:${latest_commit_hash}-amd64
    docker manifest create viktoruj/k8s-svc-sync:${latest_commit_hash} \
      viktoruj/k8s-svc-sync:${latest_commit_hash}-arm64 \
      viktoruj/k8s-svc-sync:${latest_commit_hash}-amd64
    docker manifest push viktoruj/k8s-svc-sync:${latest_commit_hash}

    echo "*** not need release"
    ;;
esac
