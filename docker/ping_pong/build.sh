latest_commit_hash=$(git rev-parse --short HEAD)

docker buildx build --platform linux/arm64 --load -t viktoruj/ping_pong:${latest_commit_hash}-arm64   .
docker buildx build --platform linux/amd64 --load -t viktoruj/ping_pong:${latest_commit_hash}-amd64   .
docker push viktoruj/ping_pong:${latest_commit_hash}-arm64
docker push viktoruj/ping_pong:${latest_commit_hash}-amd64
docker manifest create viktoruj/ping_pong:${latest_commit_hash} viktoruj/ping_pong:${latest_commit_hash}-arm64  viktoruj/ping_pong:${latest_commit_hash}-amd64
docker manifest push viktoruj/ping_pong:${latest_commit_hash}

