#!/bin/bash

set -o nounset -o pipefail -o errexit

CLIENT=${CLIENT-./client}

for i in $(seq 1 5); do
    sleep 1
    $CLIENT -p avg
    $CLIENT -p loss
    $CLIENT -i
    $CLIENT -l
done

$CLIENT -s
