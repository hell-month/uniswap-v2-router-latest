// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";

import {ExampleSwapToPrice} from "src/examples/ExampleSwapToPrice.sol";
import {UniswapV2Router02} from "src/UniswapV2Router02.sol";
import {UniswapV2Factory} from "lib/uniswap-v2-core-latest/src/UniswapV2Factory.sol";
import {IUniswapV2Pair} from "lib/uniswap-v2-core-latest/src/interfaces/IUniswapV2Pair.sol";
import {ERC20 as TestERC20} from "src/test/ERC20.sol";
import {WETH9} from "src/test/WETH9.sol";
import {Fixtures} from "test/shared/Fixtures.t.sol";

contract ExampleSwapToPriceTest is Test, Fixtures {
    UniswapV2Factory internal factory;
    UniswapV2Router02 internal router;
    WETH9 internal weth;
    TestERC20 internal token0;
    TestERC20 internal token1;
    IUniswapV2Pair internal pair;
    ExampleSwapToPrice internal swapper;

    address internal self;

    // Match ERC20 events for expectEmit
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() public {
        self = address(this);
        weth = new WETH9();
        factory = new UniswapV2Factory(self);
        router = new UniswapV2Router02(address(factory), address(weth));

        Fixtures.PairFixture memory fx = pairFixtureWithFactory(factory);
        token0 = fx.token0;
        token1 = fx.token1;
        pair = fx.pair;

        swapper = new ExampleSwapToPrice(address(factory), router);
        token0.approve(address(swapper), type(uint256).max);
        token1.approve(address(swapper), type(uint256).max);
    }

    function _syncToRatio_1_to_100() internal {
        token0.transfer(address(pair), 10 ether);
        token1.transfer(address(pair), 1000 ether);
        pair.sync();
    }

    function test_routerAddress() public {
        assertEq(address(swapper.router()), address(router));
    }

    function test_swapToPrice_requiresNonZeroTruePriceInputs() public {
        _syncToRatio_1_to_100();
        vm.expectRevert(bytes("ExampleSwapToPrice: ZERO_PRICE"));
        swapper.swapToPrice(
            address(token0), address(token1), 0, 0, type(uint256).max, type(uint256).max, self, type(uint256).max
        );

        vm.expectRevert(bytes("ExampleSwapToPrice: ZERO_PRICE"));
        swapper.swapToPrice(
            address(token0), address(token1), 10, 0, type(uint256).max, type(uint256).max, self, type(uint256).max
        );

        vm.expectRevert(bytes("ExampleSwapToPrice: ZERO_PRICE"));
        swapper.swapToPrice(
            address(token0), address(token1), 0, 10, type(uint256).max, type(uint256).max, self, type(uint256).max
        );
    }

    function test_swapToPrice_requiresNonZeroMaxSpend() public {
        _syncToRatio_1_to_100();
        vm.expectRevert(bytes("ExampleSwapToPrice: ZERO_SPEND"));
        swapper.swapToPrice(address(token0), address(token1), 1, 100, 0, 0, self, type(uint256).max);
    }

    function test_swapToPrice_movesTo_1_to_90() public {
        _syncToRatio_1_to_100();

        // Expect exact sequence of events
        uint256 amountIn = 526682316179835569; // token0 in
        uint256 amountOut = 49890467170695440744; // token1 out
        vm.expectEmit(address(token0));
        emit Transfer(self, address(swapper), amountIn);
        vm.expectEmit(address(token0));
        emit Approval(address(swapper), address(router), amountIn);
        vm.expectEmit(address(token0));
        emit Transfer(address(swapper), address(pair), amountIn);
        vm.expectEmit(address(token1));
        emit Transfer(address(pair), self, amountOut);

        swapper.swapToPrice(
            address(token0), address(token1), 1, 90, type(uint256).max, type(uint256).max, self, type(uint256).max
        );

        assertGt(token1.balanceOf(self), 0);
    }

    function test_swapToPrice_movesTo_1_to_110() public {
        _syncToRatio_1_to_100();
        uint256 amountIn = 47376582963642643588; // token1 in
        uint256 amountOut = 451039908682851138; // token0 out
        vm.expectEmit(address(token1));
        emit Transfer(self, address(swapper), amountIn);
        vm.expectEmit(address(token1));
        emit Approval(address(swapper), address(router), amountIn);
        vm.expectEmit(address(token1));
        emit Transfer(address(swapper), address(pair), amountIn);
        vm.expectEmit(address(token0));
        emit Transfer(address(pair), self, amountOut);

        swapper.swapToPrice(
            address(token0), address(token1), 1, 110, type(uint256).max, type(uint256).max, self, type(uint256).max
        );
        assertGt(token0.balanceOf(self), 0);
    }

    function test_swapToPrice_reverseOrder() public {
        _syncToRatio_1_to_100();
        uint256 amountIn = 47376582963642643588; // token1 in
        uint256 amountOut = 451039908682851138; // token0 out
        vm.expectEmit(address(token1));
        emit Transfer(self, address(swapper), amountIn);
        vm.expectEmit(address(token1));
        emit Approval(address(swapper), address(router), amountIn);
        vm.expectEmit(address(token1));
        emit Transfer(address(swapper), address(pair), amountIn);
        vm.expectEmit(address(token0));
        emit Transfer(address(pair), self, amountOut);

        swapper.swapToPrice(
            address(token1), address(token0), 110, 1, type(uint256).max, type(uint256).max, self, type(uint256).max
        );
        assertGt(token0.balanceOf(self), 0);
    }
}
