// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../helpers/IStrategy.sol";

contract SafeLock is Initializable, IStrategy {
    //address of  pennypot
    address constant _PENNYPOT =
        address(0xc4a1D0485C0C7e465c56aE8d951bdCd861f40Cd5);

    // Token whitelisted for savings
    struct TokenWhitelist {
        bool isActive;
        uint256 unlockTimestamp;
        address[] liquidityProviders;
        mapping(address => uint256) shares;
    }

    // Addresses of whitelisted tokens
    address[] public whitelistedTokens; //this is what we'll populate the first time

    //  ERC-20 tokens to their whitelist status
    mapping(address => TokenWhitelist) public tokenWhitelist;

    // Emit Event when a token is whitelisted
    event TokenWhitelisted(address indexed token);

    modifier onlyCore() {
        require(msg.sender == _PENNYPOT, "Caller is not the core address");
        _;
    }

    function initialize(address[] memory _whitelist) external onlyCore {
        for (uint256 i = 0; i < _whitelist.length; i++) {
            whitelistedTokens.push(_whitelist[i]);
        }
    }

    // Opt in a token for a savings period
    function optIn(address token, uint256 _lockPeriod) external onlyCore {
        require(!tokenWhitelist[token].isActive, "Token is aleady active");
        tokenWhitelist[token].isActive = true;
        tokenWhitelist[token].unlockTimestamp = block.timestamp + _lockPeriod;
    }

    // Deposit tokens into the safe lock
    function deposit(
        address token,
        uint256 amount,
        address sender
    ) external onlyCore {
        require(_isWhiteListed(token), "Token is not whitelisted");
        require(tokenWhitelist[token].isActive, "Token drips paused");
        require(
            IERC20(token).transferFrom(sender, address(this), amount),
            "Transfer failed"
        );
        // Record the deposit
        tokenWhitelist[token].shares[msg.sender] += amount;
        tokenWhitelist[token].liquidityProviders.push(msg.sender);
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
        require(
            tokenWhitelist[token].unlockTimestamp < block.timestamp,
            "Lock period is not over"
        );

        //transfer token from contract to user
        IERC20(token).transferFrom(address(this), receiver, amount);

        //update user's share
        tokenWhitelist[token].shares[msg.sender] -= amount;
    }

    // Get Token Details, whitelisted, Active and Unlock timestamp
    function getTokenDetails(
        address token
    ) external view returns (bool isActive, uint256 unlockTimestamp) {
        TokenWhitelist storage tokenDetails = tokenWhitelist[token];
        isActive = tokenDetails.isActive;
        unlockTimestamp = tokenDetails.unlockTimestamp;
        return (isActive, unlockTimestamp);
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
