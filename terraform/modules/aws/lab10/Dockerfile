FROM golang:1.24 as builder

WORKDIR /app

COPY . .

# Статическая компиляция Go кода
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o main main.go

FROM public.ecr.aws/lambda/provided:al2
RUN yum install -y wget python3 bash

COPY --from=builder /app/main /var/runtime/

RUN wget -O /var/runtime/server-binary-v2.py https://ws-assets-prod-iad-r-fra-b129423e91500967.s3.amazonaws.com/5fb682bf-699a-4972-848b-ab4a1ec243d5/server-binary-v2.py
COPY bootstrap /var/runtime/

RUN chmod +x /var/runtime/bootstrap

CMD ["/var/runtime/main"]