This is a small HTTP server that sends back the incoming request with all the metadata in response, including the sender's IP address, all request parameters, and headers. The server's configuration can be modified using environment variables:

- `SERVER_NAME`: The name of the server.
- `SRV_PORT`: The port on which the server is running.
- `METRIC_PORT`: The port where server metrics are available in Prometheus format.
- `ENABLE_OUTPUT`: log to stdout (default = "true")
- `LOG_PATH`: write logs to file ${LOG_PATH} (default=""  without file output)

You can view the current metrics at `{server_address}:{METRIC_PORT}/metrics`.

`docker pull viktoruj/ping_pong`
