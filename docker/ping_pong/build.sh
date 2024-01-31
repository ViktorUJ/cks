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

case $release in
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
