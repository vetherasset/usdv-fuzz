// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

interface IHevm {
    function warp(uint x) external;

    function roll(uint x) external;
}