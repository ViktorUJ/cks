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

docker buildx build --platform linux/arm64 --load -t viktoruj/ping_pong:${latest_commit_hash}-arm64   .
docker buildx build --platform linux/amd64 --load -t viktoruj/ping_pong:${latest_commit_hash}-amd64   .
docker push viktoruj/ping_pong:${latest_commit_hash}-arm64
docker push viktoruj/ping_pong:${latest_commit_hash}-amd64
docker manifest create viktoruj/ping_pong:${latest_commit_hash} viktoruj/ping_pong:${latest_commit_hash}-arm64  viktoruj/ping_pong:${latest_commit_hash}-amd64
docker manifest push viktoruj/ping_pong:${latest_commit_hash}

case $release in
true)
   echo "*** do release"
   docker manifest rm viktoruj/ping_pong:latest
   docker manifest create viktoruj/ping_pong:latest viktoruj/ping_pong:${latest_commit_hash}-arm64  viktoruj/ping_pong:${latest_commit_hash}-amd64
   docker manifest push viktoruj/ping_pong:latest
;;
*)
 echo "*** not need release"
;;

esac
