#!/bin/sh
# Start Keepalived
keepalived -f /etc/keepalived/keepalived.conf --dont-fork --log-console &

# Start HAProxy in foreground
exec haproxy -f /usr/local/etc/haproxy/haproxy.cfg
