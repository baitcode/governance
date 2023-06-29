use governance::token::ITokenDispatcherTrait;
use array::{ArrayTrait};
use debug::PrintTrait;
use governance::airdrop::{
    IAirdropDispatcher, IAirdropDispatcherTrait, Airdrop, Airdrop::compute_pedersen_root, Claim
};
use starknet::{
    get_contract_address, deploy_syscall, ClassHash, contract_address_const, ContractAddress
};
use governance::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use governance::token::{Token, ITokenDispatcher};
use governance::token_test::{deploy as deploy_token};
use starknet::class_hash::Felt252TryIntoClassHash;
use traits::{TryInto, Into};

use result::{Result, ResultTrait};
use option::{OptionTrait};

fn deploy(token: IERC20Dispatcher, root: felt252) -> IAirdropDispatcher {
    let mut constructor_args: Array<felt252> = ArrayTrait::new();
    Serde::serialize(@token, ref constructor_args);
    Serde::serialize(@root, ref constructor_args);

    let (address, _) = deploy_syscall(
        Airdrop::TEST_CLASS_HASH.try_into().unwrap(), 2, constructor_args.span(), true
    )
        .expect('DEPLOY_AD_FAILED');
    return IAirdropDispatcher { contract_address: address };
}

#[test]
#[available_gas(3000000)]
fn test_compute_pedersen_root_example_lt() {
    let mut arr = ArrayTrait::new();
    arr.append(1235);
    assert(
        compute_pedersen_root(
            1234, arr.span()
        ) == 0x24e78083d17aa2e76897f44cfdad51a09276dd00a3468adc7e635d76d432a3b,
        'example'
    );
}

#[test]
#[available_gas(3000000)]
fn test_compute_pedersen_root_example_gt() {
    let mut arr = ArrayTrait::new();
    arr.append(1233);
    assert(
        compute_pedersen_root(
            1234, arr.span()
        ) == 0x2488766c14e4bfd8299750797eeb07b7045398df03ea13cf33f0c0c6645d5f9,
        'example'
    );
}

#[test]
#[available_gas(3000000)]
fn test_compute_pedersen_root_example_eq() {
    let mut arr = ArrayTrait::new();
    arr.append(1234);
    assert(
        compute_pedersen_root(
            1234, arr.span()
        ) == 0x7a7148565b76ae90576733160aa3194a41ce528ee1434a64a9da50dcbf6d3ca,
        'example'
    );
}

#[test]
#[available_gas(3000000)]
fn test_compute_pedersen_root_empty() {
    let mut arr = ArrayTrait::new();
    assert(compute_pedersen_root(1234, arr.span()) == 1234, 'example');
}

#[test]
#[available_gas(3000000)]
fn test_compute_pedersen_root_recursive() {
    let mut arr = ArrayTrait::new();
    arr.append(1234);
    arr.append(1234);
    assert(
        compute_pedersen_root(
            1234, arr.span()
        ) == 0xc92a4f7aa8979b0202770b378e46de07bebe0836f8ceece5a47ccf3929c6b0,
        'example'
    );
}

#[test]
#[available_gas(3000000)]
fn test_claim_single_recipient() {
    let token = deploy_token('AIRDROP', 'AD', 1234567);

    let claimee = contract_address_const::<2345>();
    let amount: u128 = 6789;

    let leaf = pedersen(claimee.into(), amount.into());

    let airdrop = deploy(IERC20Dispatcher { contract_address: token.contract_address }, leaf);

    token.transfer(airdrop.contract_address, 6789);
    let proof = ArrayTrait::new();

    airdrop.claim(Claim { claimee, amount }, proof);
    assert(token.balance_of(airdrop.contract_address) == 0, 'emptied');
    assert(token.balance_of(claimee) == 6789, 'received');
}
