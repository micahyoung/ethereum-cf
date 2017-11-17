#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

read -p "This will delete all existing nodes and keys. Are you sure? " -n 1 -r
echo
[[ $REPLY =~ ^[Yy]$ ]] || exit 1

cf delete -f bootnodes
cf delete -f miners
cf delete -f nodes
cf delete-service -f ethereum-discovery
