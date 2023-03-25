

#go build -ldflags="-w -s" app/app1.go
#go build -ldflags="-w -s" app/app2.go
docker build  --file Dockerfile1 -t viktoruj/cks-lab:cks_14_app1 .
#docker push  viktoruj/cks-lab:cks_14_app1
#docker build --file Dockerfile2   -t viktoruj/cks-lab:cks_14_app2 .
#docker push  viktoruj/cks-lab:cks_14_app2
#