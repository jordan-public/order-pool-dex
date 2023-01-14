// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "../src/OrderPool.sol";
import "../src/OrderPoolFactory.sol";

contract Token is ERC20 {
    constructor(string memory symbol, uint amount) ERC20(symbol, symbol) {
        _mint(msg.sender, amount);
    }
}

contract OrderPoolTest is Test {
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

    // Accounts from anvil
    address constant account1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address constant account2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address constant account3 = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
    address constant account4 = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;

    IOrderPoolFactory factory;
    IOrderPool pool;
    IOrderPool reversePool;
    Token JETH;
    Token JUSD;
    
    function setUp() public {
        // Create 2 tokens
        JETH = new Token("JETH", 100 * 10**18); // 100 JETH
        console.log("Token JETH address: ", address(JETH));

        JUSD = new Token("JUSD", 100000 * 10**18); // 100,000 JUSD
        console.log("Token JUSD address: ", address(JUSD));
  
        // Fund accounts 2, 3, 4 and 5 for experimentation
        JETH.transfer(account1, 25 * 10**18);
        JETH.transfer(account2, 25 * 10**18);
        JETH.transfer(account3, 25 * 10**18);
        JETH.transfer(account4, 25 * 10**18);
        JUSD.transfer(account1, 25000 * 10**18);
        JUSD.transfer(account2, 25000 * 10**18);
        JUSD.transfer(account3, 25000 * 10**18);
        JUSD.transfer(account4, 25000 * 10**18);

        factory = new OrderPoolFactory();
        console.log(
            "Order Pool Factory deployed: ",
            address(factory)
        );

        {
            factory.createPair(ORACLE_ETH_USD, false, address(JETH), address(JUSD));
            pool = factory.getPair(factory.getNumPairs() - 1); // Assuning no one runs this script concurrently
            console.log("Order Pool JETH/JUSD deployed at:", address(pool));
            console.log(
                "Reverse Order Pool JUSD/JETH deployed at: ",
                address(pool.reversePool())
            );
        }

        pool = factory.getPair(factory.getNumPairs() - 1);
        reversePool = pool.reversePool();
    }

    function testPriceFeed() public {
        uint256 amount = 10**18;
        assertApproxEqRel(
            pool.reversePool().convert(pool.convert(amount)),
            amount,
            10e15
        );
    }

    function testMakeWithdrawUnexecuted() public {
        {
            vm.startPrank(account1, account1);
            JETH.approve(address(pool), type(uint256).max);
            uint256 a = 2 * 10**18;
            uint256 s = pool.sufficientOrderIndexSearch(a);
            pool.swap(a, true, true, s); // Make (deposit)
            pool.withdraw(type(uint256).max);
            vm.stopPrank();
        }

    }

    function testSwap0() public {
        {
            vm.startPrank(account1, account1);
            JETH.approve(address(pool), type(uint256).max);
            uint256 a = 2 * 10**18;
            uint256 s = pool.sufficientOrderIndexSearch(a);
            pool.swap(a, true, true, s);
            vm.stopPrank();
        }

        {
            vm.startPrank(account3, account3);
            JUSD.approve(address(reversePool), type(uint256).max);
            uint256 a = 100 * 10**18;
            uint256 s = reversePool.sufficientOrderIndexSearch(a);
            reversePool.swap(a, true, true, s);
            vm.stopPrank();
        }
    }

    function testSwap0WithdrawAll() public {
        {   // Maker
            vm.startPrank(account1, account1);
            JETH.approve(address(pool), type(uint256).max);
            uint256 a = 2 * 10**18;
            uint256 s = pool.sufficientOrderIndexSearch(a);
            pool.swap(a, true, true, s);
            vm.stopPrank();
        }

        {   // Taker
            vm.startPrank(account3, account3);
            JUSD.approve(address(reversePool), type(uint256).max);
            uint256 a = 100 * 10**18;
            uint256 s = reversePool.sufficientOrderIndexSearch(a);
            reversePool.swap(a, true, true, s);
            vm.stopPrank();
        }

        {
            vm.startPrank(account1, account1);
            (,, uint256 rangeIndex) = pool.orderStatus();
            pool.withdraw(rangeIndex);
            vm.stopPrank();
        }
    }

    function testSwap1() public {
        {
            vm.startPrank(account1, account1);
            JETH.approve(address(pool), type(uint256).max);
            uint256 a = 2 * 10**18;
            uint256 s = pool.sufficientOrderIndexSearch(a);
            pool.swap(a, true, true, s);
            vm.stopPrank();
        }

        {
            vm.startPrank(account2, account2);
            JETH.approve(address(pool), type(uint256).max);
            uint256 a = 2 * 10**18;
            uint256 s = pool.sufficientOrderIndexSearch(a);
            pool.swap(a, true, true, s);
            vm.stopPrank();
        }

        {
            vm.startPrank(account3, account3);
            JUSD.approve(address(reversePool), type(uint256).max);
            uint256 a = 3000 * 10**18;
            uint256 s = reversePool.sufficientOrderIndexSearch(a);
            reversePool.swap(a, true, true, s);
            vm.stopPrank();
        }

        {
            vm.startPrank(account4, account4);
            JUSD.approve(address(reversePool), type(uint256).max);
            uint256 a = 3000 * 10**18;
            uint256 s = reversePool.sufficientOrderIndexSearch(a);
            reversePool.swap(a, true, true, s);
            vm.stopPrank();
        }
    }

    function testSwap1Withdraw() public {
        { // 1 swaps
            vm.startPrank(account1, account1);
            JETH.approve(address(pool), type(uint256).max);
            uint256 a = 2 * 10**18;
            uint256 s = pool.sufficientOrderIndexSearch(a);
            pool.swap(a, true, true, s);
            vm.stopPrank();
        }

        { // 2 swaps
            vm.startPrank(account2, account2);
            JETH.approve(address(pool), type(uint256).max);
            uint256 a = 2 * 10**18;
            uint256 s = pool.sufficientOrderIndexSearch(a);
            pool.swap(a, true, true, s);
            vm.stopPrank();
        }

        { // 3 counterswaps
            vm.startPrank(account3, account3);
            JUSD.approve(address(reversePool), type(uint256).max);
            uint256 a = 3000 * 10**18;
            uint256 s = reversePool.sufficientOrderIndexSearch(a);
            reversePool.swap(a, true, true, s);
            vm.stopPrank();
        }

        { // 1 withdraws
            vm.startPrank(account1, account1);
            (,, uint256 rangeIndex) = pool.orderStatus();
            pool.withdraw(rangeIndex);
            vm.stopPrank();
        }

        { // 4 counterswaps
            vm.startPrank(account4, account4);
            JUSD.approve(address(reversePool), type(uint256).max);
            uint256 a = 3000 * 10**18;
            uint256 s = reversePool.sufficientOrderIndexSearch(a);
            reversePool.swap(a, true, true, s);
            vm.stopPrank();
        }

        { // 2 withdraws
            vm.startPrank(account2, account2);
            (,, uint256 rangeIndex) = pool.orderStatus();
            pool.withdraw(rangeIndex);
            vm.stopPrank();
        }
    }

    function testSwap2() public {
        {
            vm.startPrank(account1, account1);
            JETH.approve(address(pool), type(uint256).max);
            uint256 a = 2 * 10**18;
            uint256 s = pool.sufficientOrderIndexSearch(a);
            pool.swap(a, true, true, s);
            vm.stopPrank();
        }

        {
            vm.startPrank(account2, account2);
            JETH.approve(address(pool), type(uint256).max);
            uint256 a = 2 * 10**18;
            uint256 s = pool.sufficientOrderIndexSearch(a);
            pool.swap(a, true, true, s);
            vm.stopPrank();
        }

        {
            vm.startPrank(account3, account3);
            JUSD.approve(address(reversePool), type(uint256).max);
            uint256 a = 3000 * 10**18;
            uint256 s = reversePool.sufficientOrderIndexSearch(a);
            reversePool.swap(a, true, true, s);
            vm.stopPrank();
        }

        {
            vm.startPrank(account4, account4);
            JUSD.approve(address(reversePool), type(uint256).max);
            uint256 a = 100 * 10**18;
            uint256 s = reversePool.sufficientOrderIndexSearch(a);
            console.log("sufficientOrderIndexSearch %s", s);
            reversePool.swap(a, true, true, s);
            vm.stopPrank();
        }
    }

    function testSwap3Withdraw() public {
        { // 1 swaps
            vm.startPrank(account1, account1);
            JETH.approve(address(pool), type(uint256).max);
            uint256 a = 2 * 10**18;
            uint256 s = pool.sufficientOrderIndexSearch(a);
            pool.swap(a, true, true, s);
            vm.stopPrank();
        }

        { // 2 swaps
            vm.startPrank(account2, account2);
            JETH.approve(address(pool), type(uint256).max);
            uint256 a = 2 * 10**18;
            uint256 s = pool.sufficientOrderIndexSearch(a);
            pool.swap(a, true, true, s);
            vm.stopPrank();
        }

        { // 3 counterswaps
            vm.startPrank(account3, account3);
            JUSD.approve(address(reversePool), type(uint256).max);
            uint256 a = 3000 * 10**18;
            uint256 s = reversePool.sufficientOrderIndexSearch(a);
            reversePool.swap(a, true, true, s);
            vm.stopPrank();
        }

        { // 1 withdraws
            vm.startPrank(account1, account1);
            (,, uint256 rangeIndex) = pool.orderStatus();
            pool.withdraw(rangeIndex);
            vm.stopPrank();
        }

        { // 4 counterswaps
            vm.startPrank(account4, account4);
            JUSD.approve(address(reversePool), type(uint256).max);
            uint256 a = 3000 * 10**18;
            uint256 s = reversePool.sufficientOrderIndexSearch(a);
            reversePool.swap(a, true, true, s);
            vm.stopPrank();
        }

        { // 2 withdraws
            vm.startPrank(account2, account2);
            (,, uint256 rangeIndex) = pool.orderStatus();
            pool.withdraw(rangeIndex);
            vm.stopPrank();
        }

        { // 2 swaps again
            vm.startPrank(account2, account2);
            JETH.approve(address(pool), type(uint256).max);
            uint256 a = 2 * 10**18;
            uint256 s = pool.sufficientOrderIndexSearch(a);
            pool.swap(a, true, true, s);
            vm.stopPrank();
        }

        { // 4 withdraws
            vm.startPrank(account4, account4);
            (,, uint256 rangeIndex) = reversePool.orderStatus();
            reversePool.withdraw(rangeIndex);
            vm.stopPrank();
        }
    }

    function test2MakersAndWithdraw() public {
        { // 1 swamakerps
            vm.startPrank(account1, account1);
            JETH.approve(address(pool), type(uint256).max);
            uint256 a = 2 * 10**18;
            uint256 s = pool.sufficientOrderIndexSearch(a);
            pool.swap(a, false, true, s);
            vm.stopPrank();
        }

        { // 2 maker - reverse
            vm.startPrank(account2, account2);
            JUSD.approve(address(reversePool), type(uint256).max);
            uint256 a = 3000 * 10**18;
            uint256 s = reversePool.sufficientOrderIndexSearch(a);
            reversePool.swap(a, false, true, s);
            vm.stopPrank();
        }

        { // 1 withdraws
            vm.startPrank(account1, account1);
            (, uint256 remainingB, uint256 rangeIndex) = pool.orderStatus();
            assertEq(remainingB, 0);
            pool.withdraw(rangeIndex);
            vm.stopPrank();
        }

        { // 2 withdraws
            vm.startPrank(account2, account2);
            (, uint256 remainingB, uint256 rangeIndex) = reversePool.orderStatus();
            assertEq(remainingB, 0);
            reversePool.withdraw(rangeIndex);
            vm.stopPrank();
        }
    }

}
