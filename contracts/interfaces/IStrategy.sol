// IStrategy.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStrategy {
    function initialize(
        address[] memory _whitelist,
        bytes32 _memberRole,
        bytes32 _adminRole,
        uint256 _lockPeriod
    ) external;

    function optIn(address token, uint256 serialNumber, address user) external;

    function whitelist(address token) external;

    function deposit(address token, uint256 amount, address sender) external;

    function withdraw(address token, address receiver, uint256 amount) external;

    function getTokenDetails(
        address token,
        address user
    ) external view returns (bool, uint256, uint256, uint256);

    function getShareholders(
        address token
    ) external returns (address[] memory, uint256[] memory);

    function isWhiteListed(address token) external view returns (bool);
}
