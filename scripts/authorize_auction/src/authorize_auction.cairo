use starknet::ContractAddress;
use crate::utils::{
    AuctionAuth, TokenAmount, NftId, EcdsaSignature, IOffChainMessageHash
};

const AUCTIONEER: felt252 =
    0x00238492da986358805a85d97af467e162509fda4e5736737a8ff68380766223;

fn main() {
    let mock_erc721_address = starknet::contract_address_const::<0x064f4cbef551b0d9eabf29439ce4bba23548b33f5d3d91dda35acc0ffe2a853e>();
    let mock_erc20_address = starknet::contract_address_const::<0x05b726cfeaf1e97aa9e742ba910e38b2efa3d2bba4e48740c967e201b456d429>();
    
    // Create NFT ID
    let nft = NftId {
        collection_address: mock_erc721_address,
        nft_id: 1.into()
    };

    // Create minimum bid amount
    let min_bid = TokenAmount {
        token_address: mock_erc20_address,
        amount: 100.into()
    };

    let auctioneer_nonce: u64 = 1_u64;

    // Create auction auth
    let auction_auth = AuctionAuth {
        auctioneer: starknet::contract_address_const::<AUCTIONEER>(),
        auctioneer_nonce,
        nft: nft,
        min_bid: min_bid,
        deadline: 1706745600 // Jan 31, 2024 UTC
    };

    // Get the hash for the auction auth
    let auction_auth_hash = IOffChainMessageHash::<AuctionAuth>::get_message_hash(@auction_auth);
    
    let auctioneer_felt: felt252 = auction_auth.auctioneer.into();
    let nft_collection_felt: felt252 = auction_auth.nft.collection_address.into();
    let token_address_felt: felt252 = auction_auth.min_bid.token_address.into();

    println!("=== Auction Authorization Details ===");
    println!("Auctioneer: 0x{:x}", auctioneer_felt);
    println!("NFT Collection: 0x{:x}", nft_collection_felt);
    println!("NFT ID: {}", auction_auth.nft.nft_id);
    println!("Min Bid Token: 0x{:x}", token_address_felt);
    println!("Min Bid Amount: {}", auction_auth.min_bid.amount);
    println!("Deadline: {}", auction_auth.deadline);
    println!("");
    println!("=== Sign Command ===");
    println!("sncast --profile sepolia-test sign-message --message 0x{:x}", auction_auth_hash);
}