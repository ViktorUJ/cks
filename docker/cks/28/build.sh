docker buildx build --platform linux/arm64 --load -t viktoruj/cks-lab:cks_28_app1_arm  -f  Dockerfile1 .
docker buildx build --platform linux/amd64 --load -t viktoruj/cks-lab:cks_28_app1_x86  -f  Dockerfile1  .
docker manifest create viktoruj/cks-lab:cks_28_app1    viktoruj/cks-lab:cks_28_app1_arm viktoruj/cks-lab:cks_28_app1_x86
docker manifest push viktoruj/cks-lab:cks_28_app1

exit 0
docker build  --file Dockerfile1 --compress --no-cache -t viktoruj/cks-lab:cks_28_app1 .
docker push viktoruj/cks-lab:cks_28_app1

docker build --file Dockerfile1 --compress --no-cache -t viktoruj/cks-lab:cks_28_app2 .
docker push viktoruj/cks-lab:cks_28_app2

docker build --file Dockerfile2 --compress --no-cache -t viktoruj/cks-lab:cks_28_app3 .
docker push viktoruj/cks-lab:cks_28_app3