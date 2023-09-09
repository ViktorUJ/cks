export DOCKER_CLI_EXPERIMENTAL=enabled
docker buildx create --name arm-builder --node=crossplat

docker buildx use arm-builder
docker buildx inspect --bootstrap
docker ps

docker buildx build --platform linux/arm64 --load -t viktoruj/cks-lab:arm64   .
docker buildx build --platform linux/amd64 --load -t viktoruj/cks-lab:amd64   .
docker push viktoruj/cks-lab:arm64
docker push viktoruj/cks-lab:amd64
docker manifest create viktoruj/cks-lab:latest viktoruj/cks-lab:arm64  viktoruj/cks-lab:amd64
docker manifest push viktoruj/cks-lab:latest


#docker build -t viktoruj/cks-lab:latest .
#docker push  viktoruj/cks-lab:latest
