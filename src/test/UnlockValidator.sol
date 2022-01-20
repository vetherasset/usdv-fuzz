// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity =0.8.9;

import "../interfaces/tokens/validator/IUnlockValidator.sol";

contract UnlockValidator is IUnlockValidator {
    function isValid(
        address,
        uint256,
        IUSDV.LockTypes
    ) external pure override returns (bool) {
        return true;
    }
}
