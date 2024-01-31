This is a small HTTP server that sends back the incoming request with all the metadata in response, including the sender's IP address, all request parameters, and headers. The server's configuration can be modified using environment variables:

- `SERVER_NAME`: The name of the server.
- `SRV_PORT`: The port on which the server is running.
- `METRIC_PORT`: The port where server metrics are available in Prometheus format.
- `ENABLE_OUTPUT`: log to stdout (default = "true")
- `LOG_PATH`: write logs to file ${LOG_PATH} (default=""  without file output)
- `ENABLE_LOAD_MEMORY` : enable memory usage (default=false)
- `MEMORY_USAGE_PROFILE`: additional memory usage  and time for usage . example `5=10 7=60  1024=360  ` - 5 Mb 10sec  7 Mb 60sec 1024Mb 360sec
- `ENABLE_LOG_LOAD_MEMORY`: logs LOAD_MEMORY function
- `ENABLE_LOAD_CPU` : enable cpu usage (default=false)
- `ENABLE_LOG_LOAD_CPU`: logs LOAD_CPU function
- `CPU_USAGE_PROFILE`: additional CPU usage `iteraction_milion=wait_msec=gorutins=time_sec` . example  `10=1=1=30  1=400=1=60`
- `CPU_MAXPROC`: GOMAXPROCS (default = 1)

You can view the current metrics at `{server_address}:{METRIC_PORT}/metrics`.

`docker pull viktoruj/ping_pong`

##  examples

### run http pingPong server
```
kubectl  run test -n circleci --image  viktoruj/ping_pong
```

### run http pingPong server  with serverName
```
kubectl  run test -n circleci --image  viktoruj/ping_pong  --env SERVER_NAME=pingPongServer
```

### run http pingPong server  with MEMORY_USAGE
```
kubectl  run test -n circleci --image  viktoruj/ping_pong   --env MEMORY_USAGE_PROFILE='5=60  20=60   1024=360    ' --env ENABLE_LOAD_MEMORY=true
```
### run http pingPong server  with MEMORY_USAGE and CPU_USAGE  and enable cpu and memory loging . It uses CPU_MAXPROC =2 .
```
kubectl  run test  --image  viktoruj/ping_pong  --env CPU_USAGE_PROFILE='1=400=1=60 1=4=1=60 10=1=4=60'  --env ENABLE_LOAD_CPU=true  --env ENABLE_LOG_LOAD_CPU=true --env CPU_MAXPROC=2 --env MEMORY_USAGE_PROFILE='5=60  20=60   1024=360  ' --env ENABLE_LOAD_MEMORY=true --env ENABLE_LOG_LOAD_MEMORY=true
```
