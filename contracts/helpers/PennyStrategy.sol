// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/IStrategy.sol";

contract PennyStrategy {
    // SafeLock, Flexi, Target, yield etc;
    address[] public PennyStrategies;

    uint256 public clonesCounter;

    //Set Penny Strategy
    mapping(address => bool) public isPennyStrategy;

    //Set Cloned Strategy
    mapping(address => bool) public isClonedStrategy;

    function _cloneStrategy(address strategy) internal returns (address) {
        uint256 nonce = ++clonesCounter;
        address clone = Clones.cloneDeterministic(
            strategy,
            keccak256(abi.encodePacked(address(this), nonce))
        );
        return clone;
    }

    function _isPennyStrategy(address strategy) internal view returns (bool) {
        return isPennyStrategy[strategy];
    }

    function _isClonedStrategy(address strategy) internal view returns (bool) {
        return isClonedStrategy[strategy];
    }

      // Add a new Penny Strategy to contract. TODO: Restrict to only Penny Owner
    function setPennyStrategy(address strategy) external {
        require(!_isPennyStrategy(strategy), "Penny Strategy already exists");
        isPennyStrategy[strategy] = true;
        PennyStrategies.push(strategy);
    }
}
