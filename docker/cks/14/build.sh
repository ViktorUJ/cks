docker build  --file Dockerfile1 --compress  -t viktoruj/cks-lab:cks_14_app1 .
docker push  viktoruj/cks-lab:cks_14_app1

docker build --file Dockerfile2 --compress  -t viktoruj/cks-lab:cks_14_app2 .
docker push  viktoruj/cks-lab:cks_14_app2
