// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";

import {UniswapV2Factory} from "lib/uniswap-v2-core-latest/src/UniswapV2Factory.sol";
import {UniswapV2Pair} from "lib/uniswap-v2-core-latest/src/UniswapV2Pair.sol";
import {IUniswapV2Pair} from "lib/uniswap-v2-core-latest/src/interfaces/IUniswapV2Pair.sol";
import {ERC20 as TestERC20} from "src/test/ERC20.sol";

contract Fixtures is Test {
    struct FactoryFixture {
        UniswapV2Factory factory;
    }

    struct PairFixture {
        UniswapV2Factory factory;
        TestERC20 token0;
        TestERC20 token1;
        IUniswapV2Pair pair;
    }

    function factoryFixture(address feeToSetter) public returns (FactoryFixture memory) {
        UniswapV2Factory factory = new UniswapV2Factory(feeToSetter);
        return FactoryFixture({factory: factory});
    }

    function pairFixture(address wallet) public returns (PairFixture memory) {
        FactoryFixture memory f = factoryFixture(wallet);
        return pairFixtureWithFactory(f.factory);
    }

    function pairFixtureWithFactory(UniswapV2Factory factory) public returns (PairFixture memory) {
        TestERC20 tokenA = new TestERC20(10_000 ether);
        TestERC20 tokenB = new TestERC20(10_000 ether);

        factory.createPair(address(tokenA), address(tokenB));
        address pairAddr = factory.getPair(address(tokenA), address(tokenB));
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddr);

        address token0Addr = pair.token0();
        TestERC20 token0 = address(tokenA) == token0Addr ? tokenA : tokenB;
        TestERC20 token1 = address(tokenA) == token0Addr ? tokenB : tokenA;

        return PairFixture({factory: factory, token0: token0, token1: token1, pair: pair});
    }
}
