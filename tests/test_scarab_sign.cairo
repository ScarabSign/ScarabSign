#[cfg(test)]
mod test_scarab_sign {
    use core::array::SpanTrait;
    use core::traits::Into;
    use core::result::ResultTrait;
    use core::option::OptionTrait;
    use starknet::ContractAddress;
    use core::starknet::contract_address_const;
    use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
    use core::array::ArrayTrait;
    use core::poseidon::PoseidonTrait;
    use core::hash::{HashStateTrait, HashStateExTrait};
    use starknet::{get_tx_info, get_caller_address};
    use scarab_sign::snip_12::{IStructHash, IOffChainMessageHash};
    use scarab_sign::snip_12::v1::StarknetDomain;
    use scarab_sign::scarab_sign::{
        U256_TYPE_HASH, StructHashU256, TokenAmount, TOKEN_AMOUNT_TYPE_HASH, 
        NFT_ID_TYPE_HASH, BID_TYPE_HASH, AUCTION_TYPE_HASH, NftId, Bid, Auction,
        StructHashSpanBid, StructHashSpanFelt252,
        IScarabSignDispatcher, IScarabSignDispatcherTrait
    };
    use scarab_sign::mock_erc20::{IMockERC20Dispatcher, IMockERC20DispatcherTrait};
    use scarab_sign::mock_erc721::{IMockERC721Dispatcher, IMockERC721DispatcherTrait};
    use snforge_std::signature::KeyPairTrait;
    use snforge_std::signature::stark_curve::{StarkCurveKeyPairImpl, StarkCurveSignerImpl, StarkCurveVerifierImpl};

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
        let hash = IStructHash::<TokenAmount>::get_struct_hash(@token_amount);

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
        let hash = IStructHash::<NftId>::get_struct_hash(@nft);

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
        let hash = IStructHash::<Bid>::get_struct_hash(@bid);

        // Calculate expected hash manually
        let mut state = PoseidonTrait::new();
        state = state.update_with(BID_TYPE_HASH);
        let bidder_felt: felt252 = bidder.into();
        state = state.update_with(bidder_felt);
        state = state.update_with(IStructHash::<TokenAmount>::get_struct_hash(@token_amount));
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

        // Calculate hash using get_struct_hash
        let hash = IStructHash::<Auction>::get_struct_hash(@auction);

        // Calculate expected hash manually
        let mut state = PoseidonTrait::new();
        state = state.update_with(AUCTION_TYPE_HASH);
        let auctioneer_felt: felt252 = auctioneer.into();
        state = state.update_with(auctioneer_felt);
        let auctioneer_nonce_felt: felt252 = auctioneer_nonce.into();
        state = state.update_with(auctioneer_nonce_felt);
        state = state.update_with(IStructHash::<NftId>::get_struct_hash(@nft));
        state = state.update_with(IStructHash::<TokenAmount>::get_struct_hash(@min_bid));
        let deadline_felt: felt252 = deadline.into();
        state = state.update_with(deadline_felt);
        state = state.update_with(auction_sig_hash);
        state = state.update_with(StructHashSpanBid::get_struct_hash(@auction.bids));
        state = state.update_with(StructHashSpanFelt252::get_struct_hash(@auction.bid_sigs));
        let expected_hash = state.finalize();

