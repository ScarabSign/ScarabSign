#[cfg(test)]
mod test_scarab_sign {
    use starknet::ContractAddress;
    use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
    use core::array::{ArrayTrait, SpanTrait};
    use core::result::ResultTrait;
    use core::traits::TryInto;
    use core::poseidon::PoseidonTrait;
    use core::hash::{HashStateTrait, HashStateExTrait};
    use scarab_sign::snip_12::IStructHash;
    use scarab_sign::scarab_sign::{
        U256_TYPE_HASH, StructHashU256, TokenAmount, TOKEN_AMOUNT_TYPE_HASH, 
        NftId, NFT_ID_TYPE_HASH, Bid, BID_TYPE_HASH, Auction, AUCTION_TYPE_HASH,
        StructHashSpanBid, StructHashSpanFelt252
    };

    #[starknet::interface]
    trait IScarabSignDispatcher<TContractState> {
        fn consume_auction(
            ref self: TContractState,
            auction: ContractAddress,
            signature_r: felt252,
            signature_s: felt252
        );
    }

    impl TestStructHashSpanBid of IStructHash<Span<Bid>> {
        fn get_struct_hash(self: @Span<Bid>) -> felt252 {
            let mut state = PoseidonTrait::new();
            let span = *self;
            let mut i: usize = 0;
            loop {
                if i >= span.len() {
                    break;
                }
                state = state.update_with(span[i].get_struct_hash());
                i += 1;
            };
            state.finalize()
        }
    }

    impl TestStructHashSpanFelt252 of IStructHash<Span<felt252>> {
        fn get_struct_hash(self: @Span<felt252>) -> felt252 {
            let mut state = PoseidonTrait::new();
            let span = *self;
            let mut i: usize = 0;
            loop {
                if i >= span.len() {
                    break;
                }
                let value = *span[i];
                state = state.update_with(value);
                i += 1;
            };
            state.finalize()
        }
    }

    #[test]
    fn test_basic() {
        assert(1 == 1, 'basic test');
    }

    #[test]
    fn test_u256_hash() {
        // Create a u256 value
        let value: u256 = u256 { low: 12345_u128, high: 0_u128 };
        
        // Calculate the hash using our implementation
        let hash = StructHashU256::get_struct_hash(@value);
        
        // Calculate the expected hash manually
        let mut state = PoseidonTrait::new();
        state = HashStateExTrait::update_with(state, U256_TYPE_HASH);
        state = HashStateExTrait::update_with(state, value);
        let expected_hash = HashStateTrait::finalize(state);
        
        // Verify they match
        assert(hash == expected_hash, 'incorrect u256 hash');
    }

    #[test]
    fn test_token_amount_hash() {
        let token_address = starknet::contract_address_const::<0x123>();
        let amount: felt252 = 1000;
        let token_amount = TokenAmount { token_address: token_address, amount: amount };

        // Calculate hash using get_struct_hash
        let hash = token_amount.get_struct_hash();

        // Calculate expected hash manually
        let mut state = PoseidonTrait::new();
        state = state.update_with(TOKEN_AMOUNT_TYPE_HASH);
        let token_felt: felt252 = token_address.into();
        state = state.update_with(token_felt);
        state = state.update_with(amount);
        let expected_hash = state.finalize();

        // Compare hashes
        assert(hash == expected_hash, 'Hash mismatch');
    }

    #[test]
    fn test_nft_id_hash() {
        let collection_address = starknet::contract_address_const::<0x456>();
        let nft_id: u256 = 42_u256;
        let nft = NftId { collection_address, nft_id };

        // Calculate hash using get_struct_hash
        let hash = nft.get_struct_hash();

        // Calculate expected hash manually
        let mut state = PoseidonTrait::new();
        state = state.update_with(NFT_ID_TYPE_HASH);
        let collection_felt: felt252 = collection_address.into();
        state = state.update_with(collection_felt);
        let nft_id_felt: felt252 = nft_id.try_into().unwrap();
        state = state.update_with(nft_id_felt);
        let expected_hash = state.finalize();

        // Compare hashes
        assert(hash == expected_hash, 'Hash mismatch');
    }

    #[test]
    fn test_bid_hash() {
        // Create test data
        let bidder = starknet::contract_address_const::<0x789>();
        let token_address = starknet::contract_address_const::<0x123>();
        let amount: felt252 = 1000;
        let token_amount = TokenAmount { token_address: token_address, amount: amount };
        let nonce: u64 = 42;
        let auction_sig_hash: felt252 = 0x123abc;

        let bid = Bid { 
            bidder: bidder, 
            amount: token_amount, 
            nonce: nonce, 
            auction_sig_hash: auction_sig_hash 
        };

        // Calculate hash using get_struct_hash
        let hash = bid.get_struct_hash();

        // Calculate expected hash manually
        let mut state = PoseidonTrait::new();
        state = state.update_with(BID_TYPE_HASH);
        let bidder_felt: felt252 = bidder.into();
        state = state.update_with(bidder_felt);
        state = state.update_with(token_amount.get_struct_hash());
        let nonce_felt: felt252 = nonce.into();
        state = state.update_with(nonce_felt);
        state = state.update_with(auction_sig_hash);
        let expected_hash = state.finalize();

        // Compare hashes
        assert(hash == expected_hash, 'Hash mismatch');
    }

    #[test]
    fn test_auction_hash() {
        let auctioneer = starknet::contract_address_const::<0x123>();
        let auctioneer_nonce = 456_u64;
        let collection_address = starknet::contract_address_const::<0x789>();
        let nft_id = 123_u256;
        let token_address = starknet::contract_address_const::<0xabc>();
        let min_bid_amount = 1000_felt252;
        let deadline = 1234567890_u64;
        let auction_sig_hash = 0x123abc_felt252;

        let nft = NftId { collection_address, nft_id };
        let min_bid = TokenAmount { token_address, amount: min_bid_amount };

        let mut bids = ArrayTrait::new();
        let mut bid_sigs = ArrayTrait::new();

        let auction = Auction {
            auctioneer,
            auctioneer_nonce,
            nft,
            min_bid,
            deadline,
            auction_sig_hash,
            bids: bids.span(),
            bid_sigs: bid_sigs.span(),
        };

        let mut state = PoseidonTrait::new();
        state = state.update_with(AUCTION_TYPE_HASH);
        let auctioneer_felt: felt252 = auctioneer.into();
        state = state.update_with(auctioneer_felt);
        let auctioneer_nonce_felt: felt252 = auctioneer_nonce.into();
        state = state.update_with(auctioneer_nonce_felt);
        state = state.update_with(nft.get_struct_hash());
        state = state.update_with(min_bid.get_struct_hash());
        let deadline_felt: felt252 = deadline.into();
        state = state.update_with(deadline_felt);
        state = state.update_with(auction_sig_hash);
        state = state.update_with(TestStructHashSpanBid::get_struct_hash(@bids.span()));
        state = state.update_with(TestStructHashSpanFelt252::get_struct_hash(@bid_sigs.span()));
        let expected_hash = state.finalize();

        assert(auction.get_struct_hash() == expected_hash, 'wrong auction hash');
    }

    #[test]
    fn test_deploy() {
        // First declare and deploy the contract
        let contract = declare("ScarabSign").unwrap().contract_class();
        let constructor_calldata = ArrayTrait::new();
        let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
        
        // The contract exists and has an address
        let zero: felt252 = 0;
        let zero_address: ContractAddress = zero.try_into().unwrap();
        assert(contract_address != zero_address, 'deployment failed');
    }
}
