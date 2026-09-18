use core::starknet::ContractAddress;
use starknet::get_tx_info;
use core::poseidon::PoseidonTrait;
use core::hash::{HashStateTrait, HashStateExTrait};
use crate::snip_12::{IOffChainMessageHash, IStructHash, v1::StarknetDomain};
use core::array::SpanTrait;

pub const SIGNATURE_TYPE_HASH: felt252 = 
  selector!("\"Signature\"(\"r\":\"felt252\",\"s\":\"felt252\")");

pub const U256_TYPE_HASH: felt252 = 
	selector!("\"u256\"(\"low\":\"u128\",\"high\":\"u128\")");

pub const TOKEN_AMOUNT_TYPE_HASH: felt252 = 
	selector!("\"TokenAmount\"(\"token_address\":\"ContractAddress\",\"amount\":\"u256\")");

pub const NFT_ID_TYPE_HASH: felt252 = 
	selector!("\"NftId\"(\"collection_address\":\"ContractAddress\",\"nft_id\":\"u256\")\"u256\"(\"low\":\"u128\",\"high\":\"u128\")");

// Field types must be ones SNIP-12 revision 1 actually defines (verified against
// starknet.js's encoder): "u64" and "felt252" are not SNIP-12 base types - "u64" isn't
// a base type at all, and the felt type is spelled "felt", not "felt252" - so any
// SNIP-12-compliant signer (wallet or library) would throw or produce a mismatched hash
// against the original constants below. "auction_sig_hash"/"bid_sigs" are pre-hashed
// signature-span digests (see StructHashSpanEcdsaSignature et al.), so they're encoded
// as opaque felts here rather than as nested structs/arrays.
pub const BID_TYPE_HASH: felt252 =
	selector!("\"Bid\"(\"bidder\":\"ContractAddress\",\"amount\":\"TokenAmount\",\"nonce\":\"felt\",\"auction_sig_hash\":\"felt\")\"TokenAmount\"(\"token_address\":\"ContractAddress\",\"amount\":\"u256\")");

pub const AUCTION_TYPE_HASH: felt252 =
	selector!("\"Auction\"(\"auctioneer\":\"ContractAddress\",\"auctioneer_nonce\":\"felt\",\"nft\":\"NftId\",\"min_bid\":\"TokenAmount\",\"deadline\":\"felt\",\"auction_sig_hash\":\"felt\",\"bids\":\"Bid*\",\"bid_sigs\":\"felt*\")\"Bid\"(\"bidder\":\"ContractAddress\",\"amount\":\"TokenAmount\",\"nonce\":\"felt\",\"auction_sig_hash\":\"felt\")\"NftId\"(\"collection_address\":\"ContractAddress\",\"nft_id\":\"u256\")\"TokenAmount\"(\"token_address\":\"ContractAddress\",\"amount\":\"u256\")\"u256\"(\"low\":\"u128\",\"high\":\"u128\")");

pub const AUCTION_AUTH_TYPE_HASH: felt252 =
    selector!("\"AuctionAuth\"(\"auctioneer\":\"ContractAddress\",\"auctioneer_nonce\":\"felt\",\"nft\":\"NftId\",\"min_bid\":\"TokenAmount\",\"deadline\":\"felt\")\"NftId\"(\"collection_address\":\"ContractAddress\",\"nft_id\":\"u256\")\"TokenAmount\"(\"token_address\":\"ContractAddress\",\"amount\":\"u256\")\"u256\"(\"low\":\"u128\",\"high\":\"u128\")");

#[derive(Drop, Copy, Hash, Serde)]
pub struct EcdsaSignature {
  pub r: felt252,
  pub s: felt252
}

#[derive(Drop, Copy, Hash, Serde)]
pub struct TokenAmount {
  pub token_address: ContractAddress,
  pub amount: u256
}

#[derive(Drop, Copy, Hash, Serde)]
pub struct NftId {
  pub collection_address: ContractAddress,
  pub nft_id: u256
}

#[derive(Drop, Copy, Serde)]
pub struct Bid {
  pub bidder: ContractAddress,
  pub amount: TokenAmount,
  pub nonce: u64,
  pub auction_sig_hash: Span<EcdsaSignature>,
}

