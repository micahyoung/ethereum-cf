#!/bin/bash

: ${MINER_IP:?"!"}

echo "Miners peers (expect one):"
curl --data '{"method":"admin_peers","params":[],"id":0,"jsonrpc":"2.0"}' -X POST -s http://$MINER_IP:8545 | jq -r '.result[].network.remoteAddress'
echo

echo "Nodes peers (expect one):"
curl --data '{"method":"admin_peers","params":[],"id":0,"jsonrpc":"2.0"}' -X POST -s http://$MINER_IP:8545 | jq -r '.result[].network.remoteAddress'
echo

echo "Stopping miner (expect true):"
curl --data '{"method":"miner_stop","params":[],"id":0,"jsonrpc":"2.0"}' -X POST -s http://$MINER_IP:8545 | jq -r '.result'
echo

echo "Transaction Status (expect pending: 0, queued: 0):"
curl --data '{"method":"txpool_status","params":[],"id":0,"jsonrpc":"2.0"}' -X POST -s http://$MINER_IP:8545 | jq -r '.result'
echo

hexToDec() {
  read WEI
  ETH=$(printf "%d" "$WEI" 2>/dev/null) #remove 0x and convert from unsigned base-16
  echo ${ETH/-/}
}

ACCOUNTS=( $(curl --data '{"method":"eth_accounts","params":[],"id":0,"jsonrpc":"2.0"}' -X POST -s http://$MINER_IP:8545 | jq -r '.result | to_entries[] | "\(.value)"') )
echo "Accounts: ${ACCOUNTS[@]}"

echo "Setup balances (will mine until sender has > 1,000,000):"
while true; do
  SENDER_WEI=$(curl --data '{"method":"eth_getBalance","params":["'${ACCOUNTS[0]}'","latest"],"id":0,"jsonrpc":"2.0"}' -X POST -s http://$MINER_IP:8545 | jq -r '.result' | hexToDec)
  RECEVR_WEI=$(curl --data '{"method":"eth_getBalance","params":["'${ACCOUNTS[1]}'","latest"],"id":0,"jsonrpc":"2.0"}' -X POST -s http://$MINER_IP:8545 | jq -r '.result' | hexToDec)
  echo "sender: ${ACCOUNTS[0]}, wei: $SENDER_WEI"
  echo "recevr: ${ACCOUNTS[1]}, wei: $RECEVR_WEI"

  if [[ $SENDER_WEI < 1000000 ]]; then
    echo "Mining to get 1M wei to send - may take several minutes (expect true):"
    curl --data '{"method":"miner_start","params":[1],"id":0,"jsonrpc":"2.0"}' -X POST -s http://$MINER_IP:8545 | jq -r '.result'
  else
    echo "Sender has at least 1M wei to send, stopping mining"
    curl --data '{"method":"miner_stop","params":[],"id":0,"jsonrpc":"2.0"}' -X POST -s http://$MINER_IP:8545 | jq -r '.result'
    break
  fi

  sleep 10
done
echo

echo "Queuing transfer of 3 ether from first to second (expect transaction id):"
VALUE=$(printf "0x%x" 1000000)
curl --data '{"method":"personal_unlockAccount","params":["'${ACCOUNTS[0]}'","password"],"id":0,"jsonrpc":"2.0"}' -X POST -s http://$MINER_IP:8545 | jq -r '.result'
curl --data '{"method":"eth_sendTransaction","params":[{"from":"'${ACCOUNTS[0]}'","to":"'${ACCOUNTS[1]}'","value":"'$VALUE'"}],"id":0,"jsonrpc":"2.0"}' -X POST -s http://$MINER_IP:8545 | jq -r '.result'
echo

echo "Transaction Status (expect pending: 1, queued: 0):"
curl --data '{"method":"txpool_status","params":[],"id":0,"jsonrpc":"2.0"}' -X POST -s http://$MINER_IP:8545 | jq -r '.result'
echo

echo "Mining until transaction completes - may take several minutes (expect true):"
while true; do
  PENDING_STATUS=$(curl --data '{"method":"txpool_status","params":[],"id":0,"jsonrpc":"2.0"}' -X POST -s http://$MINER_IP:8545 | jq -r '.result.pending')
  SENDER_WEI=$(curl --data '{"method":"eth_getBalance","params":["'${ACCOUNTS[0]}'","latest"],"id":0,"jsonrpc":"2.0"}' -X POST -s http://$MINER_IP:8545 | jq -r '.result' | hexToDec)
  RECEVR_WEI=$(curl --data '{"method":"eth_getBalance","params":["'${ACCOUNTS[1]}'","latest"],"id":0,"jsonrpc":"2.0"}' -X POST -s http://$MINER_IP:8545 | jq -r '.result' | hexToDec)
  echo "status: pending: $PENDING_STATUS"
  echo "sender: ${ACCOUNTS[0]}, wei: $SENDER_WEI"
  echo "recevr: ${ACCOUNTS[1]}, wei: $RECEVR_WEI"

  if [ "$PENDING_STATUS" != "0x0" ]; then
    echo "Mining:"
    curl --data '{"method":"miner_start","params":[1],"id":0,"jsonrpc":"2.0"}' -X POST -s http://$MINER_IP:8545 | jq -r '.result // empty'
  else
    echo "Transaction complete; stopping mining"
    curl --data '{"method":"miner_stop","params":[],"id":0,"jsonrpc":"2.0"}' -X POST -s http://$MINER_IP:8545 | jq -r '.result'
    break
  fi

  sleep 10
done
echo

echo "Transaction Status (expect pending: 0, queued: 0):"
curl --data '{"method":"txpool_status","params":[],"id":0,"jsonrpc":"2.0"}' -X POST -s http://$MINER_IP:8545 | jq -r '.result'
echo

