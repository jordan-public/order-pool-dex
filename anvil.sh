#!/bin/zsh
source .env
# anvil --block-time 10 --fork-url https://goerli.infura.io/v3/$INFURA_KEY
anvil --fork-url https://goerli.infura.io/v3/$INFURA_KEY
