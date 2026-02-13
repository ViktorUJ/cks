docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64  -t viktoruj/cks-lab:ica_echo_version_app_v1   --push .
