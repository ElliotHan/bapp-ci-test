#!/usr/bin/env bash

# Exit script as soon as a command fails.
set -o errexit

# Executes cleanup function at script exit.
trap cleanup EXIT

cleanup() {
  # Kill the ganache instance that we started (if we started one and if it's still running).
  if [ -n "$ganache_pid" ] && ps -p $ganache_pid > /dev/null; then
    kill -9 $ganache_pid
  fi
}

ganache_port=8555

ganache_running() {
  nc -z localhost "$ganache_port"
}

start_ganache() {
  # We define 10 accounts with balance 1M ether, needed for high-value tests.
  local accounts=(
    --account="0xe105242fc492f5c398772b22c8760d526cdc4b2dce4fae3d3e95ab4c6b1a2735,1000000000000000000000000"
    --account="0xa5769d46434af0f383b039a2d6c3ce3438f81f05e53de473b55ef87a3c3348fd,1000000000000000000000000"
    --account="0x2f539ed5651d699997929aa1861f1d7b9294f96f5112a4e4fc2cfe472ff926a5,1000000000000000000000000"
    --account="0x2392221fd2cda36ad9bf04de78c0cbe696a05b2cd36849a3622a797cc95fe5a6,1000000000000000000000000"
    --account="0xbb7bb67e86015bfed06f3f222b7b3cc1437bab103d051a9f441e1b0b5646fb39,1000000000000000000000000"
    --account="0x41b70c089bbf550c8778eb1d033276c0b99c7e1b20aa6495f3b5a4bbea405364,1000000000000000000000000"
    --account="0x4ce3f9fac249e5f5db1ca67a0f9deae5e8deaa799b34134f0fefdbf85c91bc41,1000000000000000000000000"
    --account="0xd8dd0d580daec30f011008345991113ddb33f82f29ffbc973cd8d95d529302d8,1000000000000000000000000"
    --account="0xa6d22e92a5f37ad0e60f76faace1d00add793bf575a0986b0733d9bf3fe91d8e,1000000000000000000000000"
    --account="0x568c3a5f46a73c527b7c7d5d8d6a28c7fe9d9da1ba3a07d7e0cacdd34adf9590,1000000000000000000000000"
    --account="0xb178cf12d4126ea1db48ca32e3ce6743580ca6646391996032fc76652d69997c,1000000000000000000000000"
    --account="0x4deb44dfab370f6720da9eb537eb8d91294e42ecb269e1b39fd8e7f4eda4247f,1000000000000000000000000"
    --account="0x62fec2b8b10c41093c0abaa1fe457e52a37106ba4c2d8292468f2f178c62c39b,1000000000000000000000000"
    --account="0x4f4429d94a86be7faadea21c39d9c32b015fcfab0d610d1c0c1b7fb9fb2c2e21,1000000000000000000000000"
    --account="0xa4e0b000fb462d3699813284f090d3cc97a18830ebaec60e835acb4830a4e9c9,1000000000000000000000000"
    --account="0x51e30270b50c6ff19bcd412ba52d2ed246739751098cbe972e2ea18e67231bae,1000000000000000000000000"
    --account="0xfbe93bf5d5113dad9012bb998af7879861043c71be05e71c9e17137607dc16eb,1000000000000000000000000"
  )

  node_modules/.bin/testrpc-sc --gasLimit 0xfffffffffff --port "$ganache_port" "${accounts[@]}" > /dev/null &

  ganache_pid=$!
}

if ganache_running; then
  echo "Using existing ganache instance"
else
  echo "Starting our own ganache instance"
  start_ganache
fi

node_modules/.bin/solidity-coverage