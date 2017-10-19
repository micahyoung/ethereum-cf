#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

BOOTNODE_PUBKEY=$(./bootnode --writeaddress --nodekey <(echo $BOOTNODE_KEY))
while true; do
  echo BOOTNODE=$BOOTNODE_PUBKEY@$CF_INSTANCE_INTERNAL_IP:$BOOTNODE_PORT
  sleep 5
done &
