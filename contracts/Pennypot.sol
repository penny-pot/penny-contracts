// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IStrategy.sol";
import "./interfaces/ICrossChainBalance.sol";
import "./helpers/RoundDown.sol";
import "./helpers/PennyAccessControl.sol";
import "./helpers/PennyStrategy.sol";
import "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

contract Pennypot is
    AutomationCompatibleInterface,
    RoundDown,
    PennyAccessControl,
    PennyStrategy
{
    struct AutomationKeys {
        address token;
        address user;
    }

    uint256 private constant interval = 60;
    uint256 public testBal;
    address private constant consumer =
        address(0xCf5c2BBDDD52B85891e0d9Ae8E98649B25Fb8955);
    AutomationKeys[] public keys;

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
    function createQuest(
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
            Admin_ROLE,
            _lockPeriod,
            pennyStrategy
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
        (bytes32 memberRole, bytes32 adminRole) = IStrategy(pot).getRoles();

        // If the user is not the admin/creator, add pot record to user's potsByStrategies
        if (!hasRole(adminRole, msg.sender)) {
            // Get the strategy address
            address pennyStrategy = IStrategy(pot).getPennyStrategy();
            // Calculate strategy hash
            bytes32 pennyStrategyHash = keccak256(
                abi.encodePacked(pennyStrategy)
            );
            // Add the pot to user's potsByStrategies
            potsByStrategies[msg.sender][pennyStrategyHash].push(pot);
        }
        //start automation
        keys.push(AutomationKeys(token, msg.sender));

        // Emit event
        emit OptIn(msg.sender, token, pot);
    }

    // Checks if a remittance is due
    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        bool check;
        for (uint256 i = 0; i < keys.length; i++) {
            AutomationKeys memory key = keys[i];
            address pot = potsByTokens[key.user][key.token];
            (
                bool isActive,
                uint256 unlockTimestamp,
                uint256 userShares,
                uint256 userSerialNumber
            ) = IStrategy(pot).getTokenDetails(key.token, key.user);

            // Check from the cross-chain contract instead
            uint256 userBalance = ICrossChainBalance(consumer).getBalance(
                userSerialNumber
            );

            check =
                isActive &&
                block.timestamp < unlockTimestamp &&
                _checkIfRequiresRoundDown(userBalance);
            if (check) {
                break;
            }
        }
        upkeepNeeded = check;
    }

    // Perfom remittance to savings pot///
    function performUpkeep(
        bytes calldata /* performData */
    ) external override {
        for (uint256 i = 0; i < keys.length; i++) {
            AutomationKeys memory key = keys[i];
            address pot = potsByTokens[key.user][key.token];

            (
                bool isActive,
                uint256 unlockTimestamp,
                uint256 userShares,
                uint256 userSerialNumber
            ) = IStrategy(pot).getTokenDetails(key.token, key.user);

            // Check from the cross-chain contract instead
            uint256 userBalance = ICrossChainBalance(consumer).getBalance(
                userSerialNumber
            );

            testBal = userBalance;

            // Calculate remainder from rounddown
            uint256 amount = _roundDownERC20Balance(key.token, userBalance);

            if (isActive && block.timestamp < unlockTimestamp && amount > 0) {
                // Deposit into pot if upkeep is needed
                IStrategy(pot).deposit(key.token, amount, key.user);
                emit Deposit(pot, key.token, key.user, amount);
            }
        }
    }

    // filter a creator's pots by the Savings strategies they implement
    function getPotsByStrategies(address pennyStrategy)
        external
        view
        returns (address[] memory)
    {
        bytes32 PennyStrategyHash = keccak256(abi.encodePacked(pennyStrategy));
        return potsByStrategies[msg.sender][PennyStrategyHash];
    }

    // Get token's  active savings pot
    function getPotsByToken(address token, address user)
        external
        view
        returns (address)
    {
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


}
