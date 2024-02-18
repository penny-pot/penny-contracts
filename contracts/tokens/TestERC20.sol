// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

//For Testing Contract ABI on Remix.
contract TestERC20 is ERC20 {
    constructor() ERC20("USDC", "USDC") {
        _mint(msg.sender, 100 * 10 ** 18);
    }
}
