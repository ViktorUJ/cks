docker buildx build --platform linux/arm64 --load -t viktoruj/runner:arm64  -f Dockerfile_ARM .
docker buildx build --platform linux/amd64 --load -t viktoruj/runner:amd64  -f Dockerfile_x86 .
docker push viktoruj/runner:arm64
docker push viktoruj/runner:amd64
docker manifest create viktoruj/runner:latest viktoruj/runner:arm64  viktoruj/runner:amd64
docker manifest push viktoruj/runner:latest

