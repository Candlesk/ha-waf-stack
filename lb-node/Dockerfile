FROM haproxy:2.8-alpine

# Switch to root to install packages and run keepalived
USER root

# Install Keepalived and IP routing tools
RUN apk add --no-cache keepalived iproute2

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
