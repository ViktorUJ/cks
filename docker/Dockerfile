FROM alpine:3.17.2
RUN apk add --update --no-cache curl netcat-openbsd bash jq
COPY get_secret.sh /usr/bin/get_secret.sh
RUN chmod +x /usr/bin/get_secret.sh
