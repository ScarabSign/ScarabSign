use core::starknet::ContractAddress;
use core::poseidon::PoseidonTrait;
use core::hash::{HashStateTrait, HashStateExTrait};
use core::array::SpanTrait;

const AUCTIONEER: felt252 =
    0x00238492da986358805a85d97af467e162509fda4e5736737a8ff68380766223;

pub trait IOffChainMessageHash<T> {
	fn get_message_hash(self: @T) -> felt252;
}

pub trait IStructHash<T> {
	fn get_struct_hash(self: @T) -> felt252;
}

pub mod v1 {
	use core::poseidon::poseidon_hash_span;

  #[derive(Hash, Drop, Copy)]
  pub struct StarknetDomain {
    pub name: felt252,
    pub version: felt252,
    pub chain_id: felt252,
    pub revision: felt252,
	}

	const STARKNET_DOMAIN_TYPE_HASH: felt252 =
		selector!(
      "\"StarknetDomain\"(\"name\":\"shortstring\",\"version\":\"shortstring\",\"chainId\":\"shortstring\",\"revision\":\"shortstring\")"
    );

	impl StructHashStarknetDomain of super::IStructHash<StarknetDomain> {
		fn get_struct_hash(self: @StarknetDomain) -> felt252 {
			poseidon_hash_span(
				array![
					STARKNET_DOMAIN_TYPE_HASH,
					*self.name,
					*self.version,
					*self.chain_id,
					*self.revision
				].span()
			)
		}
	}
}


pub const SIGNATURE_TYPE_HASH: felt252 = 
  selector!("\"Signature\"(\"r\":\"felt252\",\"s\":\"felt252\")");

pub const U256_TYPE_HASH: felt252 = 
	selector!("\"u256\"(\"low\":\"u128\",\"high\":\"u128\")");

pub const TOKEN_AMOUNT_TYPE_HASH: felt252 = 
	selector!("\"TokenAmount\"(\"token_address\":\"ContractAddress\",\"amount\":\"u256\")");

pub const NFT_ID_TYPE_HASH: felt252 = 
	selector!("\"NftId\"(\"collection_address\":\"ContractAddress\",\"nft_id\":\"u256\")\"u256\"(\"low\":\"u128\",\"high\":\"u128\")");

pub const BID_TYPE_HASH: felt252 = 
	selector!("\"Bid\"(\"bidder\":\"ContractAddress\",\"amount\":\"TokenAmount\",\"nonce\":\"u64\",\"auction_sig_hash\":\"felt252\")\"TokenAmount\"(\"token_address\":\"ContractAddress\",\"amount\":\"u256\")");

pub const AUCTION_TYPE_HASH: felt252 = 
	selector!("\"Auction\"(\"auctioneer\":\"ContractAddress\",\"auctioneer_nonce\":\"u64\",\"nft\":\"NftId\",\"min_bid\":\"TokenAmount\",\"deadline\":\"u64\",\"auction_sig_hash\":\"felt252\",\"bids\":\"Bid*\",\"bid_sigs\":\"felt252*\")\"Bid\"(\"bidder\":\"ContractAddress\",\"amount\":\"TokenAmount\",\"nonce\":\"u64\",\"auction_sig_hash\":\"felt252\")\"NftId\"(\"collection_address\":\"ContractAddress\",\"nft_id\":\"u256\")\"TokenAmount\"(\"token_address\":\"ContractAddress\",\"amount\":\"u256\")\"u256\"(\"low\":\"u128\",\"high\":\"u128\")");

pub const AUCTION_AUTH_TYPE_HASH: felt252 = 
    selector!("\"AuctionAuth\"(\"auctioneer\":\"ContractAddress\",\"auctioneer_nonce\":\"u64\",\"nft\":\"NftId\",\"min_bid\":\"TokenAmount\",\"deadline\":\"u64\")\"NftId\"(\"collection_address\":\"ContractAddress\",\"nft_id\":\"u256\")\"TokenAmount\"(\"token_address\":\"ContractAddress\",\"amount\":\"u256\")\"u256\"(\"low\":\"u128\",\"high\":\"u128\")");

// Add Katana chain ID constant
const KATANA_CHAIN_ID: felt252 = 0x4b4154414e41;
const SN_SEPOLIA: felt252 = 0x534e5f5345504f4c4941;
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
		let domain = v1::StarknetDomain {
			name: 'scarab_auction', 
			version: '1', 
			chain_id: SN_SEPOLIA,
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
		let domain = v1::StarknetDomain {
			name: 'scarab_auction', 
			version: '1', 
			chain_id: SN_SEPOLIA,
			revision: 1
		};
		let mut state = PoseidonTrait::new();
		state = state.update_with(AUCTION_TYPE_HASH);
		state = state.update_with(domain.get_struct_hash());
		state = state.update_with(AUCTIONEER);
		state = state.update_with(self.get_struct_hash());
		state.finalize()
	}
}

impl OffChainMessageHashAuctionAuth of IOffChainMessageHash<AuctionAuth> {
    fn get_message_hash(self: @AuctionAuth) -> felt252 {
        let domain = v1::StarknetDomain {
            name: 'scarab_auction', 
            version: '1', 
            chain_id: SN_SEPOLIA,
            revision: 1
        };
        let mut state = PoseidonTrait::new();
        state = state.update_with(AUCTION_AUTH_TYPE_HASH);
        state = state.update_with(domain.get_struct_hash());
        state = state.update_with(AUCTIONEER);
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
