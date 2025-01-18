use starknet::ClassHash;
use sncast_std::{
    declare, deploy, get_nonce, 
    DeclareResult, DeployResult, DeclareResultTrait,
    FeeSettings, EthFeeSettings
};

fn main() {
    // Set deployment parameters
    let max_fee = 999999999999999;
    let salt = 0x3;

    // Get nonce for declare
    let declare_nonce = get_nonce('latest');
    
    let declare_result = declare(
        "ScarabSign",
        FeeSettings::Eth(EthFeeSettings { max_fee: Option::Some(max_fee) }),
        Option::Some(declare_nonce)
    ).expect('declare failed');

    match declare_result {
        DeclareResult::Success(result) => {
            println!("Contract declared successfully");
            println!("Class hash: {:?}", result.class_hash);
            println!("Transaction hash: {:?}", result.transaction_hash);

            // Get nonce for deploy
            let deploy_nonce = get_nonce('pending');

            let deploy_result: DeployResult = deploy(
                result.class_hash,
                ArrayTrait::new(), // No constructor arguments
                Option::Some(salt),
                true, // Unique
                FeeSettings::Eth(EthFeeSettings { max_fee: Option::Some(max_fee) }),
                Option::Some(deploy_nonce)
            ).expect('deploy failed');

            println!("Contract deployed successfully");
            println!("Contract address: {:?}", deploy_result.contract_address);
            println!("Transaction hash: {:?}", deploy_result.transaction_hash);
        },
        DeclareResult::AlreadyDeclared(result) => {
            println!("Contract already declared");
            println!("Class hash: {:?}", result.class_hash);

            // Get nonce for deploy
            let deploy_nonce = get_nonce('pending');

            let deploy_result: DeployResult = deploy(
                result.class_hash,
                ArrayTrait::new(), // No constructor arguments
                Option::Some(salt),
                true, // Unique
                FeeSettings::Eth(EthFeeSettings { max_fee: Option::Some(max_fee) }),
                Option::Some(deploy_nonce)
            ).expect('deploy failed');

            println!("Contract deployed successfully");
            println!("Contract address: {:?}", deploy_result.contract_address);
            println!("Transaction hash: {:?}", deploy_result.transaction_hash);
        }
    }
}
