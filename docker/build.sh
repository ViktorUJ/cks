docker buildx build --platform linux/arm64 --load -t viktoruj/cks-lab:arm64   .
docker buildx build --platform linux/amd64 --load -t viktoruj/cks-lab:amd64   .
docker push viktoruj/cks-lab:arm64
docker push viktoruj/cks-lab:amd64
docker manifest create viktoruj/cks-lab:latest viktoruj/cks-lab:arm64  viktoruj/cks-lab:amd64
docker manifest push viktoruj/cks-lab:latest
