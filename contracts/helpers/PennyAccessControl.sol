// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract PennyAccessControl is AccessControl {
    modifier onlyAdmin(address pot, address sender) {
        _checkOnlyAdmin(pot, sender);
        _;
    }

    modifier onlyMemberOrAdmin(address pot, address sender) {
        _checkOnlyAllowed(pot, sender);
        _;
    }

    //assign a role to a user eg invite user to join savings quest
    function assignRole(
        address pot,
        address user
    ) external onlyAdmin(pot, msg.sender) {
        bytes32 role = keccak256(abi.encodePacked(pot, "member"));
        //check user doesn't already have this role
        require(!hasRole(role, user), "user already permitted");
        _grantRole(role, user);
    }

    function _checkOnlyAdmin(address pot, address sender) internal view {
        if (!_isPotAdmin(pot, sender)) revert("UNAUTHORIZED");
    }

    function _checkOnlyAllowed(address pot, address sender) internal view {
        require(
            _isPotAdmin(pot, sender) || _isPotAllowed(pot, sender),
            "UNAUTHORIZED"
        );
    }

    function _isPotAdmin(
        address pot,
        address _address
    ) internal view returns (bool) {
        bytes32 Admin_ROLE = keccak256(abi.encodePacked(pot, "admin"));
        return hasRole(Admin_ROLE, _address);
    }

    function _isPotAllowed(
        address pot,
        address _address
    ) internal view returns (bool) {
        bytes32 Member_ROLE = keccak256(abi.encodePacked(pot, "member"));
        return hasRole(Member_ROLE, _address);
    }
}
