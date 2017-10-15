#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

docker build --tag ethereum-artifacts .

rm -rf geth-tmp
mkdir geth-tmp
cp -r genesis-template.json geth-tmp/genesis.json

for i in {1..2}; do
  docker run -v $(pwd)/geth-tmp:/geth-tmp ethereum-artifacts \
    bash -c 'geth account new --datadir /geth-tmp/ --password <(echo password)'
done

for keystore in geth-tmp/keystore/*; do
  ACCOUNT_ID="0x$(jq -r '.address' < $keystore)"

  mv geth-tmp/genesis.json{,.bak}
  cat > geth-tmp/genesis.json \
    <(cat geth-tmp/genesis.json.bak | jq --arg account_id $ACCOUNT_ID '.alloc |= .+ {($account_id): {"balance": "1000000000000000000"}}')
done

docker run -v $(pwd)/geth-tmp:/geth-tmp ethereum-artifacts \
  bash -c 'geth init --datadir="/geth-tmp/" /geth-tmp/genesis.json'

docker run -v $(pwd)/geth-tmp:/geth-tmp ethereum-artifacts \
  bash -c 'bootnode --genkey /geth-tmp/bootnode.key'

docker run -v $(pwd)/geth-tmp:/geth-tmp ethereum-artifacts \
  bash -c 'bootnode --writeaddress --nodekey /geth-tmp/bootnode.key > /geth-tmp/bootnode.pub'

rm -rf pcf-root
mkdir -p pcf-root/data
cp -r geth-tmp/{geth,keystore,genesis.json} pcf-root/data
docker run -v $(pwd)/pcf-root:/pcf-root ethereum-artifacts \
  cp /usr/bin/geth /usr/bin/bootnode /pcf-root

cf push bootnodes -f manifests/bootnode-manifest.yml -p pcf-root/ --no-start
cf push miners    -f manifests/miner-manifest.yml    -p pcf-root/ --no-start
cf push nodes     -f manifests/node-manifest.yml     -p pcf-root/ --no-start

cf start bootnodes

BOOTNODE_PUBKEY=$(< geth-tmp/bootnode.pub)
BOOTNODE_IP=$(cf ssh bootnodes -c "hostname --ip-address")
cf set-env miners BOOTNODE_PUBKEY $BOOTNODE_PUBKEY
cf set-env miners BOOTNODE_IP $BOOTNODE_IP
cf set-env nodes BOOTNODE_PUBKEY $BOOTNODE_PUBKEY
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
cf ssh miners -i 0 -c "app/geth attach --exec 'admin.sleepBlocks(2); miner.stop()' app/data/geth.ipc"
