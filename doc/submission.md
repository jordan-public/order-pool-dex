# About the project

## Inspiration
Trying to build a more capital-efficient and fair Decentralized Exchange (DEX).

Problems:
- **Liquidity Pool** AMMs require sizable capital locked and are susceptible to slippage and Minter Extracted Value (MEV) attacks / abuse.
- **Order Book** exchanges require expensive repetitive updating of the bids and offers and are not suitable for on-chain implementation.

## What it does
**Order Pool DEX** allows the users to exchange one fungible asset for another.
The new concept of **Order Pool** allows gas-efficient order management and execution. It does not require sizable capital deposit and it uses ChainLink for price discovery thus becoming immune to MEV abuse.

If a counter-party pool is not empty, the order executes as "taker", otherwise the order is pooled and it becomes a "maker". Upon execution, the maker pays the taker a small fee (0.25%) and to the protocol another 0.05%. 

## How we built it
For each pair of assets, all "buy" orders are lumped in a single pool, and the "sell" orders in another one. ChainLink is used for price discovery, so there is no slippage or MEV influence on the price. Each new seller draws counter-party assets from the Sell pool and vice versa.

## Challenges we ran into
The main challenge was to create efficient data structures to allow for fair execution order, as well as efficient constant on-chain execution (gas) cost, even when large orders execute against multiple small orders.

## Accomplishments that we're proud of
Each Order Pool is implemented as a list in order of arrival, which can be cut to size as counter-party orders require. Each order in this list is enumerated in order of arrival. Once a counter-party order executes against potentially multiple elements in the list, the order id range and the execution price is recorded in a separate list. Upon withdrawal the range list is traversed off-chain (in a read-only manner) to find the appropriate entry, so that the on-chain withdrawal process only verifies that the order ID is in the supplied range and uses the price to determine the amount to withdraw.

This achieves constant gas cost for each order entry and withdrawal regardless of the pool size and how many counter-parties the order executed against.

## What we learned
How to use and integrate ChainLink into decentralized applications. Also learned about the Foundry tool set.

## What's next for Order Pool DEX
Implementation of Epochs to facilitate order cancellations.

# Built with
The Smart Contracts are written in Solidity composing with the ChainLink Price Feed Oracle contracts. 

The front end is written in JavaScript using React and Ethers.js. 

For testing and deployment, the Foundry tool set is used.