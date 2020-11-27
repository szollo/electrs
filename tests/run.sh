#!/bin/bash
set -euo pipefail

mkdir -p data/{bitcoin,electrum,electrs}

BTC="bitcoin-cli -regtest -datadir=data/bitcoin"
ELECTRUM="electrum --regtest"
EL="$ELECTRUM --wallet data/electrum/wallet"

echo "Starting bitcoind..."
bitcoind -regtest -datadir=data/bitcoin -printtoconsole=0 &

$BTC -rpcwait getblockcount > /dev/null

echo "Creating electrum wallet..."
$EL create --offline --seed_type segwit | jq .
MINING_ADDR=`$EL --offline getunusedaddress`

echo "Generating regtest coins..."
$BTC generatetoaddress 110 $MINING_ADDR > /dev/null
$BTC getblockchaininfo | jq -c .

echo "Starting electrs..."
export RUST_LOG=electrs=debug
electrs --db-dir=data/electrs --daemon-dir=data/bitcoin --network=regtest 2> data/electrs/regtest-debug.log &
sleep 1

echo "Starting electrum daemon..."
$ELECTRUM daemon --server localhost:60401:t -1 -vDEBUG 2> data/electrum/regtest-debug.log &
sleep 1

echo "Loading electrum wallet..."
test `$EL load_wallet` == "true"
sleep 1

$EL getinfo | jq -c .

echo "Running integration tests:"

echo " * getbalance"
test "`$EL getbalance | jq -c .`" == '{"confirmed":"550","unmatured":"4950"}'

echo " * getunusedaddress"
NEW_ADDR=`$EL getunusedaddress`

echo " * payto & broadcast"
TXID=$($EL broadcast $($EL payto $NEW_ADDR 123 --fee 0.001))

echo " * get_tx_status"
test "`$EL get_tx_status $TXID | jq -c .`" == '{"confirmations":0}'

echo " * getaddresshistory"
test "`$EL getaddresshistory $NEW_ADDR | jq -c .`" == "[{\"fee\":100000,\"height\":0,\"tx_hash\":\"$TXID\"}]"

echo " * getbalance"
test "`$EL getbalance | jq -c .`" == '{"confirmed":"550","unconfirmed":"-0.001","unmatured":"4950"}'

echo "Generating bitcoin block..."
$BTC generatetoaddress 1 $MINING_ADDR > /dev/null
$BTC getblockcount > /dev/null

echo " * get_tx_status"
test "`$EL get_tx_status $TXID | jq -c .`" == '{"confirmations":1}'

echo " * getaddresshistory"
test "`$EL getaddresshistory $NEW_ADDR | jq -c .`" == "[{\"fee\":null,\"height\":111,\"tx_hash\":\"$TXID\"}]"

echo " * getbalance"
test "`$EL getbalance | jq -c .`" == '{"confirmed":"599.999","unmatured":"4950.001"}'
