#[starknet::contract]
mod ReserveData {
    use starknet::{ 
        ContractAddress,
        ClassHash
    };
    
    use starknet::storage::{
        Map,
        StorageMapReadAccess,
        StorageMapWriteAccess,
        StoragePointerWriteAccess,
        StoragePointerReadAccess
    };

    use crate::enums::enums::*;
    use crate::structs::structs::*;
    use crate::interfaces::interfaces::*;
    use crate::event_structs::event_structs::*;
    use crate::utils::utils::*;


    use openzeppelin_access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;


    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);


    #[abi(embed_v0)]
    impl AccessControlImpl = AccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;


    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;



    const ADMIN_ROLE: felt252 = selector!("ADMIN_ROLE");






    #[storage]
    pub struct Storage {

        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,


        // Reserve configuration
        reserve_config: Map<ContractAddress, ReserveConfiguration>,
        
        // Reserve state
        reserve_state: Map<ContractAddress, ReserveState>,
        
        // User positions
        user_reserve_data: Map<(ContractAddress, ContractAddress), UserReserveData>,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {

        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,


        ReserveConfigurationUpdated: ReserveConfigurationUpdated,
        ReserveStateUpdated: ReserveStateUpdated,
        UserReserveDataUpdated: UserReserveDataUpdated
       
    }



    #[constructor]
    fn constructor(
        ref self: ContractState,
        admin_address: ContractAddress,
    ) {

        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(AccessControlComponent::DEFAULT_ADMIN_ROLE, admin_address);
        self.accesscontrol._grant_role(ADMIN_ROLE, admin_address);
    }

   

    #[abi(embed_v0)]
    pub impl ReserveDataImpl of IReserveData<ContractState> {
        fn set_reserve_config(
            ref self: ContractState,
            asset: ContractAddress,
            config: ReserveConfiguration
        ) {
            self.reserve_config.write(asset, config);
        }

        fn get_reserve_config(self: @ContractState, asset: ContractAddress) -> ReserveConfigurationResponse {
            self.reserve_config.read(asset)
        }

        fn set_reserve_state(
            ref self: ContractState,
            asset: ContractAddress,
            state: ReserveState
        ) {
            self.reserve_state.write(asset, state);
        }

        fn get_reserve_state(self: @ContractState, asset: ContractAddress) -> ReserveStateResponse {
            self.reserve_state.read(asset)
        }

        fn set_user_reserve_data(
            ref self: ContractState,
            user: ContractAddress,
            asset: ContractAddress,
            data: UserReserveData
        ) {
            self.user_reserve_data.write((user, asset), data);
        }

        fn get_user_reserve_data(
            self: @ContractState,
            user: ContractAddress,
            asset: ContractAddress
        ) -> UserReserveDataResponse {
            self.user_reserve_data.read((user, asset))
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {

            let caller: ContractAddress = get_caller_address();

            assert!(self.accesscontrol.has_role(ADMIN_ROLE, caller), "AccessControl: Caller is not the Admin");

            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