        assert(hash == expected_hash, 'wrong auction hash');
    }

    #[test]
    fn test_span_bid_hash() {
        let token_address = starknet::contract_address_const::<0xabc>();
        let auction_sig_hash = 0x123abc_felt252;

        // Create multiple bids
        let mut bids = ArrayTrait::new();
        let bid1 = Bid {
            bidder: starknet::contract_address_const::<0x111>(),
            amount: TokenAmount { token_address, amount: 2000 },
            nonce: 1_u64,
            auction_sig_hash
        };
        let bid2 = Bid {
            bidder: starknet::contract_address_const::<0x222>(),
            amount: TokenAmount { token_address, amount: 3000 },
            nonce: 2_u64,
            auction_sig_hash
        };
        bids.append(bid1);
        bids.append(bid2);

        // Calculate hash using get_struct_hash
        let hash = StructHashSpanBid::get_struct_hash(@bids.span());

        // Calculate expected hash manually
        let mut state = PoseidonTrait::new();
        state = state.update_with(IStructHash::<Bid>::get_struct_hash(@bid1));
        state = state.update_with(IStructHash::<Bid>::get_struct_hash(@bid2));
        let expected_hash = state.finalize();

        assert(hash == expected_hash, 'Span<Bid> hash mismatch');
    }

    #[test]
    fn test_span_felt252_hash() {
        // Create multiple felt252 values
        let mut values = ArrayTrait::new();
        values.append(0x123_felt252);
        values.append(0x456_felt252);
        values.append(0x789_felt252);

        // Calculate hash using get_struct_hash
        let hash = StructHashSpanFelt252::get_struct_hash(@values.span());

        // Calculate expected hash manually
        let mut state = PoseidonTrait::new();
        state = state.update_with(0x123_felt252);
        state = state.update_with(0x456_felt252);
        state = state.update_with(0x789_felt252);
        let expected_hash = state.finalize();

        assert(hash == expected_hash, 'Span<felt252> hash mismatch');
    }

    #[test]
    fn test_off_chain_message_hash_bid() {
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

        // Get message hash
        let hash = IOffChainMessageHash::<Bid>::get_message_hash(@bid);

        // Calculate expected hash manually
        let domain = StarknetDomain {
            name: 'scarab_auction', 
            version: '1', 
            chain_id: get_tx_info().unbox().chain_id, 
            revision: 1
        };
        let mut state = PoseidonTrait::new();
        state = state.update_with(BID_TYPE_HASH);
        state = state.update_with(IStructHash::<StarknetDomain>::get_struct_hash(@domain));
        let caller_felt: felt252 = get_caller_address().into();
        state = state.update_with(caller_felt);
        state = state.update_with(IStructHash::<Bid>::get_struct_hash(@bid));
        let expected_hash = state.finalize();

        assert(hash == expected_hash, 'Off-chain bid hash mismatch');
    }

    #[test]
    fn test_off_chain_message_hash_auction() {
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

        // Get message hash
        let hash = IOffChainMessageHash::<Auction>::get_message_hash(@auction);

        // Calculate expected hash manually
        let domain = StarknetDomain {
            name: 'scarab_auction', 
            version: '1', 
            chain_id: get_tx_info().unbox().chain_id, 
            revision: 1
        };
        let mut state = PoseidonTrait::new();
        state = state.update_with(AUCTION_TYPE_HASH);
        state = state.update_with(IStructHash::<StarknetDomain>::get_struct_hash(@domain));
        let caller_felt: felt252 = get_caller_address().into();
        state = state.update_with(caller_felt);
        state = state.update_with(IStructHash::<Auction>::get_struct_hash(@auction));
        let expected_hash = state.finalize();

        assert(hash == expected_hash, 'Off-chain auction hash mismatch');
    }

    #[test]
    fn test_auction_hash_with_bids() {
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

        // Create some bids
        let mut bids = ArrayTrait::new();
        let bid1 = Bid {
            bidder: starknet::contract_address_const::<0x111>(),
            amount: TokenAmount { token_address, amount: 2000 },
            nonce: 1_u64,
            auction_sig_hash
        };
        let bid2 = Bid {
            bidder: starknet::contract_address_const::<0x222>(),
            amount: TokenAmount { token_address, amount: 3000 },
            nonce: 2_u64,
            auction_sig_hash
        };
        bids.append(bid1);
        bids.append(bid2);

        // Create some bid signatures
        let mut bid_sigs = ArrayTrait::new();
        bid_sigs.append(0x456_felt252);
        bid_sigs.append(0x789_felt252);

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

        // Calculate hash
        let hash = IStructHash::<Auction>::get_struct_hash(@auction);

        // Calculate expected hash manually
        let mut state = PoseidonTrait::new();
        state = state.update_with(AUCTION_TYPE_HASH);
        let auctioneer_felt: felt252 = auctioneer.into();
        state = state.update_with(auctioneer_felt);
        let auctioneer_nonce_felt: felt252 = auctioneer_nonce.into();
        state = state.update_with(auctioneer_nonce_felt);
        state = state.update_with(IStructHash::<NftId>::get_struct_hash(@nft));
        state = state.update_with(IStructHash::<TokenAmount>::get_struct_hash(@min_bid));
        let deadline_felt: felt252 = deadline.into();
        state = state.update_with(deadline_felt);
        state = state.update_with(auction_sig_hash);
        state = state.update_with(StructHashSpanBid::get_struct_hash(@auction.bids));
        state = state.update_with(StructHashSpanFelt252::get_struct_hash(@auction.bid_sigs));
        let expected_hash = state.finalize();

        assert(hash == expected_hash, 'Auction with bids hash mismatch');
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

     #[test]
    fn test_consume_auction() {
        let erc20 = declare("MockERC20").unwrap().contract_class();
        let erc721 = declare("MockERC721").unwrap().contract_class();
        
        let constructor_calldata: Array<felt252> = ArrayTrait::new();
        
        let (erc20_address, _) = erc20.deploy(@constructor_calldata).unwrap();
        let (erc721_address, _) = erc721.deploy(@constructor_calldata).unwrap();

        let erc20_dispatcher = IMockERC20Dispatcher { contract_address: erc20_address };
        let erc721_dispatcher = IMockERC721Dispatcher { contract_address: erc721_address };
        
        let bidder_keypair = KeyPairTrait::<felt252, felt252>::generate();
        let auctioneer_keypair = KeyPairTrait::<felt252, felt252>::generate();
        
        let bidder: ContractAddress = bidder_keypair.public_key.try_into().unwrap();
        let auctioneer: ContractAddress = auctioneer_keypair.public_key.try_into().unwrap();

        erc20_dispatcher.mint(bidder, 1000_u256);
        erc721_dispatcher.mint(auctioneer, 0_u256);

        // Create the bid amount
        let bid_amount = TokenAmount {
            token_address: erc20_address,
            amount: 1000
        };

        // Create the NFT ID
        let nft = NftId {
            collection_address: erc721_address,
            nft_id: 0_u256
        };

        // Create a bid
        let bid = Bid {
            bidder,
            amount: bid_amount,
            nonce: 1_u64,
            auction_sig_hash: 0, // This will be set after generating auction hash
        };

        let bid_hash = IOffChainMessageHash::<Bid>::get_message_hash(@bid);
        let (signature_r, signature_s): (felt252, felt252) = bidder_keypair.sign(bid_hash).unwrap();
    }
}
