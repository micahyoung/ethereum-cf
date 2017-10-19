#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

sleep 5 #allow time for container to settle

export BOOTNODE=$(jq -r '.["ethereum-service"][0].credentials.bootnode' <(echo $VCAP_SERVICES))
