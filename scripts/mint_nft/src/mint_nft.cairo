use starknet::ContractAddress;
use sncast_std::{invoke, InvokeResult, get_nonce, FeeSettings, EthFeeSettings};


const AUCTIONEER: felt252 =
    0x00238492da986358805a85d97af467e162509fda4e5736737a8ff68380766223;

fn main() {
    let mock_erc721_address = starknet::contract_address_const::<0x064f4cbef551b0d9eabf29439ce4bba23548b33f5d3d91dda35acc0ffe2a853e>();
    let max_fee = 999999999999999;
    let salt = 0x3;
    
    // Create u256 for token ID 1
    let token_id = u256 { low: 1_u128, high: 0_u128 };
    let token_id_low: felt252 = token_id.low.into();
    let token_id_high: felt252 = token_id.high.into();
    
    let invoke_nonce = get_nonce('latest');
    let invoke_result = invoke(
        mock_erc721_address,
        selector!("mint"),
        array![AUCTIONEER, token_id_low, token_id_high],
        FeeSettings::Eth(EthFeeSettings { max_fee: Option::Some(max_fee) }),
        Option::Some(invoke_nonce)
    ).expect('invoke failed');

    println!("Invoke nonce: {}", invoke_nonce);
    println!("Invoke result: {}", invoke_result);
}
