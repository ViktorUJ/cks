package main

import (
	"context"
	"flag"
	"fmt"
	"net"
	"os"
	"sort"
	"sync"
	"sync/atomic"
	"time"

	pb "mypackage/myapp/proto"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"
)

// grpcRequestsCount is a per-pod monotonic counter of served Echo requests.
var grpcRequestsCount uint64

// pingPongServer implements the PingPong gRPC service. Every reply carries the
// serving pod identity (serverName/hostName), which lets a client prove that
// per-request load balancing spreads calls across replicas.
type pingPongServer struct {
	pb.UnimplementedPingPongServer
}

func (s *pingPongServer) Echo(ctx context.Context, req *pb.EchoRequest) (*pb.EchoReply, error) {
	n := atomic.AddUint64(&grpcRequestsCount, 1)
	atomic.AddUint64(&requestsCount, 1)
	return &pb.EchoReply{
		Message:    req.GetMessage(),
		ServerName: serverName,
		Hostname:   hostName,
		Count:      n,
	}, nil
}

// startGRPCServer starts the gRPC server (PingPong + standard Health +
// reflection) unless ENABLE_GRPC=false. Port is GRPC_PORT (default 8079).
func startGRPCServer() {
	if os.Getenv("ENABLE_GRPC") == "false" {
		return
	}
	port := os.Getenv("GRPC_PORT")
	if port == "" {
		port = "8079"
	}

	lis, err := net.Listen("tcp", ":"+port)
	if err != nil {
		sendLog(fmt.Sprintf("gRPC listen on :%s failed: %v", port, err))
		return
	}

	s := grpc.NewServer()
	pb.RegisterPingPongServer(s, &pingPongServer{})

	// Standard gRPC health service so `fortio load -grpc`, grpc_health_probe
	// and Istio readiness checks report SERVING.
	hs := health.NewServer()
	hs.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)
	hs.SetServingStatus("pingpong.PingPong", healthpb.HealthCheckResponse_SERVING)
	healthpb.RegisterHealthServer(s, hs)

	// Server reflection so tools like grpcurl work without .proto files.
	reflection.Register(s)

	sendLog("start gRPC server on port: " + port)
	if err := s.Serve(lis); err != nil {
		sendLog(fmt.Sprintf("gRPC server failed: %v", err))
	}
}

// runGRPCClientIfRequested inspects the CLI args. If the first argument is
// "-grpc-client", it runs the gRPC client (an Echo load generator) and exits
// the process. Otherwise it returns and normal server startup continues.
//
// Usage:
//
//	app -grpc-client -target host:port [-n N] [-c conns] [-message text]
//
// The client sends N Echo requests, prints which pod answered each one, and
// prints a summary with the count of distinct serving pods. That distinct
// count is the direct proof of per-request gRPC load balancing.
func runGRPCClientIfRequested() {
	if len(os.Args) < 2 || os.Args[1] != "-grpc-client" {
		return
	}

	fs := flag.NewFlagSet("grpc-client", flag.ExitOnError)
	target := fs.String("target", "localhost:8079", "gRPC server target host:port")
	num := fs.Int("n", 100, "number of Echo requests to send")
	conns := fs.Int("c", 1, "number of parallel workers sharing the channel")
	message := fs.String("message", "ping", "payload to send")
	timeout := fs.Duration("timeout", 30*time.Second, "overall timeout")
	quiet := fs.Bool("quiet", false, "print only the summary")
	_ = fs.Parse(os.Args[2:])

	if *conns < 1 {
		*conns = 1
	}

	conn, err := grpc.NewClient(*target, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		fmt.Printf("gRPC dial %s failed: %v\n", *target, err)
		os.Exit(1)
	}
	defer conn.Close()
	client := pb.NewPingPongClient(conn)

	ctx, cancel := context.WithTimeout(context.Background(), *timeout)
	defer cancel()

	var (
		mu       sync.Mutex
		perHost  = map[string]int{}
		okCount  int
		errCount int
		wg       sync.WaitGroup
	)

	jobs := make(chan int)
	worker := func() {
		defer wg.Done()
		for i := range jobs {
			resp, err := client.Echo(ctx, &pb.EchoRequest{Message: *message})
			mu.Lock()
			if err != nil {
				errCount++
				if !*quiet {
					fmt.Printf("req %d error: %v\n", i+1, err)
				}
			} else {
				okCount++
				perHost[resp.GetHostname()]++
				if !*quiet {
					fmt.Printf("req %d from host=%s server=%s count=%d\n",
						i+1, resp.GetHostname(), resp.GetServerName(), resp.GetCount())
				}
			}
			mu.Unlock()
		}
	}

	wg.Add(*conns)
	for w := 0; w < *conns; w++ {
		go worker()
	}
	for i := 0; i < *num; i++ {
		jobs <- i
	}
	close(jobs)
	wg.Wait()

	hosts := make([]string, 0, len(perHost))
	for h := range perHost {
		hosts = append(hosts, h)
	}
	sort.Strings(hosts)

	fmt.Println("--- summary ---")
	fmt.Printf("requests: %d  ok: %d  errors: %d\n", *num, okCount, errCount)
	fmt.Printf("distinct servers: %d\n", len(perHost))
	for _, h := range hosts {
		fmt.Printf("host %s: %d\n", h, perHost[h])
	}

	if okCount == 0 {
		os.Exit(1)
	}
	os.Exit(0)
}
