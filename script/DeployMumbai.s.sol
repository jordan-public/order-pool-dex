// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "../src/OrderPool.sol";
import "../src/OrderPoolFactory.sol";

contract Deploy is Script {
    // Mumbai
    address constant ETH = 0xBA47cF08bDFbA09E7732c0e48E12a11Cd1536bcd;
    address constant USDC = 0xe6b8a5CF854791412c1f6EFC7CAf629f5Df1c747;
    address constant LINK = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
    address constant BTCB = 0xaDb88FCc910aBfb2c03B49EE2087e7D6C2Ddb2E9;
    address constant WMATIC = 0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889;

    address constant ORACLE_ETH_USD =
        0x0715A7794a1dc8e42615F059dD6e406A6594651A;
    address constant ORACLE_LINK_USD =
        0x1C2252aeeD50e0c9B64bDfF2735Ee3C932F5C408;
    address constant ORACLE_BTC_USD =
        0x007A22900a3B98143368Bd5906f8E17e9867581b;
    address constant ORACLE_MATIC_USD =
        0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada;

    function run() external {
        // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(); /*deployerPrivateKey*/

        console.log("Creator (owner): ", msg.sender);

        OrderPoolFactory factory = new OrderPoolFactory();
        console.log(
            "Order Pool Factory deployed: ",
            address(factory)
        );

        {
            factory.createPair(ORACLE_ETH_USD, false, ETH, USDC);
            IOrderPool p = factory.getPair(factory.getNumPairs() - 1); // Assuning no one runs this script concurrently
            console.log("Order Pool ETH/USDC deployed at:", address(p));
            console.log(
                "Reverse Order Pool USDC/ETH deployed at: ",
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
            factory.createPair(ORACLE_BTC_USD, false, BTCB, USDC);
            IOrderPool p = factory.getPair(factory.getNumPairs() - 1); // Assuning no one runs this script concurrently
            console.log("Order Pool BTCB/USDC deployed at:", address(p));
            console.log(
                "Reverse Order Pool USDC/BTCB deployed at: ",
                address(p.reversePool())
            );
        }
        {
            factory.createPair(ORACLE_MATIC_USD, false, WMATIC, USDC);
            IOrderPool p = factory.getPair(factory.getNumPairs() - 1); // Assuning no one runs this script concurrently
            console.log("Order Pool WMATIC/USDC deployed at:", address(p));
            console.log(
                "Reverse Order Pool USDC/WMATIC deployed at: ",
                address(p.reversePool())
            );
        }
    }
}
