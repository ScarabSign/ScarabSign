use starknet::ContractAddress;
use sncast_std::{invoke, InvokeResult, get_nonce, FeeSettings, EthFeeSettings};


const BIDDER: felt252 =
    0x07d3126eb99d185ec8bb44c9a59fc187222ac99835b78ccba572e1dd15d830c0;

fn main() {
    let mock_erc20_address = starknet::contract_address_const::<0x05b726cfeaf1e97aa9e742ba910e38b2efa3d2bba4e48740c967e201b456d429>();
    let max_fee = 999999999999999;
    let salt = 0x3;
    
    // Create u256 for token ID 1
    let amount = u256 { low: 1618_u128, high: 0_u128 };
    let amount_low: felt252 = amount.low.into();
    let amount_high: felt252 = amount.high.into();
    
    let invoke_nonce = get_nonce('latest');
    let invoke_result = invoke(
        mock_erc20_address,
        selector!("mint"),
        array![BIDDER, amount_low, amount_high],
        FeeSettings::Eth(EthFeeSettings { max_fee: Option::Some(max_fee) }),
        Option::Some(invoke_nonce)
    ).expect('invoke failed');

    println!("Invoke nonce: {}", invoke_nonce);
    println!("Invoke result: {}", invoke_result);
}
