docker build  --file Dockerfile1 --compress --no-cache -t viktoruj/cks-lab:cks_28_app1 .
docker push viktoruj/cks-lab:cks_28_app1

docker build --file Dockerfile1 --compress --no-cache -t viktoruj/cks-lab:cks_28_app2 .
docker push viktoruj/cks-lab:cks_28_app2

docker build --file Dockerfile2 --compress --no-cache -t viktoruj/cks-lab:cks_28_app3 .
docker push viktoruj/cks-lab:cks_28_app3