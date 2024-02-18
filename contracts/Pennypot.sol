// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IStrategy.sol";
import "./interfaces/ICrossChainBalance.sol";
import "./helpers/RoundDown.sol";
import "./helpers/PennyAccessControl.sol";
import "./helpers/PennyStrategy.sol";

contract Pennypot is RoundDown, PennyAccessControl, PennyStrategy {
    uint256 private constant DECIMALS = 18;

    //supported chains
    enum Chains {
        Default,
        Sepolia
    }

    mapping(address => mapping(uint256 => address)) public equivalentTokens;

    // Quest Creators pots filtered by savings strategies
    mapping(address => mapping(bytes32 => address[])) public potsByStrategies;

    // Penny Savers pots filtered by tokens
    mapping(address => mapping(address => address)) public potsByTokens;

    // Emit when a user opts in a token to a quest
    event OptIn(address indexed user, address token, address indexed strategy);

    //  Emit when a user deposits tokens into a pot
    event Deposit(
        address indexed pot,
        address indexed token,
        address indexed provider,
        uint256 amount
    );

    // Create  Savings Quest
    function create(
        address pennyStrategy,
        uint256 _lockPeriod,
        address[] memory members,
        address[] memory tokens
    ) external {
        require(_isPennyStrategy(pennyStrategy), "Invalid strategy");
        bytes32 pennyStrategyHash = keccak256(abi.encodePacked(pennyStrategy));

        // Clone  strategy for participants
        address pot = _cloneStrategy(pennyStrategy);
        isClonedStrategy[pot] = true;

        require(pot != address(0), "invalid pot");

        bytes32 Admin_ROLE = keccak256(abi.encodePacked(pot, "admin"));
        bytes32 Member_ROLE = keccak256(abi.encodePacked(pot, "member"));

        //Whitelist tokens and users
        IStrategy(pot).initialize(
            tokens,
            Member_ROLE,
            Member_ROLE,
            _lockPeriod
        );

        // // record the creator's new strategy
        potsByStrategies[msg.sender][pennyStrategyHash].push(pot);

        _grantRole(Admin_ROLE, msg.sender);

        for (uint256 i = 0; i < members.length; i++) {
            _grantRole(Member_ROLE, members[i]);
        }
    }

    // Optin a token to a Savings Quest
    function optIn(
        address pot,
        address token,
        uint256 lockPeriod,
        bytes memory _request,
        address consumer
    ) external onlyMemberOrAdmin(pot, msg.sender) {
        require(
            _isClonedStrategy(pot),
            "pot does not implement a Penny's savings strategy"
        );

        // Check that token is permitted in pot
        require(
            IStrategy(pot).isWhiteListed(token),
            "token is not allowed in pot"
        );

        // Check that token is not opted in for savings
        require(!_isActive(pot, token, msg.sender), "token already opted in");

        //Register Request to BalanceConsumer Contract
        ICrossChainBalance(consumer).updateRequest(_request);

        uint256 serialnumber = ICrossChainBalance(consumer)
            .getLatestSerialNumber();

        //opt in token
        IStrategy(pot).optIn(token, serialnumber, msg.sender);

        //add pot record to users token
        potsByTokens[msg.sender][token] = pot;

        // Emit event
        emit OptIn(msg.sender, token, pot);
    }

    // Checks if a remittance is due
    function checkUpkeep(
        address token,
        address sender,
        address consumer
    ) external view returns (bool upkeepNeeded) {
        address pot = potsByTokens[sender][token];

        if (pot == address(0)) {
            //return if no pot is found
            return false;
        }

        (
            bool isActive,
            uint256 unlockTimestamp,
            uint256 userShares,
            uint256 userSerialNumber
        ) = IStrategy(pot).getTokenDetails(token, sender);

        //check from the cross chain contract instead
        uint256 userBalance = ICrossChainBalance(consumer).getBalance(
            userSerialNumber
        );
        upkeepNeeded =
            isActive &&
            block.timestamp < unlockTimestamp &&
            _checkIfRequiresRoundDown(userBalance);
    }

    // Perfom remittance to savings pot///
    function performUpKeep(address token, address sender) external {
        //retrieve pot
        address pot = potsByTokens[sender][token];
        require(pot != address(0), "invalid pot");

        //calculate rounddown
        uint256 amount = _roundDownERC20Balance(token, sender);
        require(amount > 0, "zero or invalid deposit amount");

        //deposit into pot
        IStrategy(pot).deposit(token, amount, sender);

        emit Deposit(pot, token, sender, amount);
    }

    // filter a creator's pots by the Savings strategies they implement
    function getPotsByStrategies(
        address pennyStrategy
    ) external view returns (address[] memory) {
        bytes32 PennyStrategyHash = keccak256(abi.encodePacked(pennyStrategy));
        return potsByStrategies[msg.sender][PennyStrategyHash];
    }

    // Get token's  active savings pot
    function getPotsByToken(
        address token,
        address user
    ) external view returns (address) {
        return potsByTokens[user][token];
    }

    function _isActive(
        address pot,
        address token,
        address user
    ) internal view returns (bool) {
        (
            bool isActive,
            uint256 unlockTimestamp,
            uint256 userShares,
            uint256 userSerialNumber
        ) = IStrategy(pot).getTokenDetails(token, user);
        return isActive;
    }

    // Set crosschain equivalent for a token. TODO: Restrict
    function setEquivalentToken(
        address mainToken,
        address equivalentToken,
        Chains chain
    ) external {
        equivalentTokens[mainToken][uint256(chain)] = equivalentToken;
    }

    // Check crosschain token on the specified chain
    function checkEquivalentToken(
        address mainToken,
        Chains chain
    ) external view returns (address) {
        return equivalentTokens[mainToken][uint256(chain)];
    }
}
