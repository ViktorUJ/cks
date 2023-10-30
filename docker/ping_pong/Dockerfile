FROM golang:alpine AS builder

RUN apk update && apk add --no-cache git
WORKDIR $GOPATH/src/mypackage/myapp/
COPY app/app.go app.go
COPY app/go.mod go.mod
RUN go mod download
RUN go build -ldflags="-w -s" app.go

FROM scratch
COPY --from=builder /go/src/mypackage/myapp/app app
ENTRYPOINT ["/app"]
