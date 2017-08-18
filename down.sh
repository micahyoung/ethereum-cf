#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

read -p "This will delete all existing nodes and keys. Are you sure? " -n 1 -r
echo
[[ $REPLY =~ ^[Yy]$ ]] || exit 1

cf delete bootnodes -f
cf delete miners    -f
cf delete nodes     -f
