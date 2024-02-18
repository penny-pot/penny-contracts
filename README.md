### PennyPot Contracts

#### Summary:
The PennyPot contracts aim to facilitate savings strategies by allowing users to participate in savings quests and opt-in their tokens.

**PennyPot.sol**: This contract manages the core functionality of the PennyPot system. It allows users to create savings quests, opt-in their tokens, and deposit funds into pots. It also provides functions for checking upkeep and performing remittances.

**RoundDown.sol**: A helper contract that provides functions for rounding down token balances to the nearest multiple of 10.

**PennyAccessControl.sol**: This contract manages access control within the PennyPot system. It defines roles such as admin and member, which control users' abilities to create quests, opt-in tokens, and perform other actions.

**PennyStrategy.sol**: The PennyStrategy contract manages the creation and cloning of savings strategies. It provides functions for setting up and configuring different types of strategies for savings quests.

**CrossChainBalance.sol**: This contract interacts with Chainlink to access cross-chain balance data. It allows the PennyPot system to retrieve balance information from other chains and use it for various purposes, such as performing remittances.

#### Chainlink and Covalent Integration:
The PennyPot system leverages Chainlink Functions and Covalent's Unified API to access user's token balance data securely. Here's how it works:

1. **Chainlink Integration**: The `CrossChainBalance.sol` contract sends a request to Covalent API via Chainlink Functions to balance of a user's opted in token, and it stores the balance on chain.


2. **Automated Balance Updates**: The PennyPot system is designed to automatically update this balance data at intervals (e.g., every 15 minutes) using Chainlink's Function's Automation. This ensures that users' balance information remains up-to-date for remittances and other actions.

4. **Cross-Chain Compatibility**: By integrating with Covalent's Unified API and  Chainlink's Functions Automation and CCIP, PennyPot contracts supports interoperability on Sepolia. Users can opt-in tokens on for cross-chain remittance and still track their balances from Avalanche using Covalent's API.

