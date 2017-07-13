#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

rm -rf geth-tmp
mkdir geth-tmp
pushd geth-tmp
  #From PPA trusty packages: https://launchpad.net/~ethereum/+archive/ubuntu/ethereum/+packages?field.name_filter=ethereum&field.status_filter=published&field.series_filter=trusty
  curl -L https://launchpad.net/~ethereum/+archive/ubuntu/ethereum/+files/geth_1.6.6+build10111+trusty_amd64.deb > geth.deb
  ar p geth.deb data.tar.xz | tar xJ
  rm geth.deb

  curl -L https://launchpad.net/~ethereum/+archive/ubuntu/ethereum/+files/bootnode_1.6.6+build10111+trusty_amd64.deb > bootnode.deb
  ar p bootnode.deb data.tar.xz | tar xJ
  rm bootnode.deb
popd

rm -rf pcf-root
mkdir pcf-root
cp geth-tmp/usr/bin/{geth,bootnode} pcf-root/
mkdir pcf-root/data
cp -r keystore pcf-root/data/
geth init --datadir="./pcf-root/data/" genesis.json

cf delete bootnodes -f
cf delete miners    -f
cf delete nodes     -f
cf push bootnodes -f manifests/bootnode-manifest.yml -p pcf-root/ --no-start
cf push miners    -f manifests/miner-manifest.yml    -p pcf-root/ --no-start
cf push nodes     -f manifests/node-manifest.yml     -p pcf-root/ --no-start

cf start bootnodes

BOOTNODE_IP=$(cf ssh bootnodes -c "hostname --ip-address")
cf set-env miners BOOTNODE_IP $BOOTNODE_IP
cf set-env nodes BOOTNODE_IP $BOOTNODE_IP

cf start miners
cf start nodes

cf allow-access miners nodes     --protocol udp --port 30303
cf allow-access miners nodes     --protocol tcp --port 30303
cf allow-access nodes  nodes     --protocol udp --port 30303
cf allow-access nodes  nodes     --protocol tcp --port 30303
cf allow-access nodes  miners    --protocol udp --port 30303
cf allow-access nodes  miners    --protocol tcp --port 30303
cf allow-access miners miners    --protocol udp --port 30303
cf allow-access miners miners    --protocol tcp --port 30303
cf allow-access nodes  bootnodes --protocol udp --port 33445
cf allow-access miners bootnodes --protocol udp --port 33445

echo "Mining two blocks to confirm DAG is created and cluster is up and settled. May take several minutes (expect true):"
cf ssh miners -i 0 -c "app/geth attach --exec 'miner.start(1); admin.sleepBlocks(2); miner.stop()' app/data/geth.ipc"
