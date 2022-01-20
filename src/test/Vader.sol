// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Vader is ERC20 {
    constructor() ERC20("Vader", "VADER") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
