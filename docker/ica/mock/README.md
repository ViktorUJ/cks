# Echo Version Service

A simple Go service that responds to GET requests with JSON containing the pod name and version.

## Response Format

```json
{
  "pod_name": "echo-version-5d8f6c7b9-abc12",
  "version": "v1",
  "namespace": "default",
  "space_object": "Moon"
}
```

## Endpoints

- `/` - Returns pod info without space_object
- `/pluto` - Returns "Pluto" 
- `/moon` - Returns "Moon"
- `/mars` - Returns "Mars"
- `/blackhole` - Returns 500 error for first 2 requests, then returns "Gargantua" (for testing retry policies)
- `/invincible` - 30% chance of 5-second delay, returns "Invincible" (for testing timeout policies)

## Local Testing

```bash
# Run locally
go run main.go

# Test
curl http://localhost:8080
```

## Docker Build and Push

```bash
# Build for v1
docker build -t bizy92/echo-version-app:v1 .

# Push to Docker Hub
docker push bizy92/echo-version-app:v1

# Build for v2 (if needed)
docker build -t bizy92/echo-version-app:v2 .
docker push bizy92/echo-version-app:v2

# Run locally with Docker
docker run -p 8080:8080 -e VERSION=v1 -e POD_NAME=local-test bizy92/echo-version-app:v1

# Test
curl http://localhost:8080
```

## Kubernetes Deployment

```bash
# Deploy (pulls from Docker Hub)
kubectl apply -f deployment.yaml

# Check pods
kubectl get pods -l app=echo-version

# Test
kubectl port-forward svc/echo-version 8080:80
curl http://localhost:8080

# Check logs
kubectl logs -l app=echo-version
```

## Environment Variables

- `VERSION`: The version string (e.g., "v1", "v2")
- `POD_NAME`: Set automatically via Kubernetes downward API
- `NAMESPACE`: Set automatically via Kubernetes downward API
- `PORT`: Server port (default: 8080)
