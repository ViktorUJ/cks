# ping_pong
<p align="center">
    <a href="https://github.com/ViktorUJ/cks"><img src="https://raw.githubusercontent.com/ViktorUJ/terraform-aws-vpc/master/img/logo_192x192.png" width="192" height="192" alt="SRE Learning Platform"/></a>
</p>


This project is a small **HTTP server** that returns the incoming request with **metadata** in the response, including the sender's **IP address, all request parameters, and headers**. The server's configuration can be **modified** using **environment variables**. Additionally, the server supports **CPU and memory load** testing and provides **metrics in Prometheus** format. The **running server's** parameters can be **modified via API**.


The server can be run as a Docker container or Kubernetes resources for x86 or ARM platforms. It can also be run as compiled binary files or compiled from source code.

## Table of Contents
- [Usage Scenarios](#usage-scenarios)
  - [run http ping-pong server](#run-http-ping-pong-server)
  - [run http ping-pong server with custom server Name](#run-http-ping-pong-server--with-custom-server-name)
  - [run http ping-pong server  with serverName = podName](#run-http-ping-pong-server--with-servername--podname)
  - [run http ping-pong server with MEMORY_USAGE](#run-http-ping-pong-server--with-memory_usage)
  - [emulate crash app](#emulate-crash-app)
  - [run http ping-pong server  with response delay 3 seconds and 10 workers](#run-http-ping-pong-server--with-response-delay-3-seconds-and-10-workers)
  - [run http ping-pong server  with additional response size in Kb](#run-http-ping-pong-server--with-additional-response-size-in-kb)
- Run
  - [Docker](#run-docker-container)
    - [tags](#tags-)
  - [Kubernetes](#run-http-ping-pong-server)
  - [Binary](#binary) 
    - [Linux](#run-binary-on-linux)
    - [macOS](#run-binary-on-macos)
    - [Android](#run-binary-on-android)
  - [Compilation from Source Code](#compilation-from-source-code)
- [Configuration](#configuration)
- [gRPC](#grpc)
  - [What the gRPC server exposes](#what-the-grpc-server-exposes)
  - [Run the gRPC server](#run-the-grpc-server)
  - [Use the built-in gRPC client / load generator](#use-the-built-in-grpc-client--load-generator)
  - [Call it with grpcurl](#call-it-with-grpcurl)
  - [Check health with fortio / grpc_health_probe](#check-health-with-fortio--grpc_health_probe)
  - [gRPC in a service mesh (per-request load balancing)](#grpc-in-a-service-mesh-per-request-load-balancing)
  - [Proto definition and regeneration](#proto-definition-and-regeneration)
- [API](#api)
   - [getVar - get ping-pong variables](#get-variables)
   - [setVar - set ping-pong variables ](#set-variables) 
   - [osInfo - information about system ](#get-os-info)
   - [panic - emulate crash app](#emulate-crash-app)
   - [getMetric - get metric ](#get-metric)

   
## Usage Scenarios


### run http ping-pong server

```
kubectl  run test  --image  viktoruj/ping_pong
```

### run http ping-pong server  with custom **server Name**

```
kubectl  run test  --image  viktoruj/ping_pong  --env SERVER_NAME=pingPongServer
```

### run http ping-pong server  with serverName = podName

```
kubectl  run test  --image  viktoruj/ping_pong --env ENABLE_DEFAULT_HOSTNAME=false
```

### run http ping-pong server  with MEMORY_USAGE

```
kubectl  run test --image  viktoruj/ping_pong   --env MEMORY_USAGE_PROFILE='5=60  20=60   1024=360    ' --env ENABLE_LOAD_MEMORY=true
```

### run http ping-pong server  with MEMORY_USAGE and CPU_USAGE  and enable cpu and memory loging . It uses CPU_MAXPROC =2 .

```
kubectl  run test  --image  viktoruj/ping_pong  --env CPU_USAGE_PROFILE='1=400=1=60 1=4=1=60 10=1=4=60'  --env ENABLE_LOAD_CPU=true  --env ENABLE_LOG_LOAD_CPU=true --env CPU_MAXPROC=2 --env MEMORY_USAGE_PROFILE='5=60  20=60   1024=360  ' --env ENABLE_LOAD_MEMORY=true --env ENABLE_LOG_LOAD_MEMORY=true
```

### run http ping-pong server  with slow start 10 seconds.

```
kubectl  run test  --image  viktoruj/ping_pong  --env DELAY_START=10
```

### run http ping-pong server  with response delay 3 seconds and 10 workers.
``` 
kubectl  run test  --image  viktoruj/ping_pong --env  RESPONSE_DELAY=3000 --env  MAX_RESPONSE_WORKER=10
```

### run http ping-pong server  with additional response size in Kb.
``` 
kubectl  run test  --image  viktoruj/ping_pong --env  ADDITIONAL_RESPONSE_SIZE=1024
```

### Configuration


| ENV VAR                    | APP VAR                  | set via API | Description                                                                                                                                           |
|----------------------------|--------------------------|-------------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| `SERVER_NAME`              | `serverName`             |     Yes     | The name of the server. Default is `ping_pong_server`.                                                                                                |
| `ENABLE_DEFAULT_HOSTNAME`  | `enableDefaultHostName`  |     Yes     | Use the default hostname (default = "true").                                                                                                          |
| `SRV_PORT`                 | `serverPort`             |     No      | The port on which the server is running.                                                                                                              |
| `METRIC_PORT`              | `metricPort`             |     No      | The port where server metrics are available in Prometheus format. <br/> You can view the current metrics at `{server_address}:{METRIC_PORT}/metrics`. |
| `ENABLE_OUTPUT`            | `enableOutput`           |     Yes     | Log to stdout (default = "true").                                                                                                                     |
| `LOG_PATH`                 | `logPath`                |     Yes     | Write logs to file `${LOG_PATH}` (default="" without file output).                                                                                    |
| `ENABLE_LOAD_MEMORY`       | `enableLoadMemory`       |     Yes     | Enable memory usage (default=false).                                                                                                                  |
| `MEMORY_USAGE_PROFILE`     | `memoryProfileStr`       |     Yes     | Additional memory usage and time for usage. Example: `5=10 7=60 1024=360`.                                                                            |
| `ENABLE_LOG_LOAD_MEMORY`   | `enableLogLoadMemory`    |     Yes     | Logs LOAD_MEMORY function.                                                                                                                            |
| `ENABLE_LOAD_CPU`          | `enableLoadCpu`          |     Yes     | Enable CPU usage (default=false).                                                                                                                     |
| `ENABLE_LOG_LOAD_CPU`      | `enableLogLoadCpu`       |     Yes     | Logs LOAD_CPU function.                                                                                                                               |
| `CPU_USAGE_PROFILE`        | `cpuProfileStr`          |     Yes     | Additional CPU usage `iteraction_milion=wait_msec=gorutins=time_sec`. Example: `10=1=1=30 1=400=1=60`.                                                |
| `CPU_MAXPROC`              | `cpuMaxProc`             |     Yes     | GOMAXPROCS (default = 1). How many cores to use.                                                                                                      |
| `DELAY_START`              | `parsedDelay`            |     No      | Delay start in seconds before start app (default = 0). Useful for testing slow start of app and test startup probes.                                  |
| `RESPONSE_DELAY`           | `responseDelay`          |     Yes     | Response delay in milliseconds.                                                                                                                       |
| `MAX_RESPONSE_WORKER`      | `maxResponseWorker`      |     Yes     | Maximum number of response workers.                                                                                                                   |
| `ADDITIONAL_RESPONSE_SIZE` | `additionalResponseSize` |     Yes     | additional response size in Kb , default = 0                                                                                                          |
| `ENABLE_GRPC`              | -                        |     No      | Start the gRPC server (default = "true"; set "false" to disable).                                                                                     |
| `GRPC_PORT`                | -                        |     No      | Port for the gRPC server (default = `8079`).                                                                                                          |



## gRPC

Besides the HTTP server, `ping_pong` also runs a **gRPC server** (over HTTP/2) on a
separate port (default `8079`). It is enabled by default; the **same binary** can also act
as a gRPC **client / load generator**, so one image covers both the server and the client
side of a demo.

Control it with two environment variables (see also the [Configuration](#configuration)
table):

| ENV VAR       | Default | Description                                   |
|---------------|---------|-----------------------------------------------|
| `ENABLE_GRPC` | `true`  | Start the gRPC server. Set `false` to disable.|
| `GRPC_PORT`   | `8079`  | Port the gRPC server listens on.              |

The HTTP server (`8080`) and metrics (`9090`) keep working alongside gRPC.

### What the gRPC server exposes

- **`pingpong.PingPong/Echo`** - returns the request payload plus the serving pod identity:
  `message`, `server_name`, `hostname`, and a per-pod `count`. Because every reply carries
  the pod hostname, a client can **see which pod answered each call** - the direct way to
  prove per-request load balancing across replicas.
- **`grpc.health.v1.Health`** - the standard gRPC health service. Returns `SERVING`, so
  `fortio load -grpc`, `grpc_health_probe` and Istio/Kubernetes gRPC readiness probes work
  out of the box.
- **server reflection** - so tools like `grpcurl` can call the server without any `.proto`
  files.

### Run the gRPC server

```bash
# Docker: expose the gRPC port
docker run -d -p 8079:8079 viktoruj/ping_pong

# Kubernetes: gRPC on by default; make each pod report its real hostname
kubectl run grpc --image viktoruj/ping_pong --env ENABLE_DEFAULT_HOSTNAME=false

# disable gRPC / change the port
docker run -d -e ENABLE_GRPC=false -p 8080:8080 viktoruj/ping_pong
docker run -d -e GRPC_PORT=50051 -p 50051:50051 viktoruj/ping_pong
```

> Tip: set `ENABLE_DEFAULT_HOSTNAME=false` on the server so `Echo` returns the real pod
> hostname instead of the fixed default `ping_pong_server`. This is what makes the
> per-request balancing demo readable.

### Use the built-in gRPC client / load generator

The binary switches to client mode when the first argument is `-grpc-client`; it sends
`Echo` requests, prints which pod answered each one, then prints a summary and exits.

```bash
# from any pod/host that has the binary or the image
/app -grpc-client -target grpc-server:8079 -n 180 -c 4

# inside Kubernetes (exec into a pod running the image)
kubectl exec -it deploy/grpc-client -- /app -grpc-client -target grpc-server:8079 -n 180
```

Client flags:

| Flag       | Default          | Description                                       |
|------------|------------------|---------------------------------------------------|
| `-target`  | `localhost:8079` | gRPC server `host:port`.                          |
| `-n`       | `100`            | Number of `Echo` requests to send.                |
| `-c`       | `1`              | Parallel workers sharing the channel.             |
| `-message` | `ping`           | Payload string echoed back.                       |
| `-timeout` | `30s`            | Overall deadline for the run.                     |
| `-quiet`   | `false`          | Print only the summary (no per-request lines).    |

Example output:

```
req 1 from host=grpc-server-6d4f-aaaaa server=grpc-server-6d4f-aaaaa count=1
req 2 from host=grpc-server-6d4f-bbbbb server=grpc-server-6d4f-bbbbb count=1
...
--- summary ---
requests: 180  ok: 180  errors: 0
distinct servers: 3
host grpc-server-6d4f-aaaaa: 60
host grpc-server-6d4f-bbbbb: 60
host grpc-server-6d4f-ccccc: 60
```

`distinct servers: N` is the key line - it tells you how many backend pods actually
answered. The process exits `0` if at least one request succeeded, otherwise `1`.

### Call it with grpcurl

Server reflection is enabled, so no `.proto` files are needed:

```bash
# list services and methods
grpcurl -plaintext localhost:8079 list
grpcurl -plaintext localhost:8079 describe pingpong.PingPong

# call Echo
grpcurl -plaintext -d '{"message":"hello"}' localhost:8079 pingpong.PingPong/Echo
# -> { "message": "hello", "serverName": "...", "hostname": "...", "count": "1" }

# health check
grpcurl -plaintext localhost:8079 grpc.health.v1.Health/Check
# -> { "status": "SERVING" }
```

### Check health with fortio / grpc_health_probe

```bash
# fortio uses the standard gRPC health service
fortio load -grpc -n 50 localhost:8079        # reports "Health SERVING : 50"

# grpc_health_probe (handy as a Kubernetes probe)
grpc_health_probe -addr=localhost:8079        # -> status: SERVING
```

Kubernetes gRPC readiness probe example:

```yaml
readinessProbe:
  grpc:
    port: 8079
  initialDelaySeconds: 2
```

### gRPC in a service mesh (per-request load balancing)

gRPC is **HTTP/2, not raw TCP**. In a mesh (e.g. Istio) the service port must be named
`grpc` / `grpc-*` or carry `appProtocol: grpc`, otherwise the proxy treats it as L4 TCP,
pins the single long-lived connection to one pod, and the client sees `distinct servers:
1`. With the port declared as gRPC, the proxy balances **each request** and the client
sees `distinct servers: 3`. A full worked example is ICA
[Lab 32](../../tasks/ica/labs/32/README.MD).

### Proto definition and regeneration

The service is defined in [`app/proto/pingpong.proto`](app/proto/pingpong.proto). The
generated Go code (`*.pb.go`) is committed, so the Docker build stays a plain `go build`.
Regenerate it only when you change the `.proto`:

```bash
cd docker/ping_pong/app
# needs: buf, protoc-gen-go, protoc-gen-go-grpc on PATH
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
buf generate
# generated files land next to buf.yaml; keep them under app/proto/
```

### run Docker container
```
docker run -d -p 8080:8080 viktoruj/ping_pong
```

### tags :
The images work on **x86** and **ARM** platforms.

- `latest` - from **scratch** image with **only binary**. [Dockerfile](Dockerfile)
- `alpine` - **alpine** image with **binary** and **utils**. [Dockerfile_alpine](Dockerfile_alpine)
- `debug` - **amazon/aws-cli** image with **utils**. [Dockerfile_debug_arm](Dockerfile_debug_arm)  and [Dockerfile_debug_x86](Dockerfile_debug_x86) .

### binary

- [windows x86](https://sre-platform.aws-guru.com/download/pingpong/ping-pong-windows-amd64.exe)
- [windows arm64](https://sre-platform.aws-guru.com/download/pingpong/ping-pong-windows-arm64.exe)
- [linux arm64](https://sre-platform.aws-guru.com/download/pingpong/ping-pong-linux-arm64)
- [linux x86](https://sre-platform.aws-guru.com/download/pingpong/ping-pong-linux-amd64)
- [linux arm](https://sre-platform.aws-guru.com/download/pingpong/ping-pong-linux-arm)
- [darwin x86](https://sre-platform.aws-guru.com/download/pingpong/ping-pong-darwin-amd64)
- [darwin arm64](https://sre-platform.aws-guru.com/download/pingpong/ping-pong-darwin-arm64)
- [android arm64](https://sre-platform.aws-guru.com/download/pingpong/ping-pong-android-arm64)

### run binary on macOS

```bash 
sudo xattr -d com.apple.quarantine ping-pong-darwin-amd64
sudo chmod +x ping-pong-darwin-amd64
./ping-pong-darwin-amd64 
# or
SERVER_NAME=myCustomServer ./ping-pong-linux-amd64

# check server 
curl 127.0.0.1:8080

```

### run binary on linux

```bash
sudo chmod +x ping-pong-linux-amd64
./ping-pong-linux-amd64
# or
SERVER_NAME=myCustomServer ./ping-pong-linux-amd64

# check server 
curl 127.0.0.1:8080

```

### run binary on android

- use Termux

```bash 
copy ping-pong-android-arm64  to /data/data/com.termux/files/usr/bin/
chmod +x /data/data/com.termux/files/usr/bin/ping-pong-android-arm64
ping-pong-android-arm64 
```

### Compilation from Source Code

```bash
cd docker/ping_pong/app
go mod tidy
go run . # or go build .

```

### api

- `/ping-pong-api/getVar` - get all ping-pong variables
- `/ping-pong-api/setVar` - set ping-pong variables
- `/ping-pong-api/osInfo` - get os info
- `/ping-pong-api/panic`  - emulate crash app
- `/ping-pong-api/getMetric` - get metric

### api examples


#### get variables

```
curl {ping-pong ip}:8080/ping-pong-api/getVar  -s | jq 
```
``` 
{
  "cpuMaxProc": 2,
  "cpuProfileStr": "1000=1=1=30",
  "delayStart": 0,
  "enableDefaultHostName": "true",
  "enableLoadCpu": "true",
  "enableLoadMemory": "false",
  "enableLogLoadCpu": "true",
  "enableLogLoadMemory": "false",
  "enableOutput": "true",
  "hostName": "ping_pong_server",
  "logPath": "",
  "memoryProfiles": null,
  "serverName": "ping_pong_server"
}

```

#### set variables

```
curl -X POST "http://{ping-pong ip}:8080/ping-pong-api/setVar" -H "Content-Type: application/json" -d '{"enableLoadCpu":"true", "cpuProfileStr":"1000=1=1=30","cpuMaxProc":2}' -s | jq
```

``` 
{
  "changes": {
    "cpuMaxProc": {
      "new": "2",
      "old": "1"
    },
    "cpuProfileStr": {
      "new": "1000=1=1=30",
      "old": "1000=1=2=30"
    },
    "enableLoadCpu": {
      "new": "true",
      "old": "false"
    }
  },
  "status": "Variables updated. Handlers reloaded."
}

```

#### get os info
```
curl {ping-pong ip}:8080/ping-pong-api/osInfo  -s | jq

```

```
{
  "architecture": {
    "architecture": "amd64",
    "goamd64": "v4",
    "goarm": ""
  },
  "cpu": {
    "cores": [
      {
        "core": 1,
        "unit": "percentage",
        "usage": 13.7
      },
      {
        "core": 2,
        "unit": "percentage",
        "usage": 7.6
      },

.............

```
#### get metric
```
curl {ping-pong ip}:8080/ping-pong-api/getMetric  -s | jq

```

```
{
  "goroutines": 6,
  "requests_per_minute": 0,
  "requests_per_second": 0,
  "requests_total": 0
}


```
#### emulate crash app
```
curl {ping-pong ip}:8080/ping-pong-api/panic  -s 

```

```
# in app log

Panic occurred: Test panic
exit status 1
 
```