#[derive(Drop, Copy, Serde)]
pub struct Auction {
  pub auctioneer: ContractAddress,
  pub auctioneer_nonce: u64,
  pub nft: NftId,
  pub min_bid: TokenAmount,
  pub deadline: u64,
  pub auction_sig_hash: Span<EcdsaSignature>,
  pub bids: Span<Bid>,
  pub bid_sigs: Span<Span<EcdsaSignature>>,
}

#[derive(Drop, Copy, Hash, Serde)]
pub struct AuctionAuth {
    pub auctioneer: ContractAddress,
    pub auctioneer_nonce: u64,
    pub nft: NftId,
    pub min_bid: TokenAmount,
    pub deadline: u64,
}

impl OffChainMessageHashBid of IOffChainMessageHash<Bid> {
	fn get_message_hash(self: @Bid) -> felt252 {
		let domain = StarknetDomain {
			name: 'scarab_auction',
			version: '1',
			chain_id: get_tx_info().unbox().chain_id,
			revision: 1
		};
		let mut state = PoseidonTrait::new();
		state = state.update_with(BID_TYPE_HASH);
		state = state.update_with(domain.get_struct_hash());
		let bidder_felt: felt252 = (*self).bidder.into();
		state = state.update_with(bidder_felt);
		state = state.update_with(self.get_struct_hash());
		state.finalize()
	}
}

impl OffChainMessageHashAuction of IOffChainMessageHash<Auction> {
	fn get_message_hash(self: @Auction) -> felt252 {
		let domain = StarknetDomain {
			name: 'scarab_auction',
			version: '1',
			chain_id: get_tx_info().unbox().chain_id,
			revision: 1
		};
		let mut state = PoseidonTrait::new();
		state = state.update_with(AUCTION_TYPE_HASH);
		state = state.update_with(domain.get_struct_hash());
		let auctioneer_felt: felt252 = (*self).auctioneer.into();
		state = state.update_with(auctioneer_felt);
		state = state.update_with(self.get_struct_hash());
		state.finalize()
	}
}

impl OffChainMessageHashAuctionAuth of IOffChainMessageHash<AuctionAuth> {
    fn get_message_hash(self: @AuctionAuth) -> felt252 {
        let domain = StarknetDomain {
            name: 'scarab_auction',
            version: '1',
            chain_id: get_tx_info().unbox().chain_id,
            revision: 1
        };
        let mut state = PoseidonTrait::new();
        state = state.update_with(AUCTION_AUTH_TYPE_HASH);
        state = state.update_with(domain.get_struct_hash());
        let auctioneer_felt: felt252 = (*self).auctioneer.into();
        state = state.update_with(auctioneer_felt);
        state = state.update_with(self.get_struct_hash());
        state.finalize()
    }
}

pub impl StructHashEcdsaSignature of IStructHash<EcdsaSignature> {
  fn get_struct_hash(self: @EcdsaSignature) -> felt252 {
    let mut state = PoseidonTrait::new();
    state = state.update_with(SIGNATURE_TYPE_HASH);
    state = state.update_with(*self.r);
    state = state.update_with(*self.s);
    state.finalize()
  }
}

pub impl StructHashU256 of IStructHash<u256> {
  fn get_struct_hash(self: @u256) -> felt252 {
    let mut state = PoseidonTrait::new();
    state = state.update_with(U256_TYPE_HASH);
    state = state.update_with(*self);
    state.finalize()
  }

}

pub impl StructHashTokenAmount of IStructHash<TokenAmount> {
  fn get_struct_hash(self: @TokenAmount) -> felt252 {
    let mut state = PoseidonTrait::new();
    state = state.update_with(TOKEN_AMOUNT_TYPE_HASH);
    let token_felt: felt252 = (*self.token_address).try_into().unwrap();
    state = state.update_with(token_felt);
    state = state.update_with(*self.amount);
    state.finalize()
  }
}

pub impl StructHashNftId of IStructHash<NftId> {
  fn get_struct_hash(self: @NftId) -> felt252 {
    let mut state = PoseidonTrait::new();
    state = state.update_with(NFT_ID_TYPE_HASH);
    let collection_felt: felt252 = (*self.collection_address).try_into().unwrap();
    state = state.update_with(collection_felt);
    let nft_id_felt: felt252 = (*self.nft_id).try_into().unwrap();
    state = state.update_with(nft_id_felt);
    state.finalize()
  }
}

