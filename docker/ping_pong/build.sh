docker buildx build --platform linux/arm64 --load -t viktoruj/ping_pong:arm64   .
docker buildx build --platform linux/amd64 --load -t viktoruj/ping_pong:amd64   .
docker push viktoruj/ping_pong:arm64
docker push viktoruj/ping_pong:amd64
docker manifest create viktoruj/ping_pong:latest viktoruj/ping_pong:arm64  viktoruj/ping_pong:amd64
docker manifest push viktoruj/ping_pong:latest