#[cfg(test)]
mod tests {
    use core::traits::TryInto;
    use snforge_std::{declare, ContractClassTrait, start_prank, stop_prank, CheatTarget};
    use starknet::{ContractAddress, contract_address_const};
    use core::pedersen::pedersen_hash;
    use core::array::ArrayTrait;
    use core::option::OptionTrait;

    use super::HomomorphicAuction::{
        Bid, Auction, BidFailed, AuctionComplete,
        HomomorphicAuctionImpl
    };

    // Test contracts for ERC20 and ERC721
    #[starknet::interface]
    trait IERC20 {
        fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
        fn transfer_from(ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
        fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
        fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
        fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    }

    #[starknet::interface]
    trait IERC721 {
        fn transfer_from(ref self: TContractState, from: ContractAddress, to: ContractAddress, token_id: u256);
        fn approve(ref self: TContractState, to: ContractAddress, token_id: u256);
        fn balance_of(self: @TContractState, owner: ContractAddress) -> u256;
    }

    // Test setup
    fn setup_test() -> (ContractAddress, ContractAddress, ContractAddress, ContractAddress) {
        // Deploy mock contracts
        let auction_class = declare('HomomorphicAuction');
        let erc20_class = declare('MockERC20');
        let erc721_class = declare('MockERC721');

        let auction_address = auction_class.deploy(@ArrayTrait::new()).unwrap();
        let token_address = erc20_class.deploy(@ArrayTrait::new()).unwrap();
        let nft_address = erc721_class.deploy(@ArrayTrait::new()).unwrap();
        
        // Create test account
        let test_account = contract_address_const::<'TESTER'>();
        
        (auction_address, token_address, nft_address, test_account)
    }

    #[test]
    fn test_bid_signature_verification() {
        let (auction_address, token_address, nft_address, test_account) = setup_test();
        
        // Create test bid
        let bid = Bid {
            bidder: test_account,
            amount: 1000000000000000000, // 1 token
            bidder_nonce: 0,
            auction_sig_hash: pedersen_hash('test_auction', 0),
        };

        // Mock signature components
        let v: u8 = 27;
        let r = 12345;
        let s = 67890;

        // Mock bid signature verification
        start_prank(CheatTarget::One(auction_address), test_account);
        
        let result = HomomorphicAuctionImpl::verify_bid(bid, (v, r, s));
        assert(result, 'Bid signature verification failed');
        
        stop_prank(CheatTarget::One(auction_address));
    }

    #[test]
    fn test_auction_creation_and_bid() {
        let (auction_address, token_address, nft_address, test_account) = setup_test();
        
        // Setup auction parameters
        let deadline = 1704672000; // Some future timestamp
        let auction = Auction {
            auctioneer: test_account,
            auctioneer_nonce: 0,
            nft: nft_address,
            nft_id: 1,
            token: token_address,
            bid_start: 1000000000000000000, // 1 token
            deadline,
            auction_sig_hash: pedersen_hash('test_auction', 0),
            bids: ArrayTrait::new(),
            bid_sigs: ArrayTrait::new(),
        };

        // Mock approvals and balances
        start_prank(CheatTarget::One(token_address), test_account);
        IERC20::approve(token_address, auction_address, 1000000000000000000);
        stop_prank(CheatTarget::One(token_address));

        start_prank(CheatTarget::One(nft_address), test_account);
        IERC721::approve(nft_address, auction_address, 1);
        stop_prank(CheatTarget::One(nft_address));

        // Create and sign bid
        let bid = Bid {
            bidder: test_account,
            amount: 1000000000000000000,
            bidder_nonce: 0,
            auction_sig_hash: auction.auction_sig_hash,
        };

        let mut bids = ArrayTrait::new();
        bids.append(bid);

        let mut bid_sigs = ArrayTrait::new();
        bid_sigs.append((27, 12345, 67890)); // Mock signature

        let auction_with_bids = Auction {
            bids,
            bid_sigs,
            ..auction
        };

        // Execute auction
        start_prank(CheatTarget::One(auction_address), test_account);
        
        HomomorphicAuctionImpl::consume_auction(27, 12345, 67890, auction_with_bids);
        
        stop_prank(CheatTarget::One(auction_address));

        // Verify final state
        let winner_nft_balance = IERC721::balance_of(nft_address, test_account);
        assert(winner_nft_balance == 1, 'NFT transfer failed');
    }

    #[test]
    fn test_bid_fallback_on_insufficient_funds() {
        let (auction_address, token_address, nft_address, test_account) = setup_test();
        
        // Create auction with multiple bids
        let mut bids = ArrayTrait::new();
        
        // High bid with insufficient funds
        let high_bid = Bid {
            bidder: test_account,
            amount: 1000000000000000000000, // Very high amount
            bidder_nonce: 0,
            auction_sig_hash: pedersen_hash('test_auction', 0),
        };
        bids.append(high_bid);

        // Lower bid with sufficient funds
        let low_bid = Bid {
            bidder: test_account,
            amount: 1000000000000000000, // 1 token
            bidder_nonce: 1,
            auction_sig_hash: pedersen_hash('test_auction', 0),
        };
        bids.append(low_bid);

        let mut bid_sigs = ArrayTrait::new();
        bid_sigs.append((27, 12345, 67890)); // Mock signatures
        bid_sigs.append((27, 12345, 67890));

        let auction = Auction {
            auctioneer: test_account,
            auctioneer_nonce: 0,
            nft: nft_address,
            nft_id: 1,
            token: token_address,
            bid_start: 1000000000000000000,
            deadline: 1704672000,
            auction_sig_hash: pedersen_hash('test_auction', 0),
            bids,
            bid_sigs,
        };

        // Setup balances and approvals for lower bid
        start_prank(CheatTarget::One(token_address), test_account);
        IERC20::approve(token_address, auction_address, 1000000000000000000);
        stop_prank(CheatTarget::One(token_address));

        // Execute auction
        start_prank(CheatTarget::One(auction_address), test_account);
        
        HomomorphicAuctionImpl::consume_auction(27, 12345, 67890, auction);
        
        stop_prank(CheatTarget::One(auction_address));

        // Verify the lower bid was accepted
        let winner_nft_balance = IERC721::balance_of(nft_address, test_account);
        assert(winner_nft_balance == 1, 'NFT transfer to lower bidder failed');
    }

    #[test]
    #[should_panic(expected: ('No valid bids with sufficient funds',))]
    fn test_auction_fails_with_no_valid_bids() {
        let (auction_address, token_address, nft_address, test_account) = setup_test();
        
        // Create auction with no valid bids
        let auction = Auction {
            auctioneer: test_account,
            auctioneer_nonce: 0,
            nft: nft_address,
            nft_id: 1,
            token: token_address,
            bid_start: 1000000000000000000,
            deadline: 1704672000,
            auction_sig_hash: pedersen_hash('test_auction', 0),
            bids: ArrayTrait::new(),
            bid_sigs: ArrayTrait::new(),
        };

        // Should panic with no valid bids
        start_prank(CheatTarget::One(auction_address), test_account);
        
        HomomorphicAuctionImpl::consume_auction(27, 12345, 67890, auction);
        
        stop_prank(CheatTarget::One(auction_address));
    }

    #[test]
    fn test_homomorphic_signature_chain() {
        let (auction_address, token_address, nft_address, test_account) = setup_test();
        
        // Create multiple bids to test signature chaining
        let mut bids = ArrayTrait::new();
        let mut bid_sigs = ArrayTrait::new();

        // Create bid chain
        let base_hash = pedersen_hash('test_auction', 0);
        
        for i in 0..3 {
            let bid = Bid {
                bidder: test_account,
                amount: 1000000000000000000 * (3 - i), // Decreasing amounts
                bidder_nonce: i,
                auction_sig_hash: base_hash,
            };
            
            // Each signature incorporates previous bid information
            let sig_hash = if i == 0 {
                base_hash
            } else {
                pedersen_hash(base_hash, HomomorphicAuctionImpl::hash_bid(bids[i - 1]))
            };
            
            bids.append(bid);
            bid_sigs.append((27, sig_hash, 67890)); // Mock signatures with chained hashes
        }

        let auction = Auction {
            auctioneer: test_account,
            auctioneer_nonce: 0,
            nft: nft_address,
            nft_id: 1,
            token: token_address,
            bid_start: 1000000000000000000,
            deadline: 1704672000,
            auction_sig_hash: base_hash,
            bids,
            bid_sigs,
        };

        // Setup approvals for highest bid
        start_prank(CheatTarget::One(token_address), test_account);
        IERC20::approve(token_address, auction_address, 3000000000000000000);
        stop_prank(CheatTarget::One(token_address));

        // Execute auction
        start_prank(CheatTarget::One(auction_address), test_account);
        
        HomomorphicAuctionImpl::consume_auction(27, 12345, 67890, auction);
        
        stop_prank(CheatTarget::One(auction_address));

        // Verify highest bid won
        let winner_nft_balance = IERC721::balance_of(nft_address, test_account);
        assert(winner_nft_balance == 1, 'NFT transfer to highest bidder failed');
    }
}
