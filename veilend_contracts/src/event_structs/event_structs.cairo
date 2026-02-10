use starknet::ContractAddress;
use crate::enums::enums::*;



#[derive(Drop, starknet::Event)]
pub struct ReserveConfigurationUpdated {
    pub asset: ContractAddress,
    pub optimal_utilization_rate: u256,
    pub base_variable_borrow_rate: u256,
    pub variable_rate_slope1: u256,
    pub variable_rate_slope2: u256,
    pub loan_to_value: u256,
    pub liquidation_threshold: u256,
    pub liquidation_bonus: u256,
    pub reserve_factor: u256,
    pub a_token_address: ContractAddress,
    pub variable_debt_token_address: ContractAddress,
    pub is_active: bool,
    pub is_frozen: bool,
    pub borrowing_enabled: bool,
}

#[derive(Drop, starknet::Event)]
pub struct ReserveStateUpdated {
    pub asset: ContractAddress,
    pub total_liquidity: u256,
    pub available_liquidity: u256,
    pub total_variable_debt: u256,
    pub liquidity_rate: u256,
    pub variable_borrow_rate: u256,
    pub liquidity_index: u256,
    pub variable_borrow_index: u256,
    pub last_update_timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct UserReserveDataUpdated {
    pub user: ContractAddress,
    pub asset: ContractAddress,
    pub scaled_a_token_balance: u256,
    pub scaled_variable_debt: u256,
    pub is_using_as_collateral: bool,
}