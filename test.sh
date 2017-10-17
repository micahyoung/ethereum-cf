#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

MINER_IP=$(cf ssh miners -c "hostname --ip-address")
cf push tests -f manifests/test-manifest.yml -p tests/ --no-start
cf set-env tests MINER_IP $MINER_IP
cf allow-access tests miners    --protocol tcp --port 8545

cf start tests && cf stop tests # update droplet for task

cf run-task tests 'sleep 5 && bash ./test-task.sh' #sleep to allow C2C to init

cf logs tests
