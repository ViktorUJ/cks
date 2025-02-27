latest_commit_hash=$(git rev-parse --short HEAD)

while [[ $# > 0 ]]; do
    key="$1"
    case "$key" in
      --release)
         release="$2"
         shift
      ;;

      *)
      ;;
    esac
    shift
done

if [ -z "$release" ]; then
     release="dev"
fi

echo "*** release = $release"

build_cross_binaries() {
  echo "=== Starting cross-compilation inside Docker ==="

  # Create 'dist' folder for output binaries
  mkdir -p dist

  # We use the golang:alpine container to perform cross-compilation
  docker run --rm \
    -v "$(pwd)":/app \
    -w /app/app \
    golang:alpine \
    sh -c "
      # Install git (if needed) and update go modules
      apk add --no-cache git
      go mod tidy

      # Build for Linux (amd64)
      CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
      go build -ldflags='-w -s' -o ../dist/ping-pong-linux-amd64 app.go

      # Build for Linux (arm64)
      CGO_ENABLED=0 GOOS=linux GOARCH=arm64 \
      go build -ldflags='-w -s' -o ../dist/ping-pong-linux-arm64 app.go

      # Build for Windows (amd64)
      CGO_ENABLED=0 GOOS=windows GOARCH=amd64 \
      go build -ldflags='-w -s' -o ../dist/ping-pong-windows-amd64.exe app.go

      # Build for Windows (arm64)
      CGO_ENABLED=0 GOOS=windows GOARCH=arm64 \
      go build -ldflags='-w -s' -o ../dist/ping-pong-windows-arm64.exe app.go

      # Build for macOS (darwin) amd64
     # CGO_ENABLED=1 GOOS=darwin GOARCH=amd64 \
     # go build -ldflags='-w -s' -o ../dist/ping-pong-darwin-amd64 app.go

      # Build for macOS (darwin) arm64
     # CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 \
     # go build -ldflags='-w -s' -o ../dist/ping-pong-darwin-arm64 app.go
    "
   cd app
   go mod tidy
   CGO_ENABLED=1 GOOS=darwin GOARCH=amd64  go build -ldflags='-w -s' -o ../dist/ping-pong-darwin-amd64 app.go
   chmod +x ../dist/ping-pong-darwin-amd64
   CGO_ENABLED=1 GOOS=darwin GOARCH=arm64  go build -ldflags='-w -s' -o ../dist/ping-pong-darwin-arm64 app.go
   chmod +x ../dist/ping-pong-darwin-arm64
   cd ..

  echo "=== Cross-compilation finished. Binaries are in './dist' folder ==="
}


case $release in
bin)
   build_cross_binaries
;;
bin_deploy)
   aws s3 cp ./dist s3://sre-platform.aws-guru.com/download/pingpong/ --recursive --profile deploy
   aws cloudfront create-invalidation --distribution-id E1HF54QM48F9SB --paths "/download/pingpong/*" --profile deploy
;;
scratch)
   docker buildx build --platform linux/arm64 --load -t viktoruj/ping_pong:${latest_commit_hash}-arm64   .
   docker buildx build --platform linux/amd64 --load -t viktoruj/ping_pong:${latest_commit_hash}-amd64   .
   docker push viktoruj/ping_pong:${latest_commit_hash}-arm64
   docker push viktoruj/ping_pong:${latest_commit_hash}-amd64
   docker manifest create viktoruj/ping_pong:${latest_commit_hash} viktoruj/ping_pong:${latest_commit_hash}-arm64  viktoruj/ping_pong:${latest_commit_hash}-amd64
   docker manifest push viktoruj/ping_pong:${latest_commit_hash}
   echo "*** do release"
   docker manifest rm viktoruj/ping_pong:latest
   docker manifest create viktoruj/ping_pong:latest viktoruj/ping_pong:${latest_commit_hash}-arm64  viktoruj/ping_pong:${latest_commit_hash}-amd64
   docker manifest push viktoruj/ping_pong:latest
;;
alpine)
   echo "*** do release alpine"
   docker buildx build --platform linux/arm64 --load -t viktoruj/ping_pong:${latest_commit_hash}-arm64-alpine  -f  Dockerfile_alpine .
   docker buildx build --platform linux/amd64 --load -t viktoruj/ping_pong:${latest_commit_hash}-amd64-alpine  -f  Dockerfile_alpine  .
   docker push viktoruj/ping_pong:${latest_commit_hash}-arm64-alpine
   docker push viktoruj/ping_pong:${latest_commit_hash}-amd64-alpine
   docker manifest create viktoruj/ping_pong:${latest_commit_hash}-alpine  viktoruj/ping_pong:${latest_commit_hash}-arm64-alpine   viktoruj/ping_pong:${latest_commit_hash}-amd64-alpine
   docker manifest push viktoruj/ping_pong:${latest_commit_hash}-alpine

   docker manifest rm viktoruj/ping_pong:alpine
   docker manifest create viktoruj/ping_pong:alpine viktoruj/ping_pong:${latest_commit_hash}-arm64-alpine  viktoruj/ping_pong:${latest_commit_hash}-amd64-alpine
   docker manifest push viktoruj/ping_pong:alpine

;;

debug)
   echo "*** do release debug"
   docker buildx build --platform linux/arm64 --load -t viktoruj/ping_pong:${latest_commit_hash}-arm64-debug  -f  Dockerfile_debug_arm .
   docker buildx build --platform linux/amd64 --load -t viktoruj/ping_pong:${latest_commit_hash}-amd64-debug  -f  Dockerfile_debug_x86  .
   docker push viktoruj/ping_pong:${latest_commit_hash}-arm64-debug
   docker push viktoruj/ping_pong:${latest_commit_hash}-amd64-debug
   docker manifest create viktoruj/ping_pong:${latest_commit_hash}-debug  viktoruj/ping_pong:${latest_commit_hash}-arm64-debug   viktoruj/ping_pong:${latest_commit_hash}-amd64-debug
   docker manifest push viktoruj/ping_pong:${latest_commit_hash}-debug

   docker manifest rm viktoruj/ping_pong:debug
   docker manifest create viktoruj/ping_pong:debug viktoruj/ping_pong:${latest_commit_hash}-arm64-debug  viktoruj/ping_pong:${latest_commit_hash}-amd64-debug
   docker manifest push viktoruj/ping_pong:debug

;;
dev)
   docker buildx build --platform linux/arm64 --load -t viktoruj/ping_pong:${latest_commit_hash}-arm64   .
   docker buildx build --platform linux/amd64 --load -t viktoruj/ping_pong:${latest_commit_hash}-amd64   .
   docker push viktoruj/ping_pong:${latest_commit_hash}-arm64
   docker push viktoruj/ping_pong:${latest_commit_hash}-amd64
   docker manifest create viktoruj/ping_pong:${latest_commit_hash} viktoruj/ping_pong:${latest_commit_hash}-arm64  viktoruj/ping_pong:${latest_commit_hash}-amd64
   docker manifest push viktoruj/ping_pong:${latest_commit_hash}
   echo "*** not need release"
;;

esac
