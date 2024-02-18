// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./helpers/IStrategy.sol";

contract Pennypot is AccessControl {
    uint256 private constant DECIMALS = 18;
    uint256 public clonesCounter;

    // SafeLock, Flexi, Target, yield etc;
    address[] public PennyStrategies;

    //Set Penny Strategy
    mapping(address => bool) public isPennyStrategy;

    //Set Cloned Strategy
    mapping(address => bool) public isClonedStrategy;

    // Users pots by Penny strategies {userAddress => PennyStrategyHash => pots[]}
    mapping(address => mapping(bytes32 => address[])) public potsByStrategies;

    // Users pots by tokens {userAddress => (tokenAddress => pennyAddress)}
    mapping(address => mapping(address => address)) public potsByTokens;

    // Event emitted when a user opts in to the strategyƒ
    event OptIn(address indexed user, address token, address indexed strategy);

    //  Emit Event when a user deposits tokens
    event Deposit(
        address indexed pot,
        address indexed token,
        address indexed provider,
        uint256 amount
    );

    modifier onlyAdmin(address pot, address sender) {
        _checkOnlyAdmin(pot, sender);
        _;
    }

    // Create  Savings Quest
    function create(address pennyStrategy, address[] memory tokens) external {
        require(_isPennyStrategy(pennyStrategy), "Invalid strategy");

        bytes32 pennyStrategyHash = keccak256(abi.encodePacked(pennyStrategy));

        // Clone  strategy for participants
        address pot = _cloneStrategy(pennyStrategy);
        isClonedStrategy[pot] = true;

        require(pot != address(0), "invalid pot");

        //Whitelist tokens
        IStrategy(pot).initialize(tokens);

        // // record the user's new strategy
        potsByStrategies[msg.sender][pennyStrategyHash].push(pot);

        bytes32 Admin_ROLE = keccak256(abi.encodePacked(pot, "admin"));
        _grantRole(Admin_ROLE, msg.sender);
    }

    // Optin a token to a Savings Quest
    function optIn(
        address pot,
        address token,
        uint256 lockPeriod
    ) external onlyAdmin(pot, msg.sender) {
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
        require(!_isActive(pot, token), "token already opted in");

        //opt in token
        IStrategy(pot).optIn(token, lockPeriod);

        //add pot record to users token
        potsByTokens[msg.sender][token] = pot;

        // Emit event
        emit OptIn(msg.sender, token, pot);
    }

    // Checks if a remittance is due
    function checkUpkeep(
        address token,
        address sender
    ) external view returns (bool upkeepNeeded) {
        address pot = potsByTokens[sender][token];

        if (pot == address(0)) {
            //return if no pot is found
            return false;
        }
        uint256 userBalance = ERC20(token).balanceOf(sender);

        (bool isActive, uint256 unlockTimestamp) = IStrategy(pot)
            .getTokenDetails(token);

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

    // filter user's pot by the Penny strategies they implement
    function getPotsByStrategies(
        address pennyStrategy
    ) external view returns (address[] memory) {
        bytes32 PennyStrategyHash = keccak256(abi.encodePacked(pennyStrategy));
        return potsByStrategies[msg.sender][PennyStrategyHash];
    }

    // Get token's  active savings pot
    function getPotsByToken(address token) external view returns (address) {
        return potsByTokens[msg.sender][token];
    }

    // Add a new Penny Strategy to contract
    function setPennyStrategy(address strategy) external {
        require(!_isPennyStrategy(strategy), "Already a Penny Strategy");
        isPennyStrategy[strategy] = true;
        PennyStrategies.push(strategy);
    }

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

    function _isActive(
        address pot,
        address token
    ) internal view returns (bool) {
        (bool isActive, ) = IStrategy(pot).getTokenDetails(token);
        return isActive;
    }

    function _checkOnlyAdmin(address pot, address sender) internal view {
        if (!_isPotAdmin(pot, sender)) revert("UNAUTHORIZED");
    }

    function _isPotAdmin(
        address pot,
        address _address
    ) internal view returns (bool) {
        bytes32 Admin_ROLE = keccak256(abi.encodePacked(pot, "admin"));
        return hasRole(Admin_ROLE, _address);
    }

    function _checkIfRequiresRoundDown(
        uint256 balance
    ) internal pure returns (bool) {
        // Check if balance is not a multiple of 10 (18 decimals) TODO: not only fullstop
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

    function _roundDownERC20Balance(
        address token,
        address sender
    ) internal view returns (uint256 remainder) {
        // Get ERC20 token contract
        ERC20 erc20 = ERC20(
            address(token) //0x3b70652cB79780cA1bf60a8b34cc589BbeDc00B2
        );

        // Get the balance of the sender in the ERC20 token
        uint256 balance = erc20.balanceOf(sender);

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

    function _bytesToUint(bytes memory data) public pure returns (uint256) {
        require(data.length >= 32, "Invalid data length");

        uint256 result;
        assembly {
            result := mload(add(data, 32))
        }
        return result;
    }
}
