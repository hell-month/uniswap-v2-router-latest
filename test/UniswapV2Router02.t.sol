// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";

import {UniswapV2Router02} from "src/UniswapV2Router02.sol";
import {UniswapV2Factory} from "lib/uniswap-v2-core-latest/src/UniswapV2Factory.sol";
import {IUniswapV2Pair} from "lib/uniswap-v2-core-latest/src/interfaces/IUniswapV2Pair.sol";
import {UniswapV2Pair} from "lib/uniswap-v2-core-latest/src/UniswapV2Pair.sol";

import {ERC20 as TestERC20} from "src/test/ERC20.sol";
import {DeflatingERC20} from "src/test/DeflatingERC20.sol";
import {WETH9} from "src/test/WETH9.sol";
import {Fixtures} from "test/shared/Fixtures.t.sol";

contract UniswapV2Router02Test is Test, Fixtures {
    UniswapV2Router02 internal router;
    UniswapV2Factory internal factory;
    WETH9 internal weth;
    TestERC20 internal token0;
    TestERC20 internal token1;

    address internal self;

    function setUp() public {
        self = address(this);
        weth = new WETH9();
        factory = new UniswapV2Factory(self);
        router = new UniswapV2Router02(address(factory), address(weth));

        Fixtures.PairFixture memory fx = pairFixture(self);
        token0 = fx.token0;
        token1 = fx.token1;

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
        router.addLiquidity(address(token0), address(token1), amount, amount, 0, 0, self, type(uint256).max);
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
        uint256[] memory amounts = router.getAmountsOut(2, path);
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
        uint256[] memory amounts = router.getAmountsIn(1, path);
        assertEq(amounts.length, 2);
        assertEq(amounts[0], 2);
        assertEq(amounts[1], 1);
    }
}

contract FeeOnTransferTokensTest is Test, Fixtures {
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
        router.addLiquidityETH{value: ethAmount}(address(dtt), dttAmount, dttAmount, ethAmount, self, type(uint256).max);
    }

    receive() external payable {}

    function _pairPermitSig(UniswapV2Pair lp, address owner, uint256 ownerPk, uint256 value, uint256 deadline)
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        uint256 nonce = lp.nonces(owner);
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                lp.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(lp.PERMIT_TYPEHASH(), owner, address(router), value, nonce, deadline))
            )
        );
        return vm.sign(ownerPk, digest);
    }

    function test_removeLiquidityETHSupportingFeeOnTransferTokens() public {
        uint256 dttAmount = 1 ether;
        uint256 ethAmount = 4 ether;
        _addLiquidity((dttAmount * 100) / 99, ethAmount);

        uint256 liquidity = pair.balanceOf(self);
        pair.approve(address(router), type(uint256).max);

        router.removeLiquidityETHSupportingFeeOnTransferTokens(address(dtt), liquidity, 0, 0, self, type(uint256).max);

        assertGt(self.balance, 0);
    }

    function test_removeLiquidityETHWithPermitSupportingFeeOnTransferTokens() public {
        uint256 ownerPk = 0xBEEF;
        address owner = vm.addr(ownerPk);

        // fund owner
        vm.deal(owner, 100 ether);

        vm.prank(owner);
        DeflatingERC20 localDtt = new DeflatingERC20(10_000 ether);

        factory.createPair(address(localDtt), address(weth));
        address p = factory.getPair(address(localDtt), address(weth));
        UniswapV2Pair localPair = UniswapV2Pair(p);

        vm.startPrank(owner);
        localDtt.approve(address(router), type(uint256).max);
        router.addLiquidityETH{value: 4 ether}(
            address(localDtt),
            (1 ether * 100) / uint256(99),
            (1 ether * 100) / uint256(99),
            4 ether,
            owner,
            type(uint256).max
        );
        uint256 liquidity = localPair.balanceOf(owner);
        uint256 deadline = type(uint256).max;
        (uint8 v, bytes32 r, bytes32 s) = _pairPermitSig(localPair, owner, ownerPk, liquidity, deadline);

        router.removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
            address(localDtt), liquidity, 0, 0, owner, deadline, false, v, r, s
        );
        vm.stopPrank();

        assertGt(owner.balance, 0);
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

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn, 0, path, self, type(uint256).max);
        assertGt(weth.balanceOf(self), 0);
    }

    function test_swapExactTokensForTokensSupportingFeeOnTransferTokens_WETH_to_DTT() public {
        uint256 dttAmount = 5 ether;
        uint256 ethAmount = 10 ether;
        _addLiquidity((dttAmount * 100) / 99, ethAmount);

        weth.deposit{value: 1 ether}();
        weth.approve(address(router), type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(dtt);

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(1 ether, 0, path, self, type(uint256).max);
        assertGt(dtt.balanceOf(self), 0);
    }

    function test_swapExactETHForTokensSupportingFeeOnTransferTokens_ETH_to_DTT() public {
        uint256 dttAmount = 10 ether;
        uint256 ethAmount = 5 ether;
        _addLiquidity((dttAmount * 100) / 99, ethAmount);

        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(dtt);

        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: 1 ether}(0, path, self, type(uint256).max);

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
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(1 ether, 0, path, self, type(uint256).max);
        assertGt(self.balance, balanceBefore);
    }
}

contract FeeOnTransferTokensReloadedTest is Test {
    UniswapV2Router02 internal router;
    UniswapV2Factory internal factory;
    DeflatingERC20 internal dtt;
    DeflatingERC20 internal dtt2;

    function setUp() public {
        factory = new UniswapV2Factory(address(this));
        router = new UniswapV2Router02(address(factory), address(new WETH9()));
        dtt = new DeflatingERC20(10_000 ether);
        dtt2 = new DeflatingERC20(10_000 ether);

        factory.createPair(address(dtt), address(dtt2));
    }

    function _addLiquidity(uint256 amountA, uint256 amountB) internal {
        dtt.approve(address(router), type(uint256).max);
        dtt2.approve(address(router), type(uint256).max);
        router.addLiquidity(
            address(dtt), address(dtt2), amountA, amountB, amountA, amountB, address(this), type(uint256).max
        );
    }

    function test_swapExactTokensForTokensSupportingFeeOnTransferTokens_DTT_to_DTT2() public {
        _addLiquidity(5 ether, 5 ether);
        dtt.approve(address(router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(dtt);
        path[1] = address(dtt2);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(1 ether, 0, path, address(this), type(uint256).max);
        assertGt(dtt2.balanceOf(address(this)), 0);
    }
}
