docker buildx build --platform linux/arm64 --load -t viktoruj/cks-lab:cks_28_app1_arm  -f  Dockerfile1 .
docker buildx build --platform linux/amd64 --load -t viktoruj/cks-lab:cks_28_app1_x86  -f  Dockerfile1  .
docker push viktoruj/cks-lab:cks_28_app1_arm
docker push viktoruj/cks-lab:cks_28_app1_x86
docker manifest create viktoruj/cks-lab:cks_28_app1  viktoruj/cks-lab:cks_28_app1_arm viktoruj/cks-lab:cks_28_app1_x86
docker manifest push viktoruj/cks-lab:cks_28_app1


docker buildx build --platform linux/arm64 --load -t viktoruj/cks-lab:cks_28_app2_arm  -f  Dockerfile1 .
docker buildx build --platform linux/amd64 --load -t viktoruj/cks-lab:cks_28_app2_x86  -f  Dockerfile1  .
docker push viktoruj/cks-lab:cks_28_app2_arm
docker push viktoruj/cks-lab:cks_28_app2_x86
docker manifest create viktoruj/cks-lab:cks_28_app2  viktoruj/cks-lab:cks_28_app2_arm viktoruj/cks-lab:cks_28_app2_x86
docker manifest push viktoruj/cks-lab:cks_28_app2

docker buildx build --platform linux/arm64 --load -t viktoruj/cks-lab:cks_28_app3_arm  -f  Dockerfile2 .
docker buildx build --platform linux/amd64 --load -t viktoruj/cks-lab:cks_28_app3_x86  -f  Dockerfile2  .
docker push viktoruj/cks-lab:cks_28_app3_arm
docker push viktoruj/cks-lab:cks_28_app3_x86
docker manifest create viktoruj/cks-lab:cks_28_app3  viktoruj/cks-lab:cks_28_app3_arm viktoruj/cks-lab:cks_28_app3_x86
docker manifest push viktoruj/cks-lab:cks_28_app3
