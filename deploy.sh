#!/bin/zsh

# To load the variables in the .env file
source .env

# To deploy and verify our contract
forge script script/Deploy.s.sol:Deploy --rpc-url "http://127.0.0.1:8545/" --sender 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast -vvvv

rm web/src/artifacts/*.json

source push_artifacts.sh