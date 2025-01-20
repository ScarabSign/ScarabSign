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

### Prerequisites
- Scarb
- snforge
- sncast
- Starknet account with testnet ETH

### Setup and Testing

1. Clone the repository and set up environment:
```bash
git clone https://github.com/your-org/scarab-sign.git
cd scarab-sign
cp .env.example .env
source .env
```

2. Run the test suite:
```bash
snforge test
```

3. Deploy and initialize contracts:
```bash
# Authorize auction functionality
sncast --profile sepolia-test script run authorize_auction --package authorize_auction

# Deploy contracts
sncast --profile sepolia-test script run deploy --package deploy

# Mint test tokens
sncast --profile sepolia-test script run mint_coins --package mint_coins

# Mint test NFTs
sncast --profile sepolia-test script run mint_nft --package mint_nft
```

## Security Considerations

- **Pedersen Collision Resistance**: Our implementation relies on the proven collision resistance of Pedersen hash
- **Signature Verification Process**: Robust verification ensures bid authenticity
- **Timestamp Manipulation Prevention**: Secure timestamp handling prevents auction manipulation
- **Front-running Protection**: Built-in mechanisms to prevent front-running attacks

## Deployments - Sepolia

| Name | Contract Address |
| --- | --- |
| Scarab Sign | [0x0035cc91dcb3c458bb619c942225735e942616a9261fcc14ae12dc9d86e1c6ee](https://sepolia.starkscan.co/contract/0x0035cc91dcb3c458bb619c942225735e942616a9261fcc14ae12dc9d86e1c6ee) |
| Mock ERC721 | [0x064f4cbef551b0d9eabf29439ce4bba23548b33f5d3d91dda35acc0ffe2a853e](https://sepolia.starkscan.co/contract/0x064f4cbef551b0d9eabf29439ce4bba23548b33f5d3d91dda35acc0ffe2a853e) |
| Mock ERC20 | [0x05b726cfeaf1e97aa9e742ba910e38b2efa3d2bba4e48740c967e201b456d429](https://sepolia.starkscan.co/contract/0x05b726cfeaf1e97aa9e742ba910e38b2efa3d2bba4e48740c967e201b456d429) |

## Environment Variables

Your `.env` file should contain:
```env
STARKNET_ACCOUNT=your_account_address
STARKNET_PRIVATE_KEY=your_private_key
```

## Contributing

We welcome contributions! Please check our [Contributing Guidelines](CONTRIBUTING.md) for details on:
- Code style and standards
- Development workflow
- Testing requirements
- Pull request process

## License

MIT

---

Built with ❤️ by the ScarabSign team
