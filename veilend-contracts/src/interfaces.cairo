use starknet::ContractAddress;

#[starknet::interface]
trait IERC20<TState> {
    fn name(self: @TState) -> felt252;
    fn symbol(self: @TState) -> felt252;
    fn decimals(self: @TState) -> u8;
    fn total_supply(self: @TState) -> u256;
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
    fn approve(ref self: TState, spender: ContractAddress, amount: u256) -> bool;
}

#[starknet::interface]
trait ILendingPool<TState> {
    fn supply(ref self: TState, asset: ContractAddress, amount: u256);
    fn withdraw(ref self: TState, asset: ContractAddress, amount: u256);
    fn borrow(ref self: TState, asset: ContractAddress, amount: u256);
    fn repay(ref self: TState, asset: ContractAddress, amount: u256);
    fn get_user_account_data(self: @TState, user: ContractAddress) -> (u256, u256, u256); // total_collateral, total_debt, health_factor
}
