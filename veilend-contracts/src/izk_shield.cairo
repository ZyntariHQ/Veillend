use starknet::ContractAddress;

#[starknet::interface]
trait IZaKShield<TState> {
    // Deposit assets into the shielded pool. 
    // The amount is visible during deposit (unless using a mixer pattern), 
    // but the ownership is hidden behind the commitment.
    fn deposit_shielded(ref self: TState, asset: ContractAddress, amount: u256, commitment: felt252);
    
    // Withdraw assets by providing the secret key (nullifier) that matches the commitment.
    // In a real ZK app, this would verify a ZK-SNARK/STARK proof so the secret is never revealed.
    // For this implementation, we verify the hash on-chain (Commit-Reveal scheme).
    fn withdraw_shielded(ref self: TState, asset: ContractAddress, amount: u256, secret: felt252);
}
