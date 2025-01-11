use core::starknet::eth_address::EthAddress;
use core::starknet::ContractAddress;
use starknet::secp256_trait::{Signature};
use starknet::{get_tx_info, get_caller_address};
use core::pedersen::PedersenTrait;
use core::poseidon::PoseidonTrait;
use core::hash::{HashStateTrait, HashStateExTrait};
use crate::snip_12::{IOffChainMessageHash, IStructHash, v1::StarknetDomain};

const U256_TYPE_HASH: felt252 = 
	selector!("\"u256\"(\"low\":\"u128\",\"high\":\"u128\")");

const TOKEN_AMOUNT_TYPE_HASH: felt252 = 
	selector!("\"TokenAmount\"(\"token_address\":\"ContractAddress\",\"amount\":\"u256\")\"u256\"(\"low\":\"u128\",\"high\":\"u128\")");

const NFT_ID_TYPE_HASH: felt252 = 
	selector!("\"NftId\"(\"collection_address\":\"ContractAddress\",\"nft_id\":\"u256\")\"u256\"(\"low\":\"u128\",\"high\":\"u128\")");

const BID_TYPE_HASH: felt252 = 
	selector!("\"Bid\"(\"bidder\":\"ContractAddress\",\"amount\":\"TokenAmount\",\"nonce\":\"u64\",\"auction_sig_hash\":\"felt252\")\"TokenAmount\"(\"token_address\":\"ContractAddress\",\"amount\":\"u256\")\"u256\"(\"low\":\"u128\",\"high\":\"u128\")");

const AUCTION_TYPE_HASH: felt252 = 
	selector!("\"Auction\"(\"auctioneer\":\"ContractAddress\",\"auctioneer_nonce\":\"u64\",\"nft\":\"NftId\",\"min_bid\":\"TokenAmount\",\"deadline\":\"u64\",\"auction_sig_hash\":\"felt252\",\"bids\":\"Bid*\",\"bid_sigs\":\"felt252*\")\"Bid\"(\"bidder\":\"ContractAddress\",\"amount\":\"TokenAmount\",\"nonce\":\"u64\",\"auction_sig_hash\":\"felt252\")\"NftId\"(\"collection_address\":\"ContractAddress\",\"nft_id\":\"u256\")\"TokenAmount\"(\"token_address\":\"ContractAddress\",\"amount\":\"u256\")\"u256\"(\"low\":\"u128\",\"high\":\"u128\")");

#[derive(Drop, Copy, Hash)]
struct TokenAmount {
  token_address: ContractAddress,
  amount: u256
}

#[derive(Drop, Copy, Hash)]
struct NftId {
  collection_address: ContractAddress,
  nft_id: u256
}

#[derive(Drop, Copy, Hash)]
struct Bid {
  bidder: ContractAddress,
  amount: TokenAmount,
  nonce: u64,
  auction_sig_hash: felt252,
}

#[derive(Drop, Copy)]
struct Auction {
  auctioneer: ContractAddress,
  auctioneer_nonce: u64,
  nft: NftId,
  min_bid: TokenAmount,
  deadline: u64,
  auction_sig_hash: felt252,
  bids: Span<Bid>,
  bid_sigs: Span<felt252>,
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
		state = state.update_with('StarkNet Message');
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
		state = state.update_with('StarkNet Message');
		state = state.update_with(domain.get_struct_hash());
		state = state.update_with(get_caller_address());
		state = state.update_with(self.get_struct_hash());
		state.finalize()
	}
}

impl StructHashU256 of IStructHash<u256> {
  fn get_struct_hash(self: @u256) -> felt252 {
    let mut state = PoseidonTrait::new();
    state = state.update_with(U256_TYPE_HASH);
    state = state.update_with(*self);
    state.finalize()
  }

}

impl StructHashTokenAmount of IStructHash<TokenAmount> {
  fn get_struct_hash(self: @TokenAmount) -> felt252 {
    let mut state = PoseidonTrait::new();
    state = state.update_with(TOKEN_AMOUNT_TYPE_HASH);
    state = state.update_with(*self.token_address.into());
    state = state.update_with(self.amount.get_struct_hash());
    state.finalize()
  }
}

