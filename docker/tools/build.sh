docker buildx build --platform linux/arm64 --load -t viktoruj/tools:arm64  -f Dockerfile_ARM .
docker buildx build --platform linux/amd64 --load -t viktoruj/tools:amd64  -f Dockerfile_x86 .
docker push viktoruj/tools:arm64
docker push viktoruj/tools:amd64
docker manifest create viktoruj/tools:latest viktoruj/tools:arm64  viktoruj/tools:amd64
#docker manifest create viktoruj/tools:latest  viktoruj/tools:amd64
docker manifest push viktoruj/tools:latest
