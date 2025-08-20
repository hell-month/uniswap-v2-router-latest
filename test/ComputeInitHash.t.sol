// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import {UniswapV2Pair} from "lib/uniswap-v2-core-latest/src/UniswapV2Pair.sol";

contract ComputeInitHash is Test {
    function test_printInitCodeHash() public {
        bytes32 h = keccak256(type(UniswapV2Pair).creationCode);
        console2.logBytes32(h);
        // dummy assert
        assertTrue(h != bytes32(0));
    }
}
