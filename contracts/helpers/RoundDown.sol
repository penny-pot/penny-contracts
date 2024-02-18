// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RoundDown {
    function _roundDownERC20Balance(
        address token,
        uint256 userBalance,
        address sender
    ) internal view returns (uint256 remainder) {
        // Get ERC20 token contract
        ERC20 erc20 = ERC20(
            address(token) //0x3b70652cB79780cA1bf60a8b34cc589BbeDc00B2
        );

        // Get the balance of the sender in the ERC20 token
        // uint256 balance = erc20.balanceOf(sender);
        uint256 balance = userBalance;

        // Convert the balance to a number (remove the 18 decimals)
        uint256 balanceAsNumber = balance / 10 ** erc20.decimals();

        // Check again if rounding down is required
        bool requiresRoundDown = _checkIfRequiresRoundDown(balanceAsNumber);

        require(requiresRoundDown, "Not eligible for round down");

        // Round down if required
        uint256 roundedBalanceAsNumber = _roundDownToNearestMultiple(
            balanceAsNumber
        );

        // Convert the rounded balance back to a uint256 with 18 decimals
        uint256 roundedBalance = roundedBalanceAsNumber * 10 ** 18;

        //Calculate remainder
        remainder = balance - roundedBalance;

        return remainder;
    }

    function checkIfRequiresRoundDown(
        uint256 balance
    ) internal pure returns (bool) {
        return balance % 10 ** 18 != 0;
    }

    // Function to round down to the nearest multiple of 10 (18 decimals)
    function _roundDownToNearestMultiple(
        uint256 balance
    ) internal pure returns (uint256) {
        // Calculate the appropriate base //hardcoded
        // uint256 base = balance < 100 ? 10 : balance < 99999 ? 10000 : 100;
        uint256 base = balance > 99999 ? 10000 : (balance < 100 ? 10 : 100);

        // Round down to the nearest multiple of the base
        return (balance / base) * base;
    }

    function _checkIfRequiresRoundDown(
        uint256 balance
    ) internal pure returns (bool) {
        // Check if balance is not a multiple of 10 (18 decimals) TODO: not only fullstop
        return balance % 10 ** 18 != 0;
    }

    function _bytesToUint(bytes memory data) public pure returns (uint256) {
        require(data.length >= 32, "Invalid data length");

        uint256 result;
        assembly {
            result := mload(add(data, 32))
        }
        return result;
    }
}