pub impl StructHashBid of IStructHash<Bid> {
  fn get_struct_hash(self: @Bid) -> felt252 {
    let mut state = PoseidonTrait::new();
    state = state.update_with(BID_TYPE_HASH);
    let bidder_felt: felt252 = (*self).bidder.into();
    state = state.update_with(bidder_felt);
    state = state.update_with(self.amount.get_struct_hash());
    let nonce_felt: felt252 = (*self.nonce).into();
    state = state.update_with(nonce_felt);
    state = state.update_with((*self.auction_sig_hash).get_struct_hash());
    state.finalize()
  }
}

pub impl StructHashAuction of IStructHash<Auction> {
	fn get_struct_hash(self: @Auction) -> felt252 {
		let mut state = PoseidonTrait::new();
		state = state.update_with(AUCTION_TYPE_HASH);
		state = state.update_with(*self.auctioneer.into());
		state = state.update_with(*self.auctioneer_nonce.into());
		state = state.update_with(self.nft.get_struct_hash());
		state = state.update_with(self.min_bid.get_struct_hash());
		state = state.update_with(*self.deadline.into());
		state = state.update_with((*self.auction_sig_hash).get_struct_hash());
		state = state.update_with(self.bids.get_struct_hash());
		state = state.update_with(self.bid_sigs.get_struct_hash());
		state.finalize()
	}
}

pub impl StructHashAuctionAuth of IStructHash<AuctionAuth> {
    fn get_struct_hash(self: @AuctionAuth) -> felt252 {
        let mut state = PoseidonTrait::new();
        state = state.update_with(AUCTION_AUTH_TYPE_HASH);
        state = state.update_with(*self.auctioneer.into());
        state = state.update_with(*self.auctioneer_nonce.into());
        state = state.update_with(self.nft.get_struct_hash());
        state = state.update_with(self.min_bid.get_struct_hash());
        state = state.update_with(*self.deadline.into());
        state.finalize()
    }
}

