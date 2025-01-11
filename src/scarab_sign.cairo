use core::starknet::eth_address::EthAddress;
use core::starknet::ContractAddress
use starknet::secp256_trait::{Signature};
use starknet::{get_tx_info, get_caller_address};
use core::pedersen::PedersenTrait;
use core::hash::{HashStateTrait, HashStateExTrait};
use scarab_sign::snip_12::{IOffChainMessageHash, IStructHash, v0::StarkNetDomain};

const U256_TYPE_HASH=
  selector!("u256(low:u256,high:u256)")

const BID_TYPE_HASH: felt252 = 
  selector!("Bid(bidder:ContractAddress,amount:u256,nonce:u256,auction_sig_hash:felt)" + U256_TYPE_HASH)

const AUCTION_TYPE_HASH: felt252 =
  selector!("Auction(auctioneer:ContractAddress,auctioneer_nonce:u256,nft_address:ContractAddress,nft_id:u256,token_address:ContractAddress,start_time:u64,deadline:u64,auction_sig_hash:felt,bids:Bid*,bid_sigs:felt*)" + BID_TYPE_HASH)


#[derive(Drop, Copy, Hash)]
struct Bid {
  bidder: ContractAddress,
  amount: u256,
  nonce: u256,
  auction_sig_hash: felt252
}

#[derive(Drop, Copy, Hash)]
struct Auction {
  auctioneer: ContractAddress,
  auctioneer_nonce: u256,
  nft_address: ContractAddress,
  nft_id: u256,
  token_address: ContractAddress,
  start_time: u64,
  deadline: u64,
  auction_sig_hash: felt252,
  bids: Span<Bid>,
  bid_sigs: Span<felt252>
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
