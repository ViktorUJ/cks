FROM golang:alpine AS builder

RUN apk update && apk add --no-cache git
WORKDIR $GOPATH/src/mypackage/myapp/
COPY app/ .
RUN go mod tidy
RUN go build -ldflags="-w -s" -o app app.go

FROM scratch
COPY --from=builder /go/src/mypackage/myapp/app app
ENTRYPOINT ["/app"]
