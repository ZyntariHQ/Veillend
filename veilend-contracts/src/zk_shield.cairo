#[starknet::contract]
mod ZKShield {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use core::poseidon::PoseidonTrait;
    use core::hash::{HashStateTrait, HashStateExTrait};
    use super::super::interfaces::{IERC20Dispatcher, IERC20DispatcherTrait};
    use super::super::izk_shield::IZaKShield;

    #[storage]
    struct Storage {
        // Commitment -> Amount (In a real set, just existence)
        commitments: LegacyMap::<felt252, u256>,
        // Nullifier -> Used?
        nullifiers: LegacyMap::<felt252, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ShieldedDeposit: ShieldedDeposit,
        ShieldedWithdrawal: ShieldedWithdrawal,
    }

    #[derive(Drop, starknet::Event)]
    struct ShieldedDeposit {
        commitment: felt252,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct ShieldedWithdrawal {
        nullifier: felt252,
        amount: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {}

    #[abi(embed_v0)]
    impl ZKShieldImpl of IZaKShield<ContractState> {
        fn deposit_shielded(ref self: ContractState, asset: ContractAddress, amount: u256, commitment: felt252) {
            let caller = get_caller_address();
            let contract_address = get_contract_address();

            // Transfer assets to the pool
            IERC20Dispatcher { contract_address: asset }.transfer_from(caller, contract_address, amount);

            // Store commitment
            // NOTE: In a real privacy app, we wouldn't store the amount mapped to the commitment directly 
            // if we want to hide the amount. We would use a UTXO model.
            // Here we implement a "Hidden Owner" model.
            self.commitments.write(commitment, amount);

            self.emit(ShieldedDeposit { commitment, amount });
        }

        fn withdraw_shielded(ref self: ContractState, asset: ContractAddress, amount: u256, secret: felt252) {
            let caller = get_caller_address();
            
            // Reconstruct commitment from secret
            // commitment = Poseidon(secret)
            let commitment = core::poseidon::poseidon_hash_span(array![secret].span());

            // Verify commitment exists and has funds
            let stored_amount = self.commitments.read(commitment);
            assert(stored_amount >= amount, 'Invalid commitment or funds');
            assert(!self.nullifiers.read(secret), 'Note already spent');

            // Mark nullifier as used (prevent double spend)
            self.nullifiers.write(secret, true);
            
            // Update commitment balance (simple version)
            self.commitments.write(commitment, stored_amount - amount);

            // Transfer funds to the new caller (who proved they know the secret)
            IERC20Dispatcher { contract_address: asset }.transfer(caller, amount);

            self.emit(ShieldedWithdrawal { nullifier: secret, amount });
        }
    }
}