pub impl StructHashSpanBid of IStructHash<Span<Bid>> {
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

pub impl StructHashSpanFelt252 of IStructHash<Span<felt252>> {
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

pub impl StructHashSpanEcdsaSignature of IStructHash<Span<EcdsaSignature>> {
    fn get_struct_hash(self: @Span<EcdsaSignature>) -> felt252 {
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

pub impl StructHashSpanSpanEcdsaSignature of IStructHash<Span<Span<EcdsaSignature>>> {
    fn get_struct_hash(self: @Span<Span<EcdsaSignature>>) -> felt252 {
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

#[starknet::interface]
pub trait IScarabSign<TContractState> {
  fn consume_auction(
    ref self: TContractState,
    auction: Auction,
    signature_r: felt252,
    signature_s: felt252
  );
}

#[starknet::contract]
pub mod ScarabSign {

  use core::starknet::ContractAddress;
  use openzeppelin_account::interface::{ISRC6Dispatcher, ISRC6DispatcherTrait};
  use super::{Auction, IOffChainMessageHash, TokenAmount,NftId};
  use starknet::storage::{
      Map, StorageMapReadAccess, StorageMapWriteAccess,
      
  };
  use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
  use openzeppelin_token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
  use core::traits::{Into, TryInto };
  use core::option::OptionTrait;
  use core::array::SpanTrait;

  #[event]
  #[derive(Drop, starknet::Event)]
  pub enum Event {
    AuctionConsumed: AuctionConsumed,
  }

  #[derive(Drop, starknet::Event)]
  pub struct AuctionConsumed {
    nft: NftId,
    token: ContractAddress,
    amount: u256,
    auctioneer: ContractAddress,
    winner: ContractAddress
  }

  #[storage]
  pub struct Storage {
    used_nonces: Map<(ContractAddress, u64), bool>
  }

  #[abi(embed_v0)]
  pub impl ScarabSign of super::IScarabSign<ContractState> {
    fn consume_auction(
      ref self: ContractState,
      auction: Auction,
      signature_r: felt252,
      signature_s: felt252
    ) {
        // Create AuctionAuth from Auction
        let auction_auth = super::AuctionAuth {
            auctioneer: auction.auctioneer,
            auctioneer_nonce: auction.auctioneer_nonce,
            nft: auction.nft,
            min_bid: auction.min_bid,
            deadline: auction.deadline
        };
        
        // Get the auction auth hash for signature verification
        let auction_auth_hash = auction_auth.get_message_hash();

        // Verify the signature is from the auctioneer's account (SNIP-6 is_valid_signature,
        // not raw ECDSA - an account's address is not its signing public key).
        let auctioneer_response = ISRC6Dispatcher { contract_address: auction.auctioneer }
            .is_valid_signature(auction_auth_hash, array![signature_r, signature_s]);
        let is_valid = auctioneer_response == starknet::VALIDATED || auctioneer_response == 1;
        assert(is_valid, 'Invalid signature');

        // Check auction deadline
        let block_timestamp = starknet::get_block_timestamp();
        assert(block_timestamp <= auction.deadline.into(), 'Auction expired');

        // Check that nonce hasn't been used
        let nonce_used = self.used_nonces.read((auction.auctioneer, auction.auctioneer_nonce));
        assert(!nonce_used, 'Nonce already used');

        // Mark nonce as used
        self.used_nonces.write((auction.auctioneer, auction.auctioneer_nonce), true);
        
        // Process bids from highest to lowest
        // Store valid bids in order
        let mut valid_bids: Array<(ContractAddress, TokenAmount)> = ArrayTrait::new();
        let mut i: usize = 0;
        
        loop {
            if i >= auction.bids.len() {
                break;
            }

            let bid = *auction.bids.at(i);
            let bid_sigs = *auction.bid_sigs.at(i);
            
            // Get first signature from the span
            let bid_sig = *bid_sigs.at(0);

            // Skip if bid amount is less than minimum
            let bid_amount: u128 = bid.amount.amount.try_into().unwrap();
            let min_amount: u128 = auction.min_bid.amount.try_into().unwrap();
            
            if bid_amount >= min_amount {
                // Check if bid nonce already used
                let bid_nonce_used = self.used_nonces.read((bid.bidder, bid.nonce.into()));
                
                if !bid_nonce_used {
                    // Verify bid signature against the bidder's account (SNIP-6
                    // is_valid_signature, not raw ECDSA - see the auctioneer check above).
                    let bid_hash = bid.get_message_hash();

                    let bidder_response = ISRC6Dispatcher { contract_address: bid.bidder }
                        .is_valid_signature(bid_hash, array![bid_sig.r, bid_sig.s]);
                    let is_valid = bidder_response == starknet::VALIDATED || bidder_response == 1;

                    if is_valid {
                        // Add to valid bids array
                        valid_bids.append((bid.bidder, bid.amount));
                        // Mark bid nonce as used
                        self.used_nonces.write((bid.bidder, bid.nonce.into()), true);
                    }
                }
            }
            
            i += 1;
        };


        // Sort valid_bids by amount (highest first)
        // Note: Implement sorting logic here

        // Try each bid until one succeeds
        let mut successful_bid: Option<(ContractAddress, TokenAmount)> = Option::None;
        let mut j: usize = 0;

        loop {
            if j >= valid_bids.len() {
                break;
            }

            let (bidder, amount) = *valid_bids.at(j);
            
            // Try to transfer tokens from bidder
            let token_contract = IERC20Dispatcher { contract_address: amount.token_address };
            // Will panic on failure, no need to handle Result
            token_contract.transfer_from(bidder, auction.auctioneer, amount.amount);
            successful_bid = Option::Some((bidder, amount));
            j += 1;
            break;
            
        };
        
        match successful_bid {
            Option::Some((winner, amount)) => {
                // Transfer NFT to winner
                let nft_contract = IERC721Dispatcher { contract_address: auction.nft.collection_address };
                nft_contract.transfer_from(auction.auctioneer, winner, auction.nft.nft_id);

                // Emit event
                self.emit(Event::AuctionConsumed(AuctionConsumed {
                    nft: auction.nft,
                    token: amount.token_address,
                    amount: amount.amount,
                    auctioneer: auction.auctioneer,
                    winner: winner
                }));
            },
            Option::None => {
                // No valid bids with sufficient funds
                assert(false, 'No valid bids with funds');
            }
        }
    }
  }
}
