// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../interfaces/IStrategy.sol";

contract SafeLock is Initializable, IStrategy {
    bytes32 public memberRole;
    bytes32 public adminRole;
    uint256 public unlockTimestamp;
    address public pennyStrategy;

    //address of  pennypot
    address constant _PENNYPOT =
        address(0xE64bC8B0aE893dDE5E2a5268ddde2bb79BE0c80b);

    // Token whitelisted for savings
    struct TokenWhitelist {
        address[] liquidityProviders;
        mapping(address => uint256) shares;
        mapping(address => bool) isActive;
        mapping(address => uint256) serialNumber;
    }

    // Addresses of whitelisted tokens by Admin
    address[] public whitelistedTokens;

    // A user's optedIn tokens
    mapping(address => address[]) optedInTokens;
    mapping(address => TokenWhitelist) private tokenWhitelist;

    // Emit Event when a token is whitelisted
    event TokenWhitelisted(address indexed token);

    modifier onlyCore() {
        require(msg.sender == _PENNYPOT, "Caller is not the core address");
        _;
    }

    function initialize(
        address[] memory _whitelist,
        bytes32 _memberRole,
        bytes32 _adminRole,
        uint256 _lockPeriod,
        address _strategy
    ) external onlyCore {
        for (uint256 i = 0; i < _whitelist.length; i++) {
            whitelistedTokens.push(_whitelist[i]);
        }
        memberRole = _memberRole;
        adminRole = _adminRole;
        unlockTimestamp = block.timestamp + _lockPeriod;
        pennyStrategy = _strategy;
    }

    // Opt in a token for a savings period
    function optIn(
        address token,
        uint256 serialNumber,
        address user
    ) external onlyCore {
        require(
            !tokenWhitelist[token].isActive[user],
            "Token is aleady active"
        );
        tokenWhitelist[token].isActive[user] = true;
        tokenWhitelist[token].serialNumber[user] = serialNumber;
        //I was supposed to push liquidity providers here
    }

    // Deposit tokens into the safe lock
    function deposit(
        address token,
        uint256 amount,
        address sender
    ) external onlyCore {
        require(
            tokenWhitelist[token].isActive[sender],
            "drips paused or not active"
        );
        require(
            IERC20(token).transferFrom(sender, address(this), amount),
            "Transfer failed"
        );
        address[] storage providers = tokenWhitelist[token].liquidityProviders;
        bool isProvider = false;
        for (uint256 i = 0; i < providers.length; i++) {
            if (providers[i] == sender) {
                isProvider = true;
                break;
            }
        }
        if (!isProvider) {
            providers.push(sender);
        }
        tokenWhitelist[token].shares[sender] += amount;
    }

    // Whitelist a token
    function whitelist(address token) external onlyCore {
        require(!_isWhiteListed(token), "Token already whitelisted");
        whitelistedTokens.push(token);
        emit TokenWhitelisted(token);
    }

    // Withdraw amount NOTE: Shareholder has to interact directly with contract to withdraw, not through penny
    function withdraw(
        address token,
        address receiver,
        uint256 amount
    ) external {
        //liquidity shareholder/provider can withdraw
        require(
            tokenWhitelist[token].shares[msg.sender] <= amount,
            "Invalid Shares"
        );
        //withdrawal allowed only at eligible time
        require(unlockTimestamp < block.timestamp, "Lock period is not over");

        //transfer token from contract to user
        IERC20(token).transferFrom(address(this), receiver, amount);

        //update user's share
        tokenWhitelist[token].shares[msg.sender] -= amount;
    }

    // Get Token Details, whitelisted, Active and Unlock timestamp
    function getTokenDetails(
        address token,
        address user
    )
        external
        view
        returns (
            bool isActive,
            uint256 _unlockTimestamp,
            uint256 userShares,
            uint256 userSerialNumber
        )
    {
        TokenWhitelist storage tokenDetails = tokenWhitelist[token];

        // Check if the user is a liquidity provider for this token
        uint256 index;
        bool found = false;
        for (uint256 i = 0; i < tokenDetails.liquidityProviders.length; i++) {
            if (tokenDetails.liquidityProviders[i] == user) {
                index = i;
                found = true;
                break;
            }
        }
        if (found) {
            // Get the user's shares
            userShares = tokenDetails.shares[user];
            // Get the user's active status
            isActive = tokenDetails.isActive[user];
            // Get the user's serial number
            userSerialNumber = tokenDetails.serialNumber[user];
        } else {
            // User is not a liquidity provider for this token
            userShares = 0;
            isActive = tokenDetails.isActive[user];
            userSerialNumber = tokenDetails.serialNumber[user];
        }
        return (isActive, unlockTimestamp, userShares, userSerialNumber);
    }

    // Get token liquidity providers and their shares
    function getShareholders(
        address token
    ) external view returns (address[] memory, uint256[] memory) {
        TokenWhitelist storage tokenDetails = tokenWhitelist[token];
        address[] memory holders = new address[](
            tokenDetails.liquidityProviders.length
        );
        uint256[] memory shares = new uint256[](
            tokenDetails.liquidityProviders.length
        );

        for (uint256 i = 0; i < tokenDetails.liquidityProviders.length; i++) {
            address holder = tokenDetails.liquidityProviders[i];
            uint256 _share = tokenDetails.shares[holder];
            shares[i] = _share;
            holders[i] = holder;
        }
        return (holders, shares);
    }

    // Get all whitelisted tokens
    function getWhitelistedTokens() external view returns (address[] memory) {
        return whitelistedTokens;
    }

    // Get Penny Strategy for the contract
    function getPennyStrategy() external view returns (address) {
        return pennyStrategy;
    }

    function getRoles() external view returns (bytes32, bytes32) {
        return (memberRole, adminRole);
    }

    // Check if token is whitelisted
    function isWhiteListed(address token) external view returns (bool) {
        return _isWhiteListed(token);
    }

    function _isWhiteListed(address token) internal view returns (bool) {
        for (uint256 i = 0; i < whitelistedTokens.length; i++) {
            if (whitelistedTokens[i] == token) {
                return true;
            }
        }
        return false;
    }
}