impl StructHashNftId of IStructHash<NftId> {
  fn get_struct_hash(self: @NftId) -> felt252 {
    let mut state = PoseidonTrait::new();
    state = state.update_with(NFT_ID_TYPE_HASH);
    state = state.update_with(*self.collection_address.into());
    state = state.update_with(self.nft_id.get_struct_hash());
    state.finalize()
  }
}

impl StructHashBid of IStructHash<Bid> {
  fn get_struct_hash(self: @Bid) -> felt252 {
    let mut state = PoseidonTrait::new();
    state = state.update_with(BID_TYPE_HASH);
    state = state.update_with(*self.bidder.into());
    state = state.update_with(self.amount.get_struct_hash());
    state = state.update_with(*self.nonce.into());
    state = state.update_with(*self.auction_sig_hash);
    state.finalize()
  }
}


impl StructHashAuction of IStructHash<Auction> {
	fn get_struct_hash(self: @Auction) -> felt252 {
		let mut state = PoseidonTrait::new();
		state = state.update_with(AUCTION_TYPE_HASH);
		state = state.update_with(*self.auctioneer.into());
		state = state.update_with(*self.auctioneer_nonce.into());
		state = state.update_with(self.nft.get_struct_hash());
		state = state.update_with(self.min_bid.get_struct_hash());
		state = state.update_with(*self.deadline.into());
		state = state.update_with(*self.auction_sig_hash);
		state = state.update_with(self.bids.get_struct_hash());
		state = state.update_with(self.bid_sigs.get_struct_hash());
		state.finalize()
	}
}

// For handling the Span<Bid>
impl StructHashSpanBid of IStructHash<Span<Bid>> {
	fn get_struct_hash(self: @Span<Bid>) -> felt252 {
		let mut state = PoseidonTrait::new();
		for bid in (*self) {
			state = state.update_with(bid.get_struct_hash());
		};
		state.finalize()
	}
}

// For handling the Span<felt252>
impl StructHashSpanFelt252 of IStructHash<Span<felt252>> {
	fn get_struct_hash(self: @Span<felt252>) -> felt252 {
		let mut state = PoseidonTrait::new();
		for sig in (*self) {
			state = state.update_with(*sig);
		};
		state.finalize()
	}
}

#[starknet::interface]
trait IScarabSign<TContractState> {
  fn get_signature(self: @TContractState, r: u256, s: u256, v: u32) -> Signature;
  fn verify_eth_signature(
    self: @TContractState, eth_address: EthAddress, msg_hash: u256, r: u256, s: u256, v: u32,
    );
  fn recover_public_key(
    self: @TContractState, eth_address: EthAddress, msg_hash: u256, r: u256, s: u256, v: u32,
    );
}

#[starknet::contract]
pub mod ScarabSign {
  use super::IScarabSign;
  use core::starknet::eth_address::EthAddress;
  use starknet::secp256k1::Secp256k1Point;
  use starknet::secp256_trait::{Signature, signature_from_vrs, recover_public_key};
  use starknet::eth_signature::{verify_eth_signature, public_key_point_to_eth_address};

  #[storage]
  struct Storage {
  }

  #[abi(embed_v0)]
  impl ScarabSign of super::IScarabSign<ContractState> {
		fn get_signature(
			self: @ContractState,
      r: u256,
      s: u256,
      v: u32)
    -> Signature {
      let signature: Signature = signature_from_vrs(v, r, s);
      signature
    }
    fn verify_eth_signature(
      self: @ContractState,
      eth_address: EthAddress,
      msg_hash: u256,
      r: u256,
      s: u256,
      v: u32,
    ) {
      let signature = self.get_signature(r, s, v);
      verify_eth_signature(:msg_hash, :signature, :eth_address);
    }

    fn recover_public_key(
      self: @ContractState,
      eth_address: EthAddress,
      msg_hash: u256,
      r: u256,
      s: u256,
      v: u32,
    ) {
      let signature = self.get_signature(r, s, v);
      let public_key_point = recover_public_key::<Secp256k1Point>(msg_hash, signature).unwrap();
      let calculated_eth_address = public_key_point_to_eth_address(:public_key_point);
      assert(calculated_eth_address == eth_address, 'Invalid Address');
    }
  }
}
