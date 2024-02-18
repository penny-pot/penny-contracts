// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
// import "../interfaces/IStrategy.sol";

// contract Target is Initializable, IStrategy {
//     bytes32 public memberRole;
//     bytes32 public adminRole;

//     //address of  pennypot
//     address constant _PENNYPOT =
//         address(0x66EC7F74D59214560DE1b0CaD2527d2b2a998FC4);

//     // Token whitelisted for savings
//     struct TokenWhitelist {
//         bool isActive;
//         uint256 targetAmount;
//         uint256 totalDeposited;
//         address[] liquidityProviders;
//         mapping(address => uint256) shares;
//     }

//     // Addresses of whitelisted tokens
//     address[] public whitelistedTokens; //this is what we'll populate the first time

//     //  ERC-20 tokens to their whitelist status
//     mapping(address => TokenWhitelist) public tokenWhitelist;

//     // Emit Event when a token is whitelisted
//     event TokenWhitelisted(address indexed token);

//     modifier onlyCore() {
//         require(msg.sender == _PENNYPOT, "Caller is not the core address");
//         _;
//     }

//     function initialize(
//         address[] memory _whitelist,
//         bytes32 _memberRole,
//         bytes32 _adminRole
//     ) external onlyCore {
//         for (uint256 i = 0; i < _whitelist.length; i++) {
//             whitelistedTokens.push(_whitelist[i]);
//         }

//         memberRole = _memberRole;
//         adminRole = _adminRole;
//     }

//     // Opt in a token for a savings period
//     function optIn(address token, uint256 targetAmount) external onlyCore {
//         require(!tokenWhitelist[token].isActive, "Token is already active");
//         tokenWhitelist[token].isActive = true;
//         tokenWhitelist[token].targetAmount = targetAmount;
//     }

//     // Deposit tokens into the safe lock
//     function deposit(
//         address token,
//         uint256 amount,
//         address sender
//     ) external onlyCore {
//         require(_isWhiteListed(token), "Token is not whitelisted");
//         require(tokenWhitelist[token].isActive, "Token drips paused");
//         require(
//             IERC20(token).transferFrom(sender, address(this), amount),
//             "Transfer failed"
//         );
//         // Record the deposit
//         tokenWhitelist[token].shares[msg.sender] += amount;
//         tokenWhitelist[token].liquidityProviders.push(msg.sender);
//         tokenWhitelist[token].totalDeposited += amount;

//         if (
//             tokenWhitelist[token].totalDeposited >=
//             tokenWhitelist[token].targetAmount
//         ) {
//             //close out savings
//             tokenWhitelist[token].isActive = false;
//         }
//     }

//     // Whitelist a token
//     function whitelist(address token) external onlyCore {
//         require(!_isWhiteListed(token), "Token already whitelisted");
//         whitelistedTokens.push(token);
//         emit TokenWhitelisted(token);
//     }

//     // Withdraw amount NOTE: Shareholder has to interact directly with contract to withdraw, not through penny
//     function withdraw(
//         address token,
//         address receiver,
//         uint256 amount
//     ) external {
//         //liquidity shareholder/provider can withdraw
//         require(
//             tokenWhitelist[token].shares[msg.sender] <= amount,
//             "Invalid Shares"
//         );

//         //transfer token from contract to user
//         IERC20(token).transferFrom(address(this), receiver, amount);

//         //update user's share
//         tokenWhitelist[token].shares[msg.sender] -= amount;

//         //check if remaining shares is zero
//         if (areAllSharesZero(token)) {
//             tokenWhitelist[token].targetAmount = 0;
//             tokenWhitelist[token].totalDeposited = 0;
//             tokenWhitelist[token].isActive = false;
//         }
//     }

//     // Get Token Details, whitelisted, Active and Unlock timestamp
//     function getTokenDetails(
//         address token
//     ) external view returns (bool isActive, uint256 targetAmount) {
//         TokenWhitelist storage tokenDetails = tokenWhitelist[token];
//         isActive = tokenDetails.isActive;
//         targetAmount = tokenDetails.targetAmount;
//         return (isActive, targetAmount);
//     }

//     // Get token liquidity providers and their shares
//     function getShareholders(
//         address token
//     ) external view returns (address[] memory, uint256[] memory) {
//         TokenWhitelist storage tokenDetails = tokenWhitelist[token];
//         address[] memory holders = new address[](
//             tokenDetails.liquidityProviders.length
//         );
//         uint256[] memory shares = new uint256[](
//             tokenDetails.liquidityProviders.length
//         );

//         for (uint256 i = 0; i < tokenDetails.liquidityProviders.length; i++) {
//             address holder = tokenDetails.liquidityProviders[i];
//             uint256 _share = tokenDetails.shares[holder];
//             shares[i] = _share;
//             holders[i] = holder;
//         }
//         return (holders, shares);
//     }

//     // Get all whitelisted tokens
//     function getWhitelistedTokens() external view returns (address[] memory) {
//         return whitelistedTokens;
//     }

//     // Check if token is whitelisted
//     function isWhiteListed(address token) external view returns (bool) {
//         return _isWhiteListed(token);
//     }

//     function _isWhiteListed(address token) internal view returns (bool) {
//         for (uint256 i = 0; i < whitelistedTokens.length; i++) {
//             if (whitelistedTokens[i] == token) {
//                 return true;
//             }
//         }
//         return false;
//     }

//     function areAllSharesZero(address token) internal view returns (bool) {
//         address[] memory liquidityProviders = tokenWhitelist[token]
//             .liquidityProviders;
//         mapping(address => uint256) storage shares = tokenWhitelist[token]
//             .shares;
//         for (uint256 i = 0; i < liquidityProviders.length; i++) {
//             if (shares[liquidityProviders[i]] != 0) {
//                 return false;
//             }
//         }
//         return true;
//     }
// }
