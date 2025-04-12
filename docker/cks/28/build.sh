# docker build  --file Dockerfile1 --compress --no-cache -t viktoruj/cks-lab:cks_28_app1 .
# docker push viktoruj/cks-lab:cks_28_app1

# docker build --file Dockerfile1 --compress --no-cache -t viktoruj/cks-lab:cks_28_app2 .
# docker push viktoruj/cks-lab:cks_28_app2

# docker build --file Dockerfile2 --compress --no-cache -t viktoruj/cks-lab:cks_28_app3 .
# docker push viktoruj/cks-lab:cks_28_app3

REG="public.ecr.aws/v8u2l1s7/vitdevops/cks-lab"

docker build --file Dockerfile1 --compress -t $REG:cks_28_app1 .
docker push $REG:cks_28_app1

docker build --file Dockerfile1 --compress -t $REG:cks_28_app2 .
docker push $REG:cks_28_app2

docker build --file Dockerfile2 --compress -t $REG:cks_28_app3 .
docker push $REG:cks_28_app3