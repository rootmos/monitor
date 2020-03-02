#!/bin/bash

set -o nounset -o pipefail -o errexit

SOCKET=/var/run/user/$(id -u)/monitor.sock
socat - unix:"$SOCKET" <<EOF
PING
STOP
EOF
