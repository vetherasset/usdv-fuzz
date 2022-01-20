// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "ds-test/test.sol";

import "./UsdvFuzz.sol";

contract UsdvFuzzTest is DSTest {
    UsdvFuzz fuzz;

    function setUp() public {
        fuzz = new UsdvFuzz();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
