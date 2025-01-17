#[cfg(test)]
mod test_scarab_sign {
    use core::traits::Into;
    use core::result::ResultTrait;
    use core::option::OptionTrait;
    use core::array::ArrayTrait;
    use core::poseidon::PoseidonTrait;
    use core::hash::{HashStateTrait, HashStateExTrait};
    
    use starknet::ContractAddress;
    use starknet::{get_caller_address};
    
    use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
    use snforge_std::{start_cheat_caller_address_global};
    use snforge_std::signature::KeyPairTrait;
    use snforge_std::signature::stark_curve::{StarkCurveKeyPairImpl, StarkCurveSignerImpl, StarkCurveVerifierImpl};
    use scarab_sign::snip_12::{IStructHash, IOffChainMessageHash};
    use scarab_sign::snip_12::v1::StarknetDomain;
    use scarab_sign::scarab_sign::{
        U256_TYPE_HASH, StructHashU256, TokenAmount, TOKEN_AMOUNT_TYPE_HASH, 
        NFT_ID_TYPE_HASH, BID_TYPE_HASH, AUCTION_TYPE_HASH, NftId, Bid, Auction,
        StructHashSpanBid, StructHashSpanFelt252, EcdsaSignature, StructHashSpanEcdsaSignature,
        StructHashSpanSpanEcdsaSignature, IScarabSignDispatcher, IScarabSignDispatcherTrait,
        AuctionAuth
    };
    use scarab_sign::mock_erc20::{IMockERC20Dispatcher, IMockERC20DispatcherTrait};
    use scarab_sign::mock_erc721::{IMockERC721Dispatcher, IMockERC721DispatcherTrait};
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin_token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
    // Update KATANA_CHAIN_ID to match implementation
    const KATANA_CHAIN_ID: felt252 = 0x4b4154414e41;

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
        let amount: u256 = u256 { low: 1000_u128, high: 0_u128 };
        let token_amount = TokenAmount { token_address, amount };

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
        let amount: u256 = u256 { low: 1000_u128, high: 0_u128 };
        let nonce: u64 = 42;
        
        // Create an empty array and convert to span for auction_sig_hash
        let mut empty_sigs: Array<EcdsaSignature> = ArrayTrait::new();
        let auction_sig_hash: Span<EcdsaSignature> = empty_sigs.span();

        let token_amount = TokenAmount { token_address, amount };
        let bid = Bid { bidder, amount: token_amount, nonce, auction_sig_hash };

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
        state = state.update_with(StructHashSpanEcdsaSignature::get_struct_hash(@auction_sig_hash));
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
        let min_bid_amount: u256 = u256 { low: 1000_u128, high: 0_u128 };
        let deadline = 1234567890_u64;
        
        // Create an empty array and convert to span for auction_sig_hash
        let mut empty_sigs: Array<EcdsaSignature> = ArrayTrait::new();
        let auction_sig_hash: Span<EcdsaSignature> = empty_sigs.span();

        let nft = NftId { collection_address, nft_id };
        let min_bid = TokenAmount { token_address, amount: min_bid_amount };

        let mut bids = ArrayTrait::new();
        let mut bid_sigs: Array<Span<EcdsaSignature>> = ArrayTrait::new();

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
        state = state.update_with(StructHashSpanEcdsaSignature::get_struct_hash(@auction_sig_hash));
        state = state.update_with(StructHashSpanBid::get_struct_hash(@auction.bids));
        state = state.update_with(StructHashSpanSpanEcdsaSignature::get_struct_hash(@auction.bid_sigs));
        let expected_hash = state.finalize();

