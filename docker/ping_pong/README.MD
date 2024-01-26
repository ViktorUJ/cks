This is a small HTTP server that sends back the incoming request with all the metadata in response, including the sender's IP address, all request parameters, and headers. The server's configuration can be modified using environment variables:

- `SERVER_NAME`: The name of the server.
- `SRV_PORT`: The port on which the server is running.
- `METRIC_PORT`: The port where server metrics are available in Prometheus format.
- `ENABLE_OUTPUT`: log to stdout (default = "true")
- `LOG_PATH`: write logs to file ${LOG_PATH} (default=""  without file output)
- `ENABLE_LOAD_CPU` : enable cpu usage (default=false)
- `ENABLE_LOAD_MEMORY` : enable memory usage (default=false)
- `MEMORY_USAGE_PROFILE`: additional memory usage  and time for usage . example `5=10 7=60  1024=360  ` - 5 Mb 10sec  7 Mb 60sec 1024Mb 360sec
- `MEMORY_USAGE_MIN`: additional memory usage Mb (default=1)
- `MEMORY_USAGE_MAX`: additional memory usage Mb (default=1)
- `MEMORY_USAGE_INCREASE_TIME`: time seconds  to  set MEMORY_USAGE_MAX  (default=60)
- `MEMORY_USAGE_INCREASE_STEPS_WAIT`: time seconds  to next increase (default=1)
- `MEMORY_USAGE_INCREASE_LOOP_WAIT`: time seconds  wait start next memory loop usage (default=1) . new loop start from `MEMORY_USAGE_MIN`
- `CPU_MAXPROC`: GOMAXPROCS (default = 1)
- `CPU_PI_ITERATIONS`: calculatePi   iterations  (default=10000000)

You can view the current metrics at `{server_address}:{METRIC_PORT}/metrics`.

`docker pull viktoruj/ping_pong`
