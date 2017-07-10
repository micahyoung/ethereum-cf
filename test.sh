#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

echo "Miners peers"
NUM=$(cf scale miners | grep instances | cut -d: -f2)
let NUM--
for i in $(seq 0 $NUM); do 
  PEERS=$(cf ssh miners -i $i -c "app/geth attach --exec 'JSON.stringify(admin.peers)' app/data/geth.ipc" | jq 'fromjson | .[].network.remoteAddress')
  echo $PEERS
done

echo "Nodes peers"
NUM=$(cf scale nodes | grep instances | cut -d: -f2)
let NUM--
for i in $(seq 0 $NUM); do 
  PEERS=$(cf ssh nodes -i $i -c "app/geth attach --exec 'JSON.stringify(admin.peers)' app/data/geth.ipc" | jq 'fromjson | .[].network.remoteAddress')
  echo $PEERS
done

echo "Stopping miner"
cf ssh miners -i 0 -c "app/geth attach --exec 'miner.stop()' app/data/geth.ipc"
echo "Balances: expect both 0 or greater"
cf ssh nodes  -i 0 -c "app/geth attach --exec 'eth.accounts.map(function(account) {return web3.fromWei(eth.getBalance(account))});' app/data/geth.ipc"
echo "Transaction Status: expect pending: 0, queued: 0"
cf ssh nodes  -i 0 -c "app/geth attach --exec 'txpool.status' app/data/geth.ipc"
echo "Mining one block (may take 30s or more...)"
cf ssh miners -i 0 -c "app/geth attach --exec 'miner.start(1); admin.sleepBlocks(1); miner.stop()' app/data/geth.ipc"
echo "Balances: expect [+5, same]"
cf ssh nodes  -i 0 -c "app/geth attach --exec 'eth.accounts.map(function(account) {return web3.fromWei(eth.getBalance(account))});' app/data/geth.ipc"
echo Queuing transfer of 3 ether from first to second...
cf ssh nodes  -i 0 -c "app/geth attach --exec 'personal.unlockAccount(eth.accounts[0], \"password\"); eth.sendTransaction({from: eth.accounts[0], to: eth.accounts[1], value: web3.toWei(3, \"ether\")})' app/data/geth.ipc"
echo "Transaction Status (should be pending: 1, queued: 0)"
cf ssh nodes  -i 0 -c "app/geth attach --exec 'txpool.status' app/data/geth.ipc"
echo "Mining one block (may take 30s or more...)"
cf ssh miners -i 0 -c "app/geth attach --exec 'miner.start(1); admin.sleepBlocks(1); miner.stop()' app/data/geth.ipc"
echo "Balances: expect [+2, +3]"
cf ssh nodes  -i 0 -c "app/geth attach --exec 'eth.accounts.map(function(account) {return web3.fromWei(eth.getBalance(account))});' app/data/geth.ipc"
echo "Transaction Status (should be pending: 0, queued: 0)"
cf ssh nodes  -i 0 -c "app/geth attach --exec 'txpool.status' app/data/geth.ipc"
