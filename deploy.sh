# To load the variables in the .env file
source .env

# To deploy and verify our contract
forge script script/Deploy.s.sol:Deploy --rpc-url "http://127.0.0.1:8545/" --sender 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast -vvvv

cat broadcast/Deploy.s.sol/1/run-latest.json out/OrderPoolFactory.sol/OrderPoolFactory.json | \
jq -s \
    'add | 
    { chain: .chain} * (.transactions[] |
    { transactionType, contractName, contractAddress } |
    select(.transactionType == "CREATE" and .contractName == "OrderPoolFactory") |
    {contractName, contractAddress}) * {abi: .abi}' > deployedOrderPoolFactory.json

