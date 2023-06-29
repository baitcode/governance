use starknet::ContractAddress;
use array::{Array};

#[derive(Copy, Drop, Serde)]
struct Claim {
    claimee: ContractAddress,
    amount: u128,
}

#[starknet::interface]
trait IAirdrop<TStorage> {
    fn claim(ref self: TStorage, claim: Claim, proof: Array::<felt252>);
}

#[starknet::contract]
mod Airdrop {
    use super::{IAirdrop, ContractAddress, Claim};
    use array::{ArrayTrait, SpanTrait};
    use hash::{pedersen};
    use traits::{Into, TryInto};
    use starknet::ContractAddressIntoFelt252;

    use governance::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};

    // Compute the pedersen root of a merkle tree by combining the current node with each sibling up the tree
    fn compute_pedersen_root(mut current: felt252, mut proof: Span<felt252>) -> felt252 {
        match proof.pop_front() {
            Option::Some(proof_element) => {
                let a: u256 = current.into();
                let b: u256 = (*proof_element).into();
                if b > a {
                    current = pedersen(current, *proof_element);
                } else {
                    current = pedersen(*proof_element, current);
                }

                compute_pedersen_root(current, proof)
            },
            Option::None(()) => {
                current
            },
        }
    }

    #[generate_trait]
    impl ClaimToLeaf of ClaimToLeafTrait {
        fn to_leaf(self: @Claim) -> felt252 {
            pedersen((*self.claimee).into(), (*self.amount).into())
        }
    }

    #[storage]
    struct Storage {
        root: felt252,
        token: IERC20Dispatcher,
        claimed: LegacyMap<felt252, bool>,
    }

    #[derive(Drop, starknet::Event)]
    struct Claimed {
        claim: Claim
    }

    #[derive(starknet::Event, Drop)]
    #[event]
    enum Event {
        Claimed: Claimed, 
    }

    #[constructor]
    fn constructor(ref self: ContractState, token: IERC20Dispatcher, root: felt252) {
        self.root.write(root);
        self.token.write(token);
    }

    #[external(v0)]
    impl AirdropImpl of IAirdrop<ContractState> {
        fn claim(ref self: ContractState, claim: Claim, proof: Array::<felt252>) {
            let leaf = claim.to_leaf();

            assert(!self.claimed.read(leaf), 'ALREADY_CLAIMED');
            assert(self.root.read() == compute_pedersen_root(leaf, proof.span()), 'INVALID_PROOF');
            self.claimed.write(leaf, true);

            self.token.read().transfer(claim.claimee, u256 { high: 0, low: claim.amount });

            self.emit(Event::Claimed(Claimed { claim }));
        }
    }
}