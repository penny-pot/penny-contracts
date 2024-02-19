### PennyPot Contracts

| Contract Name            | Description                                                                                                                                                                                                                    |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `PennyPot.sol`           | Manages the core of PennyPot protocol. Allows users to create savings quests, opt-in their tokens, and functions for checking upkeep and performing remittances into savings pots.                                             |
| `RoundDown.sol`          | Provides functions for rounding down token balances to the nearest multiple of 10. The remaining fractions would be remitted for savings.                                                                                      |
| `PennyAccessControl.sol` | Manages access control within the PennyPot system. Defines roles such as admin and member, which control users' abilities to create quests, opt-in tokens, and perform other actions.                                          |
| `PennyStrategy.sol`      | Manages the creation and cloning of savings strategies. Provides functions for setting up and configuring different types of strategies for savings quests. Example is the simple safelock strategy.                           |
| `CrossChainBalance.sol`  | Interacts with Chainlink to access token balance from Covalent. Allows PennyPot to retrieve balance information on the Avalanche base network irrespective of token type or chain, use it for checking and performing upkeeps. |

### Chainlink and Covalent on Avalanche chain:

PennyPot uses Chainlink Functions and Automation to track changes in a user's token balance and perform upkeep on chain.

- `Pennypot.sol` registers a request when a token has been opted in for an active savings quest.

- By querying with Covalent's Unified API with the periodic Chainlink Functions request, `CrossChainBalance.sol` can monitor balances of opted-in tokens for cross-chain remittance.
