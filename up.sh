#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

docker build --tag ethereum-artifacts .

rm -rf geth-tmp
mkdir geth-tmp
cp -r genesis-template.json geth-tmp/genesis.json

docker run -v $(pwd)/geth-tmp:/geth-tmp ethereum-artifacts \
  bash -c '
for i in {1..2}; do
  geth account new --datadir /geth-tmp/ --password <(echo password)
done

for keystore in /geth-tmp/keystore/*; do
  ACCOUNT_ID=0x$(jq -r ".address" < $keystore)

  mv /geth-tmp/genesis.json{,.bak}
  cat > /geth-tmp/genesis.json \
    <(cat /geth-tmp/genesis.json.bak | jq --arg account_id $ACCOUNT_ID ".alloc |= .+ {(\$account_id): {\"balance\": \"1000000000000000000\"}}")
done

geth init --datadir="/geth-tmp/" /geth-tmp/genesis.json

bootnode --genkey /geth-tmp/bootnode.key

bootnode --writeaddress --nodekey /geth-tmp/bootnode.key > /geth-tmp/bootnode.pub

chown -R 1000:1000 /geth-tmp
'

rm -rf pcf-root
mkdir -p pcf-root/data
cp bootnode_env.sh node_env.sh pcf-root/
cp -r geth-tmp/{geth,keystore,genesis.json} pcf-root/data
docker run -v $(pwd)/pcf-root:/pcf-root ethereum-artifacts \
  cp /usr/bin/geth /usr/bin/bootnode /pcf-root

cf create-service ethereum-discovery-service public ethereum-discovery

cf push bootnodes -f manifests/bootnode-manifest.yml -p pcf-root/ --no-start

BOOTNODE_PORT=33445
BOOTNODE_KEY=$(< geth-tmp/bootnode.key)
cf set-env bootnodes BOOTNODE_PORT $BOOTNODE_PORT
cf set-env bootnodes BOOTNODE_KEY $BOOTNODE_KEY
cf start bootnodes

read  -n 1 -p "Check /log-collector/bootnodes for bootnode: " mainmenuinput

cf push miners    -f manifests/miner-manifest.yml    -p pcf-root/ --no-start
cf push nodes     -f manifests/node-manifest.yml     -p pcf-root/ --no-start
NETWORK_ID=12345
cf set-env miners NETWORK_ID $NETWORK_ID
cf set-env nodes NETWORK_ID $NETWORK_ID

cf start miners
cf start nodes

if ! grep -q network-policy <(cf plugins); then
  cf install-plugin -f network-policy
fi

cf allow-access miners nodes     --protocol udp --port 30303
cf allow-access miners nodes     --protocol tcp --port 30303
cf allow-access nodes  nodes     --protocol udp --port 30303
cf allow-access nodes  nodes     --protocol tcp --port 30303
cf allow-access nodes  miners    --protocol udp --port 30303
cf allow-access nodes  miners    --protocol tcp --port 30303
cf allow-access miners miners    --protocol udp --port 30303
cf allow-access miners miners    --protocol tcp --port 30303
cf allow-access nodes  bootnodes --protocol udp --port $BOOTNODE_PORT
cf allow-access miners bootnodes --protocol udp --port $BOOTNODE_PORT

echo "Chain is up. Run ./test.sh to validate"
