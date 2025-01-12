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

#[derive(Drop, Copy, Hash, Serde)]
struct TokenAmount {
  token_address: ContractAddress,
  amount: u256
}

#[derive(Drop, Copy, Hash, Serde)]
struct NftId {
  collection_address: ContractAddress,
  nft_id: u256
}

#[derive(Drop, Copy, Hash, Serde)]
struct Bid {
  bidder: ContractAddress,
  amount: TokenAmount,
  nonce: u64,
  auction_sig_hash: felt252,
}

#[derive(Drop, Copy, Serde)]
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
  fn consume_auction(
    ref self: TContractState,
    auction: Auction,
    signature_r: felt252,
    signature_s: felt252
  ) {}
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

  #[event]
  #[derive(Drop, starknet::Event)]
  enum Event {
    AuctionConsumed: AuctionConsumed,
  }
  
  #[derive(Drop, starknet::Event)]
  struct AuctionConsumed {
    nft: NftId,
    token: ContractAddress,
    amount: u256,
    auctioneer: ContractAddress,
    winner: ContractAddress
  }

  #[storage]
  struct Storage {
    used_nonces: Map<(ContractAddress, u64), bool>
  }

  #[abi(embed_v0)]
  impl ScarabSign of super::IScarabSign<ContractState> {
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
        
        // Check deadline
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
        let mut highest_bid: Option<(ContractAddress, TokenAmount)> = Option::None;
        let mut i: usize = 0;
        
        loop {
            if i >= auction.bids.len() {
                break;
            }

            let bid = *auction.bids.at(i);
            let bid_sig = *auction.bid_sigs.at(i);

            // Skip if bid amount is less than minimum
            if bid.amount.amount >= auction.min_bid.amount {
                // Check if bid nonce already used
                let bid_nonce_used = self.used_nonces.read((bid.bidder, bid.nonce.into()));
                
                if !bid_nonce_used {
                    // Verify bid signature
                    let bid_hash = bid.get_message_hash();
                    let is_valid = check_ecdsa_signature(
                        bid_hash,
                        bid.bidder.into(),
                        bid_sig,  // r component
                        bid_sig   // s component - you'll need to split the signature
                    );

                    if is_valid {
                        // Update highest bid if this is higher
                        match highest_bid {
                            Option::Some((_, current_highest)) => {
                                if bid.amount.amount > current_highest.amount {
                                    highest_bid = Option::Some((bid.bidder, bid.amount));
                                }
                            },
                            Option::None => {
                                highest_bid = Option::Some((bid.bidder, bid.amount));
                            }
                        }

                        // Mark bid nonce as used
                        self.used_nonces.write((bid.bidder, bid.nonce.into()), true);
                    }
                }
            }
            
            i += 1;
        };

        // Process winning bid
        match highest_bid {
            Option::Some((winner, amount)) => {
                // Here you would:
                // 1. Transfer NFT to winner
                // 2. Transfer tokens to auctioneer
                // 3. Emit event
                // Implementation depends on your token interfaces
                self.emit(AuctionConsumed {
                    nft: auction.nft,
                    token: amount.token_address,
                    amount: amount.amount,
                    auctioneer: auction.auctioneer,
                    winner: winner
                });
            },
            Option::None => {
                // No valid bids above minimum
                assert(false, 'No valid bids');
            }
        }
    }
  }
}
