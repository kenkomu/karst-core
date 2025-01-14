// *************************************************************************
//                              PUBLICATION CONTRACT TEST
// *************************************************************************
use core::option::OptionTrait;
use core::starknet::SyscallResultTrait;
use core::result::ResultTrait;
use core::traits::{TryInto, Into};
use starknet::{ContractAddress, class_hash::ClassHash};
use snforge_std::{declare, ContractClassTrait, CheatTarget, start_prank, stop_prank};

use token_bound_accounts::interfaces::IAccount::{IAccountDispatcher, IAccountDispatcherTrait};
use token_bound_accounts::presets::account::Account;
use karst::mocks::registry::Registry;
use karst::interfaces::IRegistry::{IRegistryDispatcher, IRegistryDispatcherTrait};
use karst::karstnft::karstnft::KarstNFT;
use karst::interfaces::IKarstNFT::{IKarstNFTDispatcher, IKarstNFTDispatcherTrait};
use karst::interfaces::IProfile::{IKarstProfileDispatcher, IKarstProfileDispatcherTrait};
use karst::publication::publication::Publications;
use karst::interfaces::IPublication::{
    IKarstPublicationsDispatcher, IKarstPublicationsDispatcherTrait
};
use karst::base::types::{PostParams, ReferencePubParams, PublicationType};

const HUB_ADDRESS: felt252 = 'HUB';
const USER_ONE: felt252 = 'BOB';
const USER_TWO: felt252 = 'ALICE';

// *************************************************************************
//                              SETUP 
// *************************************************************************
fn __setup__() -> (
    ContractAddress,
    ContractAddress,
    ContractAddress,
    ContractAddress,
    felt252,
    felt252,
    ContractAddress,
    ContractAddress,
    u256,
) {
    // deploy NFT
    let nft_contract = declare("KarstNFT").unwrap();
    let names: ByteArray = "KarstNFT";
    let symbol: ByteArray = "KNFT";
    let base_uri: ByteArray = "ipfs://QmSkDCsS32eLpcymxtn1cEn7Rc5hfefLBgfvZyjaYXr4gQ/";
    let mut calldata: Array<felt252> = array![USER_ONE];
    names.serialize(ref calldata);
    symbol.serialize(ref calldata);
    base_uri.serialize(ref calldata);
    let (nft_contract_address, _) = nft_contract.deploy(@calldata).unwrap_syscall();

    // deploy registry
    let registry_class_hash = declare("Registry").unwrap();
    let (registry_contract_address, _) = registry_class_hash.deploy(@array![]).unwrap_syscall();

    // deploy profile
    let profile_contract = declare("KarstProfile").unwrap();
    let mut karst_profile_constructor_calldata = array![HUB_ADDRESS];
    let (profile_contract_address, _) = profile_contract
        .deploy(@karst_profile_constructor_calldata)
        .unwrap();

    // deploy publication
    let publication_contract = declare("Publications").unwrap();
    let mut publication_constructor_calldata = array![];
    let (publication_contract_address, _) = publication_contract
        .deploy(@publication_constructor_calldata)
        .unwrap_syscall();

    // declare account
    let account_class_hash = declare("Account").unwrap();

    // ///// Deploying karst account for USER AND USE
    let profile_dispatcher = IKarstProfileDispatcher { contract_address: profile_contract_address };
    let publication_dispatcher = IKarstPublicationsDispatcher {
        contract_address: publication_contract_address
    };
    start_prank(
        CheatTarget::Multiple(array![publication_contract_address, profile_contract_address]),
        USER_ONE.try_into().unwrap()
    );
    let user_one_profile_address = profile_dispatcher
        .create_profile(
            nft_contract_address,
            registry_class_hash.class_hash.into(),
            account_class_hash.class_hash.into(),
            2478,
            USER_ONE.try_into().unwrap()
        );
    profile_dispatcher
        .set_profile_metadata_uri(
            user_one_profile_address.try_into().unwrap(),
            "ipfs://QmSkDCsS32eLpcymxtn1cEn7Rc5hfefLBgfvZyjaYXr4ga/"
        );
    let contentURI: ByteArray = "ipfs://helloworld";
    let user_one_first_post_pointed_pub_id = publication_dispatcher
        .post(contentURI, user_one_profile_address, profile_contract_address);
    stop_prank(
        CheatTarget::Multiple(array![publication_contract_address, profile_contract_address]),
    );

    start_prank(
        CheatTarget::Multiple(array![publication_contract_address, profile_contract_address]),
        USER_TWO.try_into().unwrap()
    );
    let user_two_profile_address = profile_dispatcher
        .create_profile(
            nft_contract_address,
            registry_class_hash.class_hash.into(),
            account_class_hash.class_hash.into(),
            2479,
            USER_TWO.try_into().unwrap()
        );
    profile_dispatcher
        .set_profile_metadata_uri(
            user_two_profile_address.try_into().unwrap(),
            "ipfs://QmSkDCsS32eLpcymxtn1cEn7Rc5hfefLBgfvZyjaYXr4ga/"
        );
    let contentURI: ByteArray = "ipfs://helloworld";
    publication_dispatcher.post(contentURI, user_two_profile_address, profile_contract_address);
    stop_prank(
        CheatTarget::Multiple(array![publication_contract_address, profile_contract_address]),
    );

    return (
        nft_contract_address,
        registry_contract_address,
        profile_contract_address,
        publication_contract_address,
        registry_class_hash.class_hash.into(),
        account_class_hash.class_hash.into(),
        user_one_profile_address,
        user_two_profile_address,
        user_one_first_post_pointed_pub_id,
    );
}