        assert(hash == expected_hash, 'wrong auction hash');
    }

    #[test]
    fn test_span_bid_hash() {
        let token_address = starknet::contract_address_const::<0xabc>();
        
        // Create an empty array and convert to span for auction_sig_hash
        let mut empty_sigs: Array<EcdsaSignature> = ArrayTrait::new();
        let auction_sig_hash: Span<EcdsaSignature> = empty_sigs.span();

        // Create multiple bids
        let mut bids = ArrayTrait::new();
        let bid1 = Bid {
            bidder: starknet::contract_address_const::<0x111>(),
            amount: TokenAmount { token_address, amount: u256 { low: 2000_u128, high: 0_u128 } },
            nonce: 1_u64,
            auction_sig_hash
        };
        let bid2 = Bid {
            bidder: starknet::contract_address_const::<0x222>(),
            amount: TokenAmount { token_address, amount: u256 { low: 3000_u128, high: 0_u128 } },
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
        let bidder = starknet::contract_address_const::<0x789>();
        let token_address = starknet::contract_address_const::<0x123>();
        let amount: u256 = u256 { low: 1000_u128, high: 0_u128 };
        let nonce = 123_u64;

        // Create an empty array and convert to span for auction_sig_hash
        let mut empty_sigs: Array<EcdsaSignature> = ArrayTrait::new();
        let auction_sig_hash: Span<EcdsaSignature> = empty_sigs.span();

        let token_amount = TokenAmount { token_address, amount };
        let bid = Bid { bidder, amount: token_amount, nonce, auction_sig_hash };

        // Get message hash
        let hash = IOffChainMessageHash::<Bid>::get_message_hash(@bid);

        // Calculate expected hash manually
        let domain = StarknetDomain {
            name: 'scarab_auction', 
            version: '1', 
            chain_id: KATANA_CHAIN_ID,
            revision: 1
        };
        let mut state = PoseidonTrait::new();
        state = state.update_with(BID_TYPE_HASH);
        state = state.update_with(domain.get_struct_hash());
        let bidder_felt: felt252 = bid.bidder.into();
        state = state.update_with(bidder_felt);
        state = state.update_with(IStructHash::<Bid>::get_struct_hash(@bid));
        let expected_hash = state.finalize();

        assert(hash == expected_hash, 'Off-chain bid hash mismatch');
    }

    #[test]
    fn test_off_chain_message_hash_auction() {
        let auctioneer = starknet::contract_address_const::<0x123>();
        
        // Set the caller address to match the auctioneer
        start_cheat_caller_address_global(auctioneer);
        
        let auctioneer_nonce = 456_u64;
        let collection_address = starknet::contract_address_const::<0x789>();
        let nft_id = 123_u256;
        let token_address = starknet::contract_address_const::<0xabc>();
        let min_bid_amount: u256 = u256 { low: 1000_u128, high: 0_u128 };
        let deadline = 1234567890_u64;
        
        // Create an empty array and convert to span for auction_sig_hash
        let mut empty_sigs: Array<EcdsaSignature> = ArrayTrait::new();
        let auction_sig_hash: Span<EcdsaSignature> = empty_sigs.span();

        let nft = NftId { collection_address, nft_id };
        let min_bid = TokenAmount { token_address, amount: min_bid_amount };

        let mut bids = ArrayTrait::new();
        let mut bid_sigs: Array<Span<EcdsaSignature>> = ArrayTrait::new();

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
            chain_id: KATANA_CHAIN_ID,
            revision: 1
        };
        let mut state = PoseidonTrait::new();
        state = state.update_with(AUCTION_TYPE_HASH);
        state = state.update_with(domain.get_struct_hash());
        state = state.update_with(get_caller_address());
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
        let min_bid_amount: u256 = u256 { low: 1000_u128, high: 0_u128 };
        let deadline = 1234567890_u64;
        
        // Create an empty array and convert to span for auction_sig_hash
        let mut empty_sigs: Array<EcdsaSignature> = ArrayTrait::new();
        let auction_sig_hash: Span<EcdsaSignature> = empty_sigs.span();

        let nft = NftId { collection_address, nft_id };
        let min_bid = TokenAmount { token_address, amount: min_bid_amount };

        // Create some bids
        let mut bids = ArrayTrait::new();
        let bid1 = Bid {
            bidder: starknet::contract_address_const::<0x111>(),
            amount: TokenAmount { token_address, amount: u256 { low: 2000_u128, high: 0_u128 } },
            nonce: 1_u64,
            auction_sig_hash
        };
        let bid2 = Bid {
            bidder: starknet::contract_address_const::<0x222>(),
            amount: TokenAmount { token_address, amount: u256 { low: 3000_u128, high: 0_u128 } },
            nonce: 2_u64,
            auction_sig_hash
        };
        bids.append(bid1);
        bids.append(bid2);

        // Create some bid signatures
        let mut bid_sigs: Array<Span<EcdsaSignature>> = ArrayTrait::new();
        let mut bid_sig1: Array<EcdsaSignature> = ArrayTrait::new();
        bid_sig1.append(EcdsaSignature { r: 0x456_felt252, s: 0x456_felt252 });
        let bid_sig1_span = bid_sig1.span();
        let mut bid_sig2: Array<EcdsaSignature> = ArrayTrait::new();
        bid_sig2.append(EcdsaSignature { r: 0x789_felt252, s: 0x789_felt252 });
        let bid_sig2_span = bid_sig2.span();
        bid_sigs.append(bid_sig1_span);
        bid_sigs.append(bid_sig2_span);

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
        state = state.update_with(StructHashSpanEcdsaSignature::get_struct_hash(@auction_sig_hash));
        state = state.update_with(StructHashSpanBid::get_struct_hash(@auction.bids));
        state = state.update_with(StructHashSpanSpanEcdsaSignature::get_struct_hash(@auction.bid_sigs));
        let expected_hash = state.finalize();

        assert(hash == expected_hash, 'Auction with bids hash mismatch');
    }

    #[test]
    fn test_auction_auth_hash() {
        // Create test data
        let auctioneer = starknet::contract_address_const::<0x123>();
        let token_address = starknet::contract_address_const::<0x456>();
        let collection_address = starknet::contract_address_const::<0x789>();
        
        let min_bid = TokenAmount {
            token_address,
            amount: u256 { low: 1000_u128, high: 0_u128 }
        };

        let nft = NftId {
            collection_address,
            nft_id: 123_u256
        };

        let auction_auth = AuctionAuth {
            auctioneer,
            auctioneer_nonce: 456_u64,
            nft,
            min_bid,
            deadline: 999_u64,
        };

        let hash = IOffChainMessageHash::<AuctionAuth>::get_message_hash(@auction_auth);
        assert(hash != 0, 'Hash should not be zero');
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
        let scarab_sign = declare("ScarabSign").unwrap().contract_class();

        let constructor_calldata: Array<felt252> = ArrayTrait::new();
        let (erc20_address, _) = erc20.deploy(@constructor_calldata).unwrap();
        let (erc721_address, _) = erc721.deploy(@constructor_calldata).unwrap();
        let (scarab_sign_address, _) = scarab_sign.deploy(@constructor_calldata).unwrap();

        let mock_erc20_dispatcher = IMockERC20Dispatcher { contract_address: erc20_address };
        let erc20_dispatcher = IERC20Dispatcher { contract_address: erc20_address };
        let mock_erc721_dispatcher = IMockERC721Dispatcher { contract_address: erc721_address };
        let erc721_dispatcher = IERC721Dispatcher { contract_address: erc721_address };
        let scarab_sign_dispatcher = IScarabSignDispatcher { contract_address: scarab_sign_address };
        
        let bidder_keypair = KeyPairTrait::<felt252, felt252>::generate();
        let auctioneer_keypair = KeyPairTrait::<felt252, felt252>::generate();
        
        let bidder: ContractAddress = bidder_keypair.public_key.try_into().unwrap();
        let auctioneer: ContractAddress = auctioneer_keypair.public_key.try_into().unwrap();

        mock_erc20_dispatcher.mint(bidder, u256 { low: 1000_u128, high: 0_u128 });
        mock_erc721_dispatcher.mint(auctioneer, 0_u256);

        // Create the bid amount
        let bid_amount = TokenAmount {
            token_address: erc20_address,
            amount: u256 { low: 1000_u128, high: 0_u128 }
        };

        // Create the NFT ID
        let nft = NftId {
            collection_address: erc721_address,
            nft_id: 0_u256
        };

        // Create and sign the auction auth first
        let auction_auth = AuctionAuth {
            auctioneer,
            auctioneer_nonce: 1_u64,
            nft,
            min_bid: bid_amount,
            deadline: 9999999999_u64,
        };

        // Set caller as auctioneer before generating signature
        start_cheat_caller_address_global(auctioneer);

        let auction_auth_hash = IOffChainMessageHash::<AuctionAuth>::get_message_hash(@auction_auth);
        
        // Debug logging for signature generation
        let caller: felt252 = get_caller_address().try_into().unwrap();
        let auctioneer_felt: felt252 = auctioneer.try_into().unwrap();
        println!("=== Signature Generation ===");
        println!("Auction auth hash: {}", auction_auth_hash);
        println!("Caller address (felt): {}", caller);
        println!("Auctioneer address (felt): {}", auctioneer_felt);
        println!("========================");

        let (auction_signature_r, auction_signature_s): (felt252, felt252) = auctioneer_keypair.sign(auction_auth_hash).unwrap();

        // Create a bid
        let mut empty_sigs: Array<EcdsaSignature> = ArrayTrait::new();
        let auction_auth_sig = EcdsaSignature { r: auction_signature_r, s: auction_signature_s };
        let mut auction_sigs: Array<EcdsaSignature> = ArrayTrait::new();
        auction_sigs.append(auction_auth_sig);
        
        let bid = Bid {
            bidder,
            amount: bid_amount,
            nonce: 1_u64,
            auction_sig_hash: auction_sigs.span()
        };

        // Set caller as bidder for bid signature
        start_cheat_caller_address_global(bidder);

        let bid_hash = IOffChainMessageHash::<Bid>::get_message_hash(@bid);
        let (bid_signature_r, bid_signature_s): (felt252, felt252) = bidder_keypair.sign(bid_hash).unwrap();
        let bid_sig = EcdsaSignature { r: bid_signature_r, s: bid_signature_s };

        // Create the final auction with the auth data, signatures and bids
        let auction = Auction {
            auctioneer: auction_auth.auctioneer,
            auctioneer_nonce: auction_auth.auctioneer_nonce,
            nft: auction_auth.nft,
            min_bid: auction_auth.min_bid,
            deadline: auction_auth.deadline,
            auction_sig_hash: auction_sigs.span(),
            bids: array![bid].span(),
            bid_sigs: array![array![bid_sig].span()].span(),
        };

        // Deploy the contract

        // Approve token transfer using OpenZeppelin ERC20 interface
        start_cheat_caller_address_global(bidder);
        erc20_dispatcher.approve(scarab_sign_address, bid_amount.amount);
        erc20_dispatcher.approve(auction.auctioneer, bid_amount.amount);

        // Get initial balances
        let initial_token_balance = erc20_dispatcher.balance_of(auction.auctioneer);

        // Set caller back to auctioneer for auction consumption
        start_cheat_caller_address_global(auctioneer);

        // Create the dispatcher and call consume_auction
        scarab_sign_dispatcher.consume_auction(auction, auction_signature_r, auction_signature_s);

        // Verify final state
        let final_nft_owner = erc721_dispatcher.owner_of(nft.nft_id);
        assert(final_nft_owner == bidder, 'NFT transfer failed');
        
        let final_token_balance = erc20_dispatcher.balance_of(auction.auctioneer);
        let expected_balance = initial_token_balance + bid_amount.amount;
        assert(final_token_balance == expected_balance, 'Token transfer failed');
    }
}
