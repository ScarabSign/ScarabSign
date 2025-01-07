# 🪲 ScarabSign

A Starknet hyperstructure for peer-to-peer signature aggregation in decentralized auctions.

## Overview

ScarabSign is inspired by the sacred scarab beetles of ancient Egypt, who rolled spheres of material that grew larger as they moved forward. Similarly, ScarabSign rolls forward accumulating signatures in a P2P fashion, leveraging Starknet's unique capabilities and the homomorphic properties of Pedersen hash.

## Technical Features

- **Homomorphic Signature Aggregation**: Utilizes Pedersen hash properties for efficient signature combining
- **P2P Signature Snowballing**: Enables off-chain bid collection and aggregation
- **Gas-Efficient Settlement**: Single on-chain transaction for auction settlement
- **Starknet Native Integration**: Built from ground up for Starknet's unique capabilities

## Core Components

### 1. Auction Creation
```cairo
struct Auction {
    auctioneer: felt
    nft_contract: felt
    token_contract: felt
    bid_start: felt
    deadline: felt
    aggregated_signature: felt
}
```

### 2. Bid Collection
- Off-chain signature accumulation
- Pedersen-based signature verification
- Automatic bid ordering through homomorphic properties

### 3. Settlement
- Single transaction auction settlement
- Automated winner selection
- Instant asset transfer

## Getting Started

[Coming Soon]

## Security Considerations

- Pedersen collision resistance
- Signature verification process
- Timestamp manipulation prevention
- Front-running protection

## Contributing

We welcome contributions! Please check our [Contributing Guidelines](CONTRIBUTING.md) for details.

## License

MIT
