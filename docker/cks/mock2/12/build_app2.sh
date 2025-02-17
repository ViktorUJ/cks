latest_commit_hash=$(git rev-parse --short HEAD)

docker buildx build --platform linux/arm64 --load -t viktoruj/cks-lab:${latest_commit_hash}-arm64-cks_mock2_12_app2  -f  Dockerfile2 .
docker buildx build --platform linux/amd64 --load -t viktoruj/cks-lab:${latest_commit_hash}-amd64-cks_mock2_12_app2  -f  Dockerfile2  .
docker push viktoruj/cks-lab:${latest_commit_hash}-arm64-cks_mock2_12_app2
docker push viktoruj/cks-lab:${latest_commit_hash}-amd64-cks_mock2_12_app2
docker manifest create viktoruj/cks-lab:${latest_commit_hash}-cks_mock2_12_app2  viktoruj/cks-lab:${latest_commit_hash}-arm64-cks_mock2_12_app2   viktoruj/cks-lab:${latest_commit_hash}-amd64-cks_mock2_12_app2
docker manifest push viktoruj/cks-lab:${latest_commit_hash}-cks_mock2_12_app2

docker manifest rm viktoruj/ping_pong:cks_mock2_12_app2
docker manifest create viktoruj/ping_pong:cks_mock2_12_app2 viktoruj/ping_pong:${latest_commit_hash}-arm64-cks_mock2_12_app2  viktoruj/ping_pong:${latest_commit_hash}-amd64-cks_mock2_12_app2
docker manifest push viktoruj/ping_pong:cks_mock2_12_app2