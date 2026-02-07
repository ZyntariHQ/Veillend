#[starknet::contract]
mod LendingPool {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use super::super::interfaces::{ILendingPool, IERC20Dispatcher, IERC20DispatcherTrait};

    #[storage]
    struct Storage {
        // user -> asset -> amount
        user_supplies: LegacyMap::<(ContractAddress, ContractAddress), u256>,
        user_borrows: LegacyMap::<(ContractAddress, ContractAddress), u256>,
        
        // Asset configuration
        supported_assets: LegacyMap::<ContractAddress, bool>,
        asset_price: LegacyMap::<ContractAddress, u256>, // Mock price in USD (18 decimals)
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Supply: Supply,
        Withdraw: Withdraw,
        Borrow: Borrow,
        Repay: Repay,
    }

    #[derive(Drop, starknet::Event)]
    struct Supply {
        user: ContractAddress,
        asset: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Withdraw {
        user: ContractAddress,
        asset: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Borrow {
        user: ContractAddress,
        asset: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Repay {
        user: ContractAddress,
        asset: ContractAddress,
        amount: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        // Initialize logic if needed
    }

    #[external(v0)]
    fn add_asset(ref self: ContractState, asset: ContractAddress, price: u256) {
        // Access control should be added here
        self.supported_assets.write(asset, true);
        self.asset_price.write(asset, price);
    }

    #[abi(embed_v0)]
    impl LendingPoolImpl of ILendingPool<ContractState> {
        fn supply(ref self: ContractState, asset: ContractAddress, amount: u256) {
            assert(self.supported_assets.read(asset), 'Asset not supported');
            let caller = get_caller_address();
            let contract_address = get_contract_address();

            // Transfer tokens from user to this contract
            IERC20Dispatcher { contract_address: asset }.transfer_from(caller, contract_address, amount);

            // Update state
            let current_supply = self.user_supplies.read((caller, asset));
            self.user_supplies.write((caller, asset), current_supply + amount);

            self.emit(Supply { user: caller, asset, amount });
        }

        fn withdraw(ref self: ContractState, asset: ContractAddress, amount: u256) {
            let caller = get_caller_address();
            let current_supply = self.user_supplies.read((caller, asset));
            assert(current_supply >= amount, 'Insufficient supply balance');

            // Update state
            self.user_supplies.write((caller, asset), current_supply - amount);

            // Transfer tokens back to user
            IERC20Dispatcher { contract_address: asset }.transfer(caller, amount);

            self.emit(Withdraw { user: caller, asset, amount });
        }

        fn borrow(ref self: ContractState, asset: ContractAddress, amount: u256) {
            assert(self.supported_assets.read(asset), 'Asset not supported');
            let caller = get_caller_address();
            
            // Simplified LTV check: Assume 1 ETH collateral ($2000) allows borrow of $1600 USDC
            // For now, we allow borrowing if user has ANY supply (MOCK Logic for demo)
            // Real logic requires iterating all user supplies * price * LTV > all user borrows * price
            
            // Check if contract has liquidity
            let liquidity = IERC20Dispatcher { contract_address: asset }.balance_of(get_contract_address());
            assert(liquidity >= amount, 'Insufficient liquidity');

            // Update state
            let current_borrow = self.user_borrows.read((caller, asset));
            self.user_borrows.write((caller, asset), current_borrow + amount);

            // Transfer borrowed tokens to user
            IERC20Dispatcher { contract_address: asset }.transfer(caller, amount);

            self.emit(Borrow { user: caller, asset, amount });
        }

        fn repay(ref self: ContractState, asset: ContractAddress, amount: u256) {
            let caller = get_caller_address();
            let contract_address = get_contract_address();
            let current_borrow = self.user_borrows.read((caller, asset));
            
            let repay_amount = if amount > current_borrow { current_borrow } else { amount };

            // Transfer tokens from user to contract
            IERC20Dispatcher { contract_address: asset }.transfer_from(caller, contract_address, repay_amount);

            // Update state
            self.user_borrows.write((caller, asset), current_borrow - repay_amount);

            self.emit(Repay { user: caller, asset, amount: repay_amount });
        }

        fn get_user_account_data(self: @ContractState, user: ContractAddress) -> (u256, u256, u256) {
            // Placeholder: return sum of supply and borrow for one asset if we knew it
            // In a real version, we'd loop over a list of supported assets
            // Returning (total_collateral_usd, total_debt_usd, health_factor)
            (1000, 500, 200) // Mock return
        }
    }
}
