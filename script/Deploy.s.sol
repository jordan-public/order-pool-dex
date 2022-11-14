// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "../src/OrderPool.sol";
import "../src/OrderPoolFactory.sol";

contract Deploy is Script {
    // Mainnet
    // address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    // address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    // address constant ORACLE_ETH_USD =
    //     0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    // Görli
    address constant WETH = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
    address constant USDC = 0x07865c6E87B9F70255377e024ace6630C1Eaa37F;
    address constant LINK = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
    address constant WBTC = 0xCA063A2AB07491eE991dCecb456D1265f842b568;

    address constant ORACLE_ETH_USD =
        0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e;
    address constant ORACLE_LINK_USD =
        0x48731cF7e84dc94C5f84577882c14Be11a5B7456;
    address constant ORACLE_BTC_USD =
        0xA39434A63A52E749F02807ae27335515BA4b07F7;
    address constant ORACLE_BTC_ETH =
        0x779877A7B0D9E8603169DdbD7836e478b4624789;

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

        {
            factory.createPair(ORACLE_ETH_USD, false, WETH, USDC);
            IOrderPool p = factory.getPair(factory.getNumPairs() - 1); // Assuning no one runs this script concurrently
            console.log("Order Pool WETH/USDC deployed at:", address(p));
            console.log(
                "Reverse Order Pool USDC/WETH deployed at: ",
                address(p.reversePool())
            );
        }

        {
            factory.createPair(ORACLE_LINK_USD, false, LINK, USDC);
            IOrderPool p = factory.getPair(factory.getNumPairs() - 1); // Assuning no one runs this script concurrently
            console.log("Order Pool LINK/USDC deployed at:", address(p));
            console.log(
                "Reverse Order Pool USDC/LINK deployed at: ",
                address(p.reversePool())
            );
        }
        {
            factory.createPair(ORACLE_BTC_USD, false, WBTC, USDC);
            IOrderPool p = factory.getPair(factory.getNumPairs() - 1); // Assuning no one runs this script concurrently
            console.log("Order Pool WBTC/USDC deployed at:", address(p));
            console.log(
                "Reverse Order Pool USDC/WBTC deployed at: ",
                address(p.reversePool())
            );
        }
        {
            factory.createPair(ORACLE_BTC_ETH, false, WBTC, WETH);
            IOrderPool p = factory.getPair(factory.getNumPairs() - 1); // Assuning no one runs this script concurrently
            console.log("Order Pool WBTC/WETH deployed at:", address(p));
            console.log(
                "Reverse Order Pool WETH/WBTC deployed at: ",
                address(p.reversePool())
            );
        }
        vm.stopBroadcast();
    }
}
