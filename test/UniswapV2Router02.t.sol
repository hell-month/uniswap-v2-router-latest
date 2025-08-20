// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";

import {UniswapV2Router02} from "src/UniswapV2Router02.sol";
import {IUniswapV2Factory} from "uniswap-v2-core-latest/src/interfaces/IUniswapV2Factory.sol";
import {UniswapV2Factory} from "uniswap-v2-core-latest/src/UniswapV2Factory.sol";
import {IUniswapV2Pair} from "uniswap-v2-core-latest/src/interfaces/IUniswapV2Pair.sol";

import {ERC20 as TestERC20} from "src/test/ERC20.sol";
import {DeflatingERC20} from "src/test/DeflatingERC20.sol";
import {WETH9} from "src/test/WETH9.sol";

contract UniswapV2Router02Test is Test {
    UniswapV2Router02 internal router;
    IUniswapV2Factory internal factory;
    WETH9 internal weth;
    TestERC20 internal token0;
    TestERC20 internal token1;

    address internal self;

    function setUp() public {
        self = address(this);
        weth = new WETH9();
        factory = IUniswapV2Factory(address(new UniswapV2Factory(self)));
        router = new UniswapV2Router02(address(factory), address(weth));

        token0 = new TestERC20(1_000_000 ether);
        token1 = new TestERC20(1_000_000 ether);

        // approve router to move tokens
        token0.approve(address(router), type(uint256).max);
        token1.approve(address(router), type(uint256).max);
    }

    function test_quote() public {
        assertEq(router.quote(1, 100, 200), 2);
        assertEq(router.quote(2, 200, 100), 1);

        vm.expectRevert(bytes("UniswapV2Library: INSUFFICIENT_AMOUNT"));
        router.quote(0, 100, 200);
        vm.expectRevert(bytes("UniswapV2Library: INSUFFICIENT_LIQUIDITY"));
        router.quote(1, 0, 200);
        vm.expectRevert(bytes("UniswapV2Library: INSUFFICIENT_LIQUIDITY"));
        router.quote(1, 100, 0);
    }

    function _addLiquiditySimple(uint256 amount) internal {
        router.addLiquidity(
            address(token0),
            address(token1),
            amount,
            amount,
            0,
            0,
            self,
            type(uint256).max
        );
    }

    function test_getAmountOut() public {
        assertEq(router.getAmountOut(2, 100, 100), 1);
        vm.expectRevert(bytes("UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT"));
        router.getAmountOut(0, 100, 100);
        vm.expectRevert(bytes("UniswapV2Library: INSUFFICIENT_LIQUIDITY"));
        router.getAmountOut(2, 0, 100);
        vm.expectRevert(bytes("UniswapV2Library: INSUFFICIENT_LIQUIDITY"));
        router.getAmountOut(2, 100, 0);
    }

    function test_getAmountIn() public {
        assertEq(router.getAmountIn(1, 100, 100), 2);
        vm.expectRevert(bytes("UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT"));
        router.getAmountIn(0, 100, 100);
        vm.expectRevert(bytes("UniswapV2Library: INSUFFICIENT_LIQUIDITY"));
        router.getAmountIn(1, 0, 100);
        vm.expectRevert(bytes("UniswapV2Library: INSUFFICIENT_LIQUIDITY"));
        router.getAmountIn(1, 100, 0);
    }

    function test_getAmountsOut() public {
        _addLiquiditySimple(10_000);

        address[] memory badPath = new address[](1);
        badPath[0] = address(token0);
        vm.expectRevert(bytes("UniswapV2Library: INVALID_PATH"));
        router.getAmountsOut(2, badPath);

        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);
        uint[] memory amounts = router.getAmountsOut(2, path);
        assertEq(amounts.length, 2);
        assertEq(amounts[0], 2);
        assertEq(amounts[1], 1);
    }

    function test_getAmountsIn() public {
        _addLiquiditySimple(10_000);

        address[] memory badPath = new address[](1);
        badPath[0] = address(token0);
        vm.expectRevert(bytes("UniswapV2Library: INVALID_PATH"));
        router.getAmountsIn(1, badPath);

        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);
        uint[] memory amounts = router.getAmountsIn(1, path);
        assertEq(amounts.length, 2);
        assertEq(amounts[0], 2);
        assertEq(amounts[1], 1);
    }
}

contract FeeOnTransferTokensTest is Test {
    UniswapV2Router02 internal router;
    UniswapV2Factory internal factory;
    WETH9 internal weth;
    DeflatingERC20 internal dtt;
    IUniswapV2Pair internal pair;

    address internal self;

    function setUp() public {
        self = address(this);
        weth = new WETH9();
        factory = new UniswapV2Factory(self);
        router = new UniswapV2Router02(address(factory), address(weth));
        dtt = new DeflatingERC20(10_000 ether);

        factory.createPair(address(dtt), address(weth));
        address p = factory.getPair(address(dtt), address(weth));
        pair = IUniswapV2Pair(p);
    }

    function _addLiquidity(uint256 dttAmount, uint256 ethAmount) internal {
        dtt.approve(address(router), type(uint256).max);
        router.addLiquidityETH{value: ethAmount}(
            address(dtt),
            dttAmount,
            dttAmount,
            ethAmount,
            self,
            type(uint256).max
        );
    }

    receive() external payable {}

    function test_removeLiquidityETHSupportingFeeOnTransferTokens() public {
        uint256 dttAmount = 1 ether;
        uint256 ethAmount = 4 ether;
        _addLiquidity((dttAmount * 100) / 99, ethAmount);

        uint256 liquidity = pair.balanceOf(self);
        pair.approve(address(router), type(uint256).max);

        router.removeLiquidityETHSupportingFeeOnTransferTokens(
            address(dtt),
            liquidity,
            0,
            0,
            self,
            type(uint256).max
        );

        // no assertion on exact amounts; just ensure no revert and we received some ETH
        assertGt(self.balance, 0);
    }

    function test_swapExactTokensForTokensSupportingFeeOnTransferTokens_DTT_to_WETH() public {
        uint256 dttAmount = 5 ether;
        uint256 ethAmount = 10 ether;
        _addLiquidity((dttAmount * 100) / 99, ethAmount);

        uint256 amountIn = 1 ether;
        dtt.approve(address(router), type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = address(dtt);
        path[1] = address(weth);

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn,
            0,
            path,
            self,
            type(uint256).max
        );
        // ensure we received some WETH
        assertGt(weth.balanceOf(self), 0);
    }

    function test_swapExactETHForTokensSupportingFeeOnTransferTokens_ETH_to_DTT() public {
        uint256 dttAmount = 10 ether;
        uint256 ethAmount = 5 ether;
        _addLiquidity((dttAmount * 100) / 99, ethAmount);

        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(dtt);

        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: 1 ether}(
            0,
            path,
            self,
            type(uint256).max
        );

        assertGt(dtt.balanceOf(self), 0);
    }

    function test_swapExactTokensForETHSupportingFeeOnTransferTokens_DTT_to_ETH() public {
        uint256 dttAmount = 5 ether;
        uint256 ethAmount = 10 ether;
        _addLiquidity((dttAmount * 100) / 99, ethAmount);

        dtt.approve(address(router), type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = address(dtt);
        path[1] = address(weth);

        uint256 balanceBefore = self.balance;
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            1 ether,
            0,
            path,
            self,
            type(uint256).max
        );
        assertGt(self.balance, balanceBefore);
    }
}


