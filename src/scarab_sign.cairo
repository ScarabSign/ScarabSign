use core::starknet::eth_address::EthAddress;
use core::starknet::ContractAddress;
use starknet::secp256_trait::{Signature};
use starknet::{get_tx_info, get_caller_address};
use core::pedersen::PedersenTrait;
use core::poseidon::PoseidonTrait;
use core::hash::{HashStateTrait, HashStateExTrait};
use crate::snip_12::{IOffChainMessageHash, IStructHash, v1::StarknetDomain};
use crate::ERC20::{IERC20Dispatcher, IERC20DispatcherTrait};
use crate::ERC721::{IERC721Dispatcher, IERC721DispatcherTrait};
use core::array::SpanTrait;

pub const SIGNATURE_TYPE_HASH: felt252 = 
  selector!("\"Signature\"(\"r\":\"felt252\",\"s\":\"felt252\")");

pub const U256_TYPE_HASH: felt252 = 
	selector!("\"u256\"(\"low\":\"u128\",\"high\":\"u128\")");

pub const TOKEN_AMOUNT_TYPE_HASH: felt252 = 
	selector!("\"TokenAmount\"(\"token_address\":\"ContractAddress\",\"amount\":\"felt252\")");

pub const NFT_ID_TYPE_HASH: felt252 = 
	selector!("\"NftId\"(\"collection_address\":\"ContractAddress\",\"nft_id\":\"u256\")\"u256\"(\"low\":\"u128\",\"high\":\"u128\")");

pub const BID_TYPE_HASH: felt252 = 
	selector!("\"Bid\"(\"bidder\":\"ContractAddress\",\"amount\":\"TokenAmount\",\"nonce\":\"u64\",\"auction_sig_hash\":\"felt252\")\"TokenAmount\"(\"token_address\":\"ContractAddress\",\"amount\":\"felt252\")");

pub const AUCTION_TYPE_HASH: felt252 = 
	selector!("\"Auction\"(\"auctioneer\":\"ContractAddress\",\"auctioneer_nonce\":\"u64\",\"nft\":\"NftId\",\"min_bid\":\"TokenAmount\",\"deadline\":\"u64\",\"auction_sig_hash\":\"felt252\",\"bids\":\"Bid*\",\"bid_sigs\":\"felt252*\")\"Bid\"(\"bidder\":\"ContractAddress\",\"amount\":\"TokenAmount\",\"nonce\":\"u64\",\"auction_sig_hash\":\"felt252\")\"NftId\"(\"collection_address\":\"ContractAddress\",\"nft_id\":\"u256\")\"TokenAmount\"(\"token_address\":\"ContractAddress\",\"amount\":\"felt252\")\"u256\"(\"low\":\"u128\",\"high\":\"u128\")");

#[derive(Drop, Copy, Hash, Serde)]
pub struct EcdsaSignature {
  pub r: felt252,
  pub s: felt252
}

#[derive(Drop, Copy, Hash, Serde)]
pub struct TokenAmount {
  pub token_address: ContractAddress,
  pub amount: felt252
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
		state = state.update_with(get_caller_address());
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
		state = state.update_with(get_caller_address());
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
    state = state.update_with(*self.bidder.into());
    state = state.update_with(self.amount.get_struct_hash());
    state = state.update_with(*self.nonce.into());
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

  use super::IScarabSign;
  use starknet::secp256k1::Secp256k1Point;
  use core::ecdsa::check_ecdsa_signature;
  use core::starknet::ContractAddress;
  use starknet::get_caller_address;
  use super::{Auction, IOffChainMessageHash, TokenAmount, Bid,NftId};
  use starknet::storage::{
      Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
      StoragePointerWriteAccess,
  };
  use crate::ERC20::{IERC20Dispatcher, IERC20DispatcherTrait};
  use crate::ERC721::{IERC721Dispatcher, IERC721DispatcherTrait};
  use core::traits::{Into, TryInto, PartialEq, PartialOrd};
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
    amount: felt252,
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
        let auction_hash = auction.get_message_hash();
        let is_valid = check_ecdsa_signature(
          auction_hash,
          get_caller_address().into(),
          signature_r,
          signature_s 
        );
        assert(is_valid, 'Invalid signature');

          let block_timestamp = starknet::get_block_timestamp();
        assert(block_timestamp <= auction.deadline.into(), 'Auction expired');

        // Verify auctioneer
        assert(get_caller_address() == auction.auctioneer, 'Only auctioneer');

        // Check if auctioneer nonce is valid
        let nonce_used = self.used_nonces.read((auction.auctioneer, auction.auctioneer_nonce));
        assert(!nonce_used, 'Nonce already used');

        // Mark auctioneer nonce as used
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
            if bid_amount > min_amount {
                // Check if bid nonce already used
                let bid_nonce_used = self.used_nonces.read((bid.bidder, bid.nonce.into()));
                
                if !bid_nonce_used {
                    // Verify bid signature
                    let bid_hash = bid.get_message_hash();
                    let is_valid = check_ecdsa_signature(
                        bid_hash,
                        bid.bidder.into(),
                        bid_sig.r,  // r component
                        bid_sig.s   // s component
                    );

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
            token_contract.transfer_from(bidder, auction.auctioneer, amount.amount);
            // No return value to check, will panic on failure
            successful_bid = Option::Some((bidder, amount));
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
