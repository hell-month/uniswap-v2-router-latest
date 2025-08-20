// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";

import {ExampleComputeLiquidityValue} from "src/examples/ExampleComputeLiquidityValue.sol";
import {UniswapV2Router02} from "src/UniswapV2Router02.sol";
import {UniswapV2Factory} from "lib/uniswap-v2-core-latest/src/UniswapV2Factory.sol";
import {IUniswapV2Pair} from "lib/uniswap-v2-core-latest/src/interfaces/IUniswapV2Pair.sol";
import {ERC20 as TestERC20} from "src/test/ERC20.sol";
import {WETH9} from "src/test/WETH9.sol";

contract ExampleComputeLiquidityValueTest is Test {
    UniswapV2Factory internal factory;
    UniswapV2Router02 internal router;
    WETH9 internal weth;
    TestERC20 internal token0;
    TestERC20 internal token1;
    IUniswapV2Pair internal pair;
    ExampleComputeLiquidityValue internal comp;

    address internal self;

    function setUp() public {
        self = address(this);
        weth = new WETH9();
        factory = new UniswapV2Factory(self);
        router = new UniswapV2Router02(address(factory), address(weth));
        token0 = new TestERC20(1_000_000 ether);
        token1 = new TestERC20(1_000_000 ether);
        factory.createPair(address(token0), address(token1));
        pair = IUniswapV2Pair(factory.getPair(address(token0), address(token1)));

        comp = new ExampleComputeLiquidityValue(address(factory));
    }

    function _mintPair1to100_100Shares() internal {
        token0.transfer(address(pair), 10 ether);
        token1.transfer(address(pair), 1000 ether);
        pair.mint(self);
        assertEq(pair.totalSupply(), 100 ether);
    }

    function test_factoryAddress() public {
        assertEq(comp.factory(), address(factory));
    }
}


