// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "../src/OrderPool.sol";
import "../src/OrderPoolFactory.sol";

contract Deploy is Script {
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant ORACLE_ETH_USD =
        0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    function run() external {
        // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(); /*deployerPrivateKey*/

        console.log("Creator: ", msg.sender);

        OrderPoolFactory factory = new OrderPoolFactory();
        console.log(
            "Order Pool Factory deployed: ",
            address(factory),
            " owner: ",
            factory.owner()
        );

        // createPair(ETH/USD chainlink feed, not inverse, WETH, USDC)
        factory.createPair(ORACLE_ETH_USD, false, WETH, USDC);
        IOrderPool p = factory.getPair(factory.getNumPairs()-1); // Assuning no one runs this script concurrently 
        console.log("Order Pool WETH/USDC deployed at:", address(p));
        console.log("Reverse Order Pool USDC/WETH deployed at: ", address(p.reversePool()));

        vm.stopBroadcast();
    }
}
