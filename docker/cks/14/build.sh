go build -ldflags="-w -s" app/app1.go
go build -ldflags="-w -s" app/app2.go
docker build Dockerfile1 --file -t viktoruj/cks-lab:cks_14_app1 .
docker push  viktoruj/cks-lab:cks_14_app1
docker build Dockerfile2 --file -t viktoruj/cks-lab:cks_14_app2 .
docker push  viktoruj/cks-lab:cks_14_app2
