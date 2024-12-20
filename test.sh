#!/bin/bash

set -o nounset -o pipefail -o errexit

CLIENT=${CLIENT-./client}

for i in $(seq 1 5); do
    sleep 1
    $CLIENT ping avg
    $CLIENT ping loss
    $CLIENT ip
    $CLIENT location
    $CLIENT fs usage /
    $CLIENT fs free /
    $CLIENT fs available /
done

$CLIENT stop