// *************************************************************************
//                              TEST
// *************************************************************************

#[test]
fn test_post() {
    let (
        _,
        _,
        profile_contract_address,
        publication_contract_address,
        _,
        _,
        user_one_profile_address,
        _,
        user_one_first_post_pointed_pub_id,
    ) =
        __setup__();
    let publication_dispatcher = IKarstPublicationsDispatcher {
        contract_address: publication_contract_address
    };
    start_prank(
        CheatTarget::Multiple(array![publication_contract_address, profile_contract_address]),
        USER_ONE.try_into().unwrap()
    );

    let publication_type = publication_dispatcher
        .get_publication_type(user_one_profile_address, user_one_first_post_pointed_pub_id);
    assert(publication_type == PublicationType::Post, 'invalid pub_type');

    stop_prank(
        CheatTarget::Multiple(array![publication_contract_address, profile_contract_address]),
    );
}

#[test]
fn test_comment() {
    let (
        _,
        _,
        profile_contract_address,
        publication_contract_address,
        _,
        _,
        user_one_profile_address,
        user_two_profile_address,
        user_one_first_post_pointed_pub_id,
    ) =
        __setup__();
    let publication_dispatcher = IKarstPublicationsDispatcher {
        contract_address: publication_contract_address
    };
    start_prank(
        CheatTarget::Multiple(array![publication_contract_address, profile_contract_address]),
        USER_ONE.try_into().unwrap()
    );
    let user_one_comment_on_his_post_content_URI =
        "ipfs://QmSkDCsS32eLpcymxtn1cEn7Rc5hfefLBgfvZyjaryrga/";
    let user_two_comment_one_user_one_post_content_URI =
        "ipfs://QmSkDCsS32eLpcymxtn1cEn7Rc5hfefLBgfvZysddewga/";

    // user comment on his own post
    let user_one_comment_assigned_pub_id_1 = publication_dispatcher
        .comment(
            user_one_profile_address,
            user_one_comment_on_his_post_content_URI,
            user_one_profile_address,
            user_one_first_post_pointed_pub_id,
            profile_contract_address
        );
    // user two comment on user_one_post
    let user_two_comment_on_user_one_assigned_pub_id_2 = publication_dispatcher
        .comment(
            user_two_profile_address,
            user_two_comment_one_user_one_post_content_URI,
            user_one_profile_address,
            user_one_first_post_pointed_pub_id,
            profile_contract_address
        );

    let user_one_publication_root_id = publication_dispatcher
        .get_publication(user_one_profile_address, user_one_comment_assigned_pub_id_1)
        .root_profile_address;
    let user_two_comment_publication_root_id = publication_dispatcher
        .get_publication(user_two_profile_address, user_two_comment_on_user_one_assigned_pub_id_2)
        .root_profile_address;
    let publication_type = publication_dispatcher
        .get_publication_type(user_one_profile_address, user_one_comment_assigned_pub_id_1);
    assert(publication_type == PublicationType::Comment, 'invalid pub_type');
    assert(user_one_publication_root_id == user_two_comment_publication_root_id, 'Invalid root_id');

    stop_prank(
        CheatTarget::Multiple(array![publication_contract_address, profile_contract_address]),
    );
}


fn to_address(name: felt252) -> ContractAddress {
    name.try_into().unwrap()
}
