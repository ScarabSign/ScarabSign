#[cfg(test)]
mod test_scarab_sign {
    use starknet::ContractAddress;
    use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
    use core::array::ArrayTrait;
    use core::result::ResultTrait;
    use core::traits::TryInto;
    use core::poseidon::PoseidonTrait;
    use core::hash::{HashStateTrait, HashStateExTrait};
    use scarab_sign::snip_12::IStructHash;
    use scarab_sign::scarab_sign::{U256_TYPE_HASH, StructHashU256, TokenAmount, TOKEN_AMOUNT_TYPE_HASH};

    #[starknet::interface]
    trait IScarabSignDispatcher<TContractState> {
        fn consume_auction(
            ref self: TContractState,
            auction: ContractAddress,
            signature_r: felt252,
            signature_s: felt252
        );
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
