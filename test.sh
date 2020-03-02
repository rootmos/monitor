#!/bin/bash

set -o nounset -o pipefail -o errexit

MONITOR_RUN_DIR=${MONITOR_RUN_DIR-/var/run/user/$(id -u)}
SOCKET=$MONITOR_RUN_DIR/monitor.sock
socat - unix:"$SOCKET" <<EOF
PING
STOP
EOF
