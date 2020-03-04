#!/bin/bash

set -o nounset -o pipefail -o errexit

MONITOR_RUN_DIR=${MONITOR_RUN_DIR-/var/run/user/$(id -u)}
SOCKET=$MONITOR_RUN_DIR/monitor.sock

for i in $(seq 1 5); do
    sleep 1
    socat - unix:"$SOCKET" <<EOF
PING
IP
EOF
done

socat - unix:"$SOCKET" <<EOF
STOP
EOF
