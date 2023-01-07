#!/bin/zsh
# Usage: ./push_artifacts.sh <chain_id>

# To load the variables in the .env file
source .env

# To deploy and verify our contract
forge script script/DeployMumbai.s.sol:Deploy --rpc-url "https://polygon-mumbai.g.alchemy.com/v2/$ALCHEMY_KEY" --sender $SENDER --private-key $PRIVATE_KEY --broadcast -vvvv

rm web/src/artifacts/*.json "DeployMumbai.s.sol/80001"

source push_artifacts.sh

cd web
npm run build