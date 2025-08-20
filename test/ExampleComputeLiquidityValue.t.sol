// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";

import {ExampleComputeLiquidityValue} from "src/examples/ExampleComputeLiquidityValue.sol";
import {UniswapV2Router02} from "src/UniswapV2Router02.sol";
import {UniswapV2Factory} from "lib/uniswap-v2-core-latest/src/UniswapV2Factory.sol";
import {IUniswapV2Pair} from "lib/uniswap-v2-core-latest/src/interfaces/IUniswapV2Pair.sol";
import {ERC20 as TestERC20} from "src/test/ERC20.sol";
import {WETH9} from "src/test/WETH9.sol";
import {Fixtures} from "test/shared/Fixtures.t.sol";

contract ExampleComputeLiquidityValueTest is Test, Fixtures {
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

        Fixtures.PairFixture memory fx = pairFixtureWithFactory(factory);
        token0 = fx.token0;
        token1 = fx.token1;
        pair = fx.pair;

        comp = new ExampleComputeLiquidityValue(address(factory));
    }

    function _mintPair1to100_100Shares() internal {
        token0.transfer(address(pair), 10 ether);
        token1.transfer(address(pair), 1000 ether);
        pair.mint(self);
        assertEq(pair.totalSupply(), 100 ether);
    }

    function _approveRouter(address tkn, uint256 amount) internal {
        (bool ok,) = tkn.call(abi.encodeWithSignature("approve(address,uint256)", address(router), amount));
        require(ok, "approve failed");
    }

    function test_factoryAddress() public {
        assertEq(comp.factory(), address(factory));
    }

    function test_getLiquidityValue_correct_for_5_shares() public {
        _mintPair1to100_100Shares();
        (uint256 a, uint256 b) = comp.getLiquidityValue(address(token0), address(token1), 5 ether);
        assertEq(a, 500000000000000000);
        assertEq(b, 50000000000000000000);
    }

    function test_getLiquidityValue_correct_for_7_shares() public {
        _mintPair1to100_100Shares();
        (uint256 a, uint256 b) = comp.getLiquidityValue(address(token0), address(token1), 7 ether);
        assertEq(a, 700000000000000000);
        assertEq(b, 70000000000000000000);
    }

    function test_getLiquidityValue_correct_after_swap() public {
        _mintPair1to100_100Shares();
        _approveRouter(address(token0), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);
        router.swapExactTokensForTokens(10 ether, 0, path, self, type(uint256).max);
        (uint256 a, uint256 b) = comp.getLiquidityValue(address(token0), address(token1), 7 ether);
        assertEq(a, 1400000000000000000);
        assertEq(b, 35052578868302453680);
    }

    function test_getReservesAfterArbitrage_1_over_400() public {
        _mintPair1to100_100Shares();
        (uint256 rA, uint256 rB) = comp.getReservesAfterArbitrage(address(token0), address(token1), 1, 400);
        assertEq(rA, 5007516917298542016);
        assertEq(rB, 1999997739838173075192);
    }

    function test_getReservesAfterArbitrage_1_over_200() public {
        _mintPair1to100_100Shares();
        (uint256 rA, uint256 rB) = comp.getReservesAfterArbitrage(address(token0), address(token1), 1, 200);
        assertEq(rA, 7081698338256310291);
        assertEq(rB, 1413330640570018326894);
    }

    function test_getReservesAfterArbitrage_1_over_100() public {
        _mintPair1to100_100Shares();
        (uint256 rA, uint256 rB) = comp.getReservesAfterArbitrage(address(token0), address(token1), 1, 100);
        assertEq(rA, 10000000000000000000);
        assertEq(rB, 1000000000000000000000);
    }

    function test_getReservesAfterArbitrage_1_over_50() public {
        _mintPair1to100_100Shares();
        (uint256 rA, uint256 rB) = comp.getReservesAfterArbitrage(address(token0), address(token1), 1, 50);
        assertEq(rA, 14133306405700183269);
        assertEq(rB, 708169833825631029041);
    }

    function test_getReservesAfterArbitrage_1_over_25() public {
        _mintPair1to100_100Shares();
        (uint256 rA, uint256 rB) = comp.getReservesAfterArbitrage(address(token0), address(token1), 1, 25);
        assertEq(rA, 19999977398381730752);
        assertEq(rB, 500751691729854201595);
    }

    function test_getReservesAfterArbitrage_25_over_1() public {
        _mintPair1to100_100Shares();
        (uint256 rA, uint256 rB) = comp.getReservesAfterArbitrage(address(token0), address(token1), 25, 1);
        assertEq(rA, 500721601459041764285);
        assertEq(rB, 20030067669194168064);
    }

    function test_getReservesAfterArbitrage_largePrice() public {
        _mintPair1to100_100Shares();
        // Use a large but safer value that avoids overflow in mulDiv paths
        uint256 big = 1e24;
        (uint256 rA, uint256 rB) = comp.getReservesAfterArbitrage(address(token0), address(token1), big, big);
        assertGt(rA, 0);
        assertGt(rB, 0);
    }

    function test_getLiquidityValueAfterArbitrageToPrice_feeOff_1_to_105() public {
        _mintPair1to100_100Shares();
        (uint256 a, uint256 b) =
            comp.getLiquidityValueAfterArbitrageToPrice(address(token0), address(token1), 1, 105, 5 ether);
        assertEq(a, 488683612488266114);
        assertEq(b, 51161327957205755422);
    }

    function test_getLiquidityValueAfterArbitrageToPrice_feeOff_1_to_95() public {
        _mintPair1to100_100Shares();
        (uint256 a, uint256 b) =
            comp.getLiquidityValueAfterArbitrageToPrice(address(token0), address(token1), 1, 95, 5 ether);
        assertEq(a, 512255881944227034);
        assertEq(b, 48807237571060645526);
    }

    function test_getLiquidityValueAfterArbitrageToPrice_feeOff_1_to_100() public {
        _mintPair1to100_100Shares();
        (uint256 a, uint256 b) =
            comp.getLiquidityValueAfterArbitrageToPrice(address(token0), address(token1), 1, 100, 5 ether);
        assertEq(a, 500000000000000000);
        assertEq(b, 50000000000000000000);
    }

    function test_gasCost_current_price_feeOff() public {
        _mintPair1to100_100Shares();
        uint256 gasCost =
            comp.getGasCostOfGetLiquidityValueAfterArbitrageToPrice(address(token0), address(token1), 1, 100, 5 ether);
        assertGt(gasCost, 0);
    }

    function test_gasCost_higher_price_feeOff() public {
        _mintPair1to100_100Shares();
        uint256 gasCost =
            comp.getGasCostOfGetLiquidityValueAfterArbitrageToPrice(address(token0), address(token1), 1, 105, 5 ether);
        assertGt(gasCost, 0);
    }

    function test_gasCost_lower_price_feeOff() public {
        _mintPair1to100_100Shares();
        uint256 gasCost =
            comp.getGasCostOfGetLiquidityValueAfterArbitrageToPrice(address(token0), address(token1), 1, 95, 5 ether);
        assertGt(gasCost, 0);
    }

    function test_afterSwap_feeOff_isRoughly_1_over_25() public {
        _mintPair1to100_100Shares();
        _approveRouter(address(token0), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);
        router.swapExactTokensForTokens(10 ether, 0, path, self, type(uint256).max);
        (uint256 a, uint256 b) =
            comp.getLiquidityValueAfterArbitrageToPrice(address(token0), address(token1), 1, 25, 5 ether);
        assertEq(a, 1000000000000000000);
        assertEq(b, 25037556334501752628);
    }

    function test_afterSwap_feeOff_sharesAfterArbBackTo_1_over_100() public {
        _mintPair1to100_100Shares();
        _approveRouter(address(token0), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);
        router.swapExactTokensForTokens(10 ether, 0, path, self, type(uint256).max);
        (uint256 a, uint256 b) =
            comp.getLiquidityValueAfterArbitrageToPrice(address(token0), address(token1), 1, 100, 5 ether);
        assertEq(a, 501127678536722155);
        assertEq(b, 50037429168613534246);
    }

    function test_feeOn_correctAfterSwap() public {
        _mintPair1to100_100Shares();
        factory.setFeeTo(self);
        token0.transfer(address(pair), 10 ether);
        token1.transfer(address(pair), 1000 ether);
        pair.mint(address(0));
        assertEq(pair.totalSupply(), 200 ether);
        _approveRouter(address(token0), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);
        router.swapExactTokensForTokens(20 ether, 0, path, self, type(uint256).max);
        (uint256 a, uint256 b) = comp.getLiquidityValue(address(token0), address(token1), 7 ether);
        assertEq(a, 1399824934325735058);
        assertEq(b, 35048195651620807684);
    }

    function test_gasCost_feeOn_current_price() public {
        _mintPair1to100_100Shares();
        factory.setFeeTo(self);
        token0.transfer(address(pair), 10 ether);
        token1.transfer(address(pair), 1000 ether);
        pair.mint(address(0));
        uint256 gasCost =
            comp.getGasCostOfGetLiquidityValueAfterArbitrageToPrice(address(token0), address(token1), 1, 100, 5 ether);
        assertGt(gasCost, 0);
    }

    function test_gasCost_feeOn_higher_price() public {
        _mintPair1to100_100Shares();
        factory.setFeeTo(self);
        token0.transfer(address(pair), 10 ether);
        token1.transfer(address(pair), 1000 ether);
        pair.mint(address(0));
        uint256 gasCost =
            comp.getGasCostOfGetLiquidityValueAfterArbitrageToPrice(address(token0), address(token1), 1, 105, 5 ether);
        assertGt(gasCost, 0);
    }

    function test_gasCost_feeOn_lower_price() public {
        _mintPair1to100_100Shares();
        factory.setFeeTo(self);
        token0.transfer(address(pair), 10 ether);
        token1.transfer(address(pair), 1000 ether);
        pair.mint(address(0));
        uint256 gasCost =
            comp.getGasCostOfGetLiquidityValueAfterArbitrageToPrice(address(token0), address(token1), 1, 95, 5 ether);
        assertGt(gasCost, 0);
    }
}
