#!/usr/bin/env bash
latest_commit_hash=$(git rev-parse --short HEAD)

while [[ $# > 0 ]]; do
    key="$1"
    case "$key" in
      --release)
         release="$2"
         shift
      ;;
      *)
      ;;
    esac
    shift
done

if [ -z "$release" ]; then
     release="dev"
fi

echo "*** release = $release"

case $release in
scratch)
   docker buildx build --platform linux/arm64 --load -t viktoruj/ping_pong_front:${latest_commit_hash}-arm64 .
   docker buildx build --platform linux/amd64 --load -t viktoruj/ping_pong_front:${latest_commit_hash}-amd64 .
   docker push viktoruj/ping_pong_front:${latest_commit_hash}-arm64
   docker push viktoruj/ping_pong_front:${latest_commit_hash}-amd64
   docker manifest create viktoruj/ping_pong_front:${latest_commit_hash} \
     viktoruj/ping_pong_front:${latest_commit_hash}-arm64 \
     viktoruj/ping_pong_front:${latest_commit_hash}-amd64
   docker manifest push viktoruj/ping_pong_front:${latest_commit_hash}
   docker manifest rm viktoruj/ping_pong_front:latest || true
   docker manifest create viktoruj/ping_pong_front:latest \
     viktoruj/ping_pong_front:${latest_commit_hash}-arm64 \
     viktoruj/ping_pong_front:${latest_commit_hash}-amd64
   docker manifest push viktoruj/ping_pong_front:latest
;;
dev)
   docker buildx build --platform linux/arm64 --load -t viktoruj/ping_pong_front:${latest_commit_hash}-arm64 .
   docker buildx build --platform linux/amd64 --load -t viktoruj/ping_pong_front:${latest_commit_hash}-amd64 .
   docker push viktoruj/ping_pong_front:${latest_commit_hash}-arm64
   docker push viktoruj/ping_pong_front:${latest_commit_hash}-amd64
   docker manifest create viktoruj/ping_pong_front:${latest_commit_hash} \
     viktoruj/ping_pong_front:${latest_commit_hash}-arm64 \
     viktoruj/ping_pong_front:${latest_commit_hash}-amd64
   docker manifest push viktoruj/ping_pong_front:${latest_commit_hash}
;;
esac
