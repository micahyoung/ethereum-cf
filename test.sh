#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

echo "Miners peers (expect one):"
cf ssh miners -i 0 -c "app/geth attach --exec 'JSON.stringify(admin.peers)' app/data/geth.ipc" | jq 'fromjson | .[].network.remoteAddress'
echo

echo "Nodes peers (expect one):"
cf ssh nodes -i 0 -c "app/geth attach --exec 'JSON.stringify(admin.peers)' app/data/geth.ipc" | jq 'fromjson | .[].network.remoteAddress'
echo

echo "Stopping miner (expect true):"
cf ssh miners -i 0 -c "app/geth attach --exec 'miner.stop()' app/data/geth.ipc"
echo

echo "Transaction Status (expect pending: 0, queued: 0):"
cf ssh nodes  -i 0 -c "app/geth attach --exec 'txpool.status' app/data/geth.ipc"
echo

echo "Balances (expect both 0 or greater):"
cf ssh nodes  -i 0 -c "app/geth attach --exec 'eth.accounts.map(function(account) {return web3.fromWei(eth.getBalance(account))});' app/data/geth.ipc"
echo

echo "Mining one block - may take several minutes (expect true):"
cf ssh miners -i 0 -c "app/geth attach --exec 'miner.start(1); admin.sleepBlocks(1); miner.stop()' app/data/geth.ipc"
echo

echo "Balances (expect [previous+5, same]):"
cf ssh nodes  -i 0 -c "app/geth attach --exec 'eth.accounts.map(function(account) {return web3.fromWei(eth.getBalance(account))});' app/data/geth.ipc"
echo

echo "Queuing transfer of 3 ether from first to second (expect transaction id):"
cf ssh nodes  -i 0 -c "app/geth attach --exec 'personal.unlockAccount(eth.accounts[0], \"password\"); eth.sendTransaction({from: eth.accounts[0], to: eth.accounts[1], value: web3.toWei(3, \"ether\")})' app/data/geth.ipc"
echo

#echo "Transaction Status (expect pending: 1, queued: 0):"
#cf ssh nodes  -i 0 -c "app/geth attach --exec 'txpool.status' app/data/geth.ipc"
#echo

echo "Mining one block - may take several minutes (expect true):"
cf ssh miners -i 0 -c "app/geth attach --exec 'miner.start(1); admin.sleepBlocks(1); miner.stop()' app/data/geth.ipc"
echo

echo "Balances (expect [previous+2, previous+3]):"
cf ssh nodes  -i 0 -c "app/geth attach --exec 'eth.accounts.map(function(account) {return web3.fromWei(eth.getBalance(account))});' app/data/geth.ipc"
echo

echo "Transaction Status (expect pending: 0, queued: 0):"
cf ssh nodes  -i 0 -c "app/geth attach --exec 'txpool.status' app/data/geth.ipc"
echo
