use core::hash::{HashStateExTrait, HashStateTrait};
use core::pedersen::PedersenTrait;

pub trait IOffChainMessageHash<T> {
	fn get_message_hash(self: @T) -> felt252;
}

pub trait IStructHash<T> {
	fn get_struct_hash(self: @T) -> felt252;
}


pub mod v0 {
	use core::hash::{HashStateExTrait, HashStateTrait};
	use core::pedersen::PedersenTrait;

	#[derive(Copy, Drop, Hash)]
	pub struct StarkNetDomain {
		name: felt252,
		version: felt252,
		chain_id: felt252,
	}

	const STARKNET_DOMAIN_TYPE_HASH: felt252 =
		selector!("StarkNetDomain(name:felt,version:felt,chainId:felt)");

	impl StructHashStarkNetDomain of super::IStructHash<StarkNetDomain> {
		fn get_struct_hash(self: @StarkNetDomain) -> felt252 {
			PedersenTrait::new(0)
				.update_with(STARKNET_DOMAIN_TYPE_HASH)
				.update_with(*self)
				.update_with(4)
				.finalize()
		}
	}
}
