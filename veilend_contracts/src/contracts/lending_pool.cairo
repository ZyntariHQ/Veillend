#[starknet::contract]
mod LendingPool {
    use starknet::{
        ContractAddress,
        ClassHash,
        get_caller_address,
        get_contract_address,
        get_block_timestamp
    }
    use openzeppelin_access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;

    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;

    use openzeppelin::security::reentrancyguard::ReentrancyGuardComponent;

    use openzeppelin::security::pausable::PausableComponent;

    use openzeppelin::token::erc20::interface::{ 
        IERC20Dispatcher,
        IERC20DispatcherTrait
    };



    use super::interfaces::IERC20Dispatcher;
    use crate::interfaces::interfaces::IPriceOracleDispatcher;
    use crate::interfaces::interfaces::IReserveDataDispatcher;
    use crate::interfaces::interfaces::IInterestTokenInternalDispatcher;

    use starknet::storage::{
        Map,
        Vec,
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




    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: ReentrancyGuardComponent, storage: reentrancyguard, event: ReentrancyGuardEvent);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);


    
    
    
    #[abi(embed_v0)]
    impl AccessControlImpl = AccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;
    
    impl ReentrancyGuardInternalImpl = ReentrancyGuardComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;

    // self.reentrancyguard.start();
    // self.reentrancyguard.end();
    
    
    // self.pausable.pause(); -> void
    // self.pausable.unpause(); -> void
    // self.pausable.assert_not_paused(); -> bool
    // self.pausable.assert_paused(); -> bool



    const ADMIN_ROLE: felt252 = selector!("ADMIN_ROLE");



    #[storage]
    struct Storage {

        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        reentrancyguard: ReentrancyGuardComponent::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,



        addresses_provider_address: ContractAddress,
        reserve_data_contract_address: ContractAddress,
        price_oracle_contract_address: ContractAddress,
        v_share_token_contract_address: ContractAddress,
        
        // Whitelist for assets
        reserves_list: Vec<ContractAddress>,
        reserves: Map<ContractAddress, bool>,
        
        // Protocol fee collector
        fee_collector_address: ContractAddress
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {

        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        ReentrancyGuardEvent: ReentrancyGuardComponent::Event,
        #[flat]
        PausableEvent: PausableComponent::Event,


        Deposit: Deposit,
        Withdraw: Withdraw,
        Borrow: Borrow,
        Repay: Repay,
        ReserveDataUpdated: ReserveDataUpdated,
    }

   
    #[constructor]
    fn constructor(
        ref self: ContractState,
        admin_address: ContractAddress,
        provider: ContractAddress,
        reserve_data_contract: ContractAddress,
        price_oracle_contract: ContractAddress,
        fee_collector: ContractAddress,
        v_share_token_contract_address: ContractAddress
    ) {
        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(AccessControlComponent::DEFAULT_ADMIN_ROLE, admin_address);
        self.accesscontrol._grant_role(ADMIN_ROLE, admin_address);

        self.addresses_provider_address.write(provider);
        self.reserve_data_contract_address.write(reserve_data_contract);
        self.price_oracle_contract_address.write(price_oracle_contract);
        self.fee_collector_address.write(fee_collector);
        self.v_share_token_contract_address.write(v_share_token_contract_address);
    }

    #[abi(embed_v0)]
    impl LendingPoolImpl of ILendingPool<ContractState> {
        fn deposit(
            ref self: ContractState,
            asset: ContractAddress,
            amount: u256,
            on_behalf_of: ContractAddress
        ) {
            self.pausable.assert_not_paused();
            
            self.reentrancyguard.start();

            // Validate parameters
            assert!(amount > 0_u256, "Amount must be greater than 0");
            assert!(on_behalf_of != 0_u256, "Invalid on_behalf_of address");

            // Get reserve configuration
            let reserve_data_contract_dispatcher: IReserveDataDispatcher = IReserveDataDispatcher {
                contract_address: self.reserve_data_contract_address.read()
            };

            let reserve_config: ReserveConfigurationResponse = reserve_data_contract_dispatcher.get_reserve_config(&asset);

            assert!(reserve_config.is_active, "Reserve not active");

            // Transfer tokens from user
            let token_dispatcher: IERC20Dispatcher = IERC20Dispatcher { contract_address: &asset };

            let caller: ContractAddress = get_caller_address();

            let contract: ContractAddress = get_contract_address();

            let balance: u256 = token_dispatcher.balance_of(&caller);

            assert!(balance >= amount, "Caller doesn't have enough balance");

            let allowance: u256 = token_dispatcher.allowance(&caller, contract);

            assert!(allowance >= amount, "Contract is not allowed to spend enough token");

            let success: bool = token_dispatcher.transfer_from(&caller, contract, amount);

            // Update reserve state
            self._update_reserve_state(&asset, &amount, 0_u256, true);

            // Mint aTokens to user
            let a_token: IERC20Dispatcher = IERC20Dispatcher { contract_address: self.v_share_token_contract_address.read() };
            let reserve_state: ReserveStateResponse = reserve_data_contract_dispatcher.get_reserve_state(&asset);
            a_token.transfer(on_behalf_of, amount);

            // Emit event
            let deposit_event: Deposit = Deposit {
                reserve: asset,
                user: get_caller_address(),
                on_behalf_of,
                amount,
                referral_code: 0,
            };

            self.emit(deposit_event);
        }

        fn withdraw(
            ref self: ContractState,
            asset: ContractAddress,
            amount: u256,
            to: ContractAddress
        ) {
            self.pausable.assert_not_paused();
            
            self.reentrancyguard.start()

            assert!(amount > 0_u256, "Amount must be greater than 0");
            assert!(to != 0_u256, "Invalid to address");

            let caller = get_caller_address();

            let reserve_data_contract_dispatcher: IReserveDataDispatcher = IReserveDataDispatcher {
                contract_address: self.reserve_data_contract_address.read()
            };
            
            // Get reserve configuration
            let reserve_config: ReserveConfigurationResponse = reserve_data_contract_dispatcher.get_reserve_config(&asset);
            // Get reserve state
            let reserve_state: ReserveStateResponse = reserve_data_contract_dispatcher.get_reserve_state(&asset);

            
            // Check health factor after withdrawal
            let user_data = self.get_user_account_data(&caller);
            assert(user_data.health_factor > 1000000000000000000_u256, "Health factor too low");

            // Burn aTokens
            let a_token: IERC20Dispatcher = IERC20Dispatcher { contract_address: self.v_share_token_contract_address.read() };
            a_token.transfer_from(&caller, get_contract_address(), &amount);

            // Update reserve state
            self._update_reserve_state(&asset, 0_u256, &amount, false);

            // Transfer tokens to user
            let token: IERC20Dispatcher = IERC20Dispatcher { contract_address: &asset };
            token.transfer(to, &amount);

            let withdraw_event: Withdraw = Withdraw {
                reserve: asset,
                user: caller,
                to,
                amount,
            };

            self.emit(withdraw_event);
        }

        fn borrow(
            ref self: ContractState,
            asset: ContractAddress,
            amount: u256,
            interest_rate_mode: u8,
            on_behalf_of: ContractAddress
        ) {
            // Implementation follows similar pattern...
        }

        fn repay(
            ref self: ContractState,
            asset: ContractAddress,
            amount: u256,
            interest_rate_mode: u8,
            on_behalf_of: ContractAddress
        ) {
            // Implementation...
        }

        fn get_user_account_data(
            self: @ContractState,
            user: ContractAddress
        ) -> (u256, u256, u256, u256, u256, u8) {

            let reserve_data_contract_dispatcher: IReserveDataDispatcher = IReserveDataDispatcher {
                contract_address: self.reserve_data_contract_address.read()
            };

            let mut total_collateral = 0_u256;
            let mut total_debt = 0_u256;
            let mut avg_liquidation_threshold = 0_u256;
            let mut count = 0_u256;


            // let mut filtered_claims_array: Array<InsuranceClaim> = array![];

            // let len: u64 = self.claims_vec.len();

            // for i in 0..len {

            //     let current_status_code: u8 = self.claims_vec.at(i).read().claim_status_code.into();


            //     if current_status_code == convert_claim_status_to_code(ClaimStatus::Repudiated) {
            //         continue;
            //     } else if current_status_code == convert_claim_status_to_code(ClaimStatus::Settled) {
            //         continue;
            //     } else {
            //         filtered_claims_array.append(self.claims_vec.at(i).read());
            //     }
            // }

            // filtered_claims_array


            // Iterate through all reserves
            let reserves = self.reserves_list.read();
            let len: u64 = reserves.len();
            let mut i = 0_usize;

            loop {
                if i >= len {
                    break ();
                }

                let asset = *reserves.at(i);
                let reserve_config: ReserverConfigurationResponse = reserve_data_contract_dispatcher.get_reserve_config(&asset);
                let user_data: UserReserveDataResponse = reserve_data_contract_dispatcher.get_user_reserve_data(user, asset);

                if user_data.scaled_a_token_balance > 0_u256 && user_data.is_using_as_collateral {
                    let price = self.price_oracle.read().get_price(asset);
                    let a_token = IERC20Dispatcher{ contract_address: reserve_config.a_token_address };
                    let balance = a_token.balance_of(user);
                    
                    total_collateral += balance * price / (10_u256 ** 18_u256);
                    avg_liquidation_threshold += reserve_config.liquidation_threshold;
                    count += 1_u256;
                }

                if user_data.scaled_variable_debt > 0_u256 {
                    let price = self.price_oracle.read().get_price(asset);
                    // Calculate debt value
                    total_debt += user_data.scaled_variable_debt * price / (10_u256 ** 18_u256);
                }

                i += 1;
            }

            let avg_lt = if count > 0_u256 { avg_liquidation_threshold / count } else { 0_u256 };
            let health_factor = if total_debt > 0_u256 {
                (total_collateral * avg_lt) / (total_debt * 10000_u256)
            } else {
                1000000000000000000_u256 * 100_u256 // Max health factor
            };

            (
                total_collateral,
                total_debt,
                avg_lt,
                health_factor,
                0_u256, // Available borrows (simplified)
                0_u8    // Current liquidation mode
            )
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _assert_not_paused(ref self: ContractState) -> bool {
            self.pausable.assert_not_paused();
        }

        fn _update_reserve_state(
            ref self: ContractState,
            asset: ContractAddress,
            liquidity_added: u256,
            liquidity_removed: u256,
            is_deposit: bool
        ) {

            let reserve_data_contract_dispatcher: IReserveDataDispatcher = IReserveDataDispatcher {
                contract_address: self.reserve_data_contract_address.read()
            };

            let current_time: u64 = get_block_timestamp();

            let mut reserve_state: ReserveStateResponse = reserve_data_contract_dispatcher.get_reserve_state(asset);
            
            if is_deposit {
                reserve_state.total_liquidity = reserve_state.total_liquidity + liquidity_added;
                reserve_state.available_liquidity = reserve_state.available_liquidity + liquidity_added;
            } else {
                reserve_state.total_liquidity = reserve_state.total_liquidity - liquidity_removed;
                reserve_state.available_liquidity = reserve_state.available_liquidity - liquidity_removed;
            }

            // Update interest rates based on utilization
            let utilization_rate = if reserve_state.total_liquidity > 0_u256 {
                reserve_state.total_variable_debt * 10000_u256 / reserve_state.total_liquidity
            } else {
                0_u256
            };

            // Calculate new rates (simplified)
            let new_variable_rate = self._calculate_variable_borrow_rate(reserve_data_contract_dispatcher, asset, utilization_rate);
            let new_liquidity_rate = self._calculate_liquidity_rate(reserve_data_contract_dispatcher, asset, utilization_rate, new_variable_rate);

            reserve_state.variable_borrow_rate = new_variable_rate;
            reserve_state.liquidity_rate = new_liquidity_rate;
            reserve_state.last_update_timestamp = get_block_timestamp();

            // Update indices
            reserve_state.liquidity_index = self._calculate_liquidity_index(reserve_data_contract_dispatcher);
            reserve_state.variable_borrow_index = self.calculate_variable_borrow_index(reserve_data_contract_dispatcher);

            self.reserve_data.write().set_reserve_state(asset, reserve_state);

            reserve_data_contract_dispatcher.set_reserve_state(
                asset: reserve_state.asset,
                total_liquidity: reserve_state.total_liquidity,
                available_liquidity: reserve_state.available_liquidity,
                total_variable_debt: reserve_state.total_variable_debt,
                liquidity_rate: reserve_state.liquidity_rate,
                variable_borrow_rate: reserve_state.variable_borrow_rate,
                liquidity_index: reserve_state.liquidity_index,
                variable_borrow_index: reserve_state.variable_borrow_index,
                last_update_timestamp: get_block_timestamp()
            );

            self.emit(Event::ReserveDataUpdated(ReserveDataUpdated {
                reserve: asset,
                liquidity_rate: new_liquidity_rate,
                stable_borrow_rate: 0_u256,
                variable_borrow_rate: new_variable_rate,
                liquidity_index: reserve_state.liquidity_index,
                variable_borrow_index: reserve_state.variable_borrow_index,
            }));
        }

        fn _calculate_variable_borrow_rate(self: @ContractState, reserve_data_contract_dispatcher: IReserveDataDispatcher, asset: ContractAddress, utilization: u256) -> u256 {

            // Simplified rate calculation
            // In production, use piecewise linear function
            let config: ReserveConfigurationResponse = reserve_data_contract_dispatcher.get_reserve_config(asset);
            
            if utilization < config.optimal_utilization_rate {
                return (config.base_variable_borrow_rate + (utilization * config.variable_rate_slope1) / config.optimal_utilization_rate);
            } else {
                return (config.base_variable_borrow_rate + config.variable_rate_slope1 + 
                    ((utilization - config.optimal_utilization_rate) * config.variable_rate_slope2) / (10000_u256 - config.optimal_utilization_rate));
            }
        }

        fn _calculate_liquidity_rate(
            self: @ContractState,
            reserve_data_contract_dispatcher: IReserveDataDispatcher,
            asset: ContractAddress,
            utilization: u256,
            variable_rate: u256
        ) -> u256 {

            let config: ReserveConfigurationResponse = reserve_data_contract_dispatcher.get_reserve_config(asset);
            let reserve_factor = config.reserve_factor;
            
            // Liquidity rate = utilization * variable_rate * (1 - reserve_factor)
            return (utilization * variable_rate * (10000_u256 - reserve_factor)) / (10000_u256 * 10000_u256);
        }

        fn _calculate_liquidity_index(self: @ContractState, reserve_data_contract_dispatcher: IReserveDataDispatcher) -> u256 {

            let state: ReserveStateResponse = reserve_data_contract_dispatcher.get_reserve_state();

            let time_diff: u256 = (get_block_timestamp() - state.last_update_timestamp).into();
            let rate_per_second = state.liquidity_rate / 31536000_u256; // Seconds per year
            
            state.liquidity_index * (u256_pow(10_u256, 27_u256) + (rate_per_second * time_diff)) / (u256_pow(10_u256, 27_u256))
        }

        fn _calculate_variable_borrow_index(self: @ContractState, reserve_data_contract_dispatcher: IReserveDataDispatcher) -> u256 {

            let state: ReserveStateResponse = reserve_data_contract_dispatcher.get_reserve_state();

            let time_diff: u256 = (get_block_timestamp() - state.last_update_timestamp).into();
            let rate_per_second = state.variable_borrow_rate / 31536000_u256;
            
            state.variable_borrow_index * (u256_pow(10_u256, 27_u256) + rate_per_second * time_diff) / (u256_pow(10_u256, 27_u256))
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