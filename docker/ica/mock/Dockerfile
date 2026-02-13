FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY go.mod ./
COPY main.go ./

RUN go build -o echo-version main.go

FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/echo-version .

EXPOSE 8080
CMD ["./echo-version"]
