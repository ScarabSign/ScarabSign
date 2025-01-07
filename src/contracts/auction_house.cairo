#[starknet::contract]
mod HomomorphicAuction {
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use starknet::{ERC721Receiver, IERC721Receiver};
    use core::pedersen::pedersen_hash;
    use core::option::OptionTrait;
    use core::array::ArrayTrait;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        BidFailed: BidFailed,
        AuctionComplete: AuctionComplete,
    }

    #[derive(Drop, starknet::Event)]
    struct BidFailed {
        bidder: ContractAddress,
        amount: u256,
        reason: felt252
    }

    #[derive(Drop, starknet::Event)]
    struct AuctionComplete {
        nft: ContractAddress,
        token: ContractAddress,
        nft_id: u256,
        winning_amount: u256,
        auctioneer: ContractAddress,
        winner: ContractAddress
    }

    #[storage]
    struct Storage {
        domain_separator: felt252,
        used_nonces: LegacyMap<ContractAddress, u256>,
        bid_type_hash: felt252,
        auction_type_hash: felt252,
        // Track processed bids to avoid reprocessing
        processed_bids: LegacyMap<(ContractAddress, u256), bool>
    }

    #[derive(Drop, Serde)]
    struct Bid {
        bidder: ContractAddress,
        amount: u256,
        bidder_nonce: u256,
        auction_sig_hash: felt252
    }

    #[derive(Drop, Serde)]
    struct Auction {
        auctioneer: ContractAddress,
        auctioneer_nonce: u256,
        nft: ContractAddress,
        nft_id: u256,
        token: ContractAddress,
        bid_start: u256,
        deadline: u256,
        auction_sig_hash: felt252,
        bids: Array<Bid>,
        bid_sigs: Array<felt252>
    }

    #[constructor]
    fn constructor() {
        // Constructor implementation remains the same
        ...
    }

    #[external]
    fn consume_auction(
        v: u8,
        r: felt252,
        s: felt252,
        auction: Auction
    ) {
        // Verify auction signature (same as before)
        verify_auction_signature(v, r, s, auction);

        // Try processing bids in order from highest to lowest
        let mut successful_bid = Option::None;
        let mut i = 0;
        
        loop {
            if i >= auction.bids.len() {
                break;
            }
            
            let bid = auction.bids[i];
            let sig = auction.bid_sigs[i];

            // Skip if bid was already processed
            if self.processed_bids.read((bid.bidder, bid.bidder_nonce)) {
                i += 1;
                continue;
            }

            // Mark bid as processed
            self.processed_bids.write((bid.bidder, bid.bidder_nonce), true);

            // Verify bid signature and try to execute
            if verify_bid(bid, sig) {
                match try_execute_bid(bid, auction) {
                    Option::Some(_) => {
                        successful_bid = Option::Some(bid);
                        break;
                    }
                    Option::None => {
                        // Emit event for failed bid
                        self.emit(BidFailed {
                            bidder: bid.bidder,
                            amount: bid.amount,
                            reason: 'insufficient_funds_or_allowance'
                        });
                    }
                }
            }

            i += 1;
        }

        // Ensure we found a valid bid
        match successful_bid {
            Option::Some(winning_bid) => {
                // Update nonces
                self.used_nonces.write(
                    winning_bid.bidder,
                    self.used_nonces.read(winning_bid.bidder) + 1
                );
                self.used_nonces.write(
                    auction.auctioneer,
                    self.used_nonces.read(auction.auctioneer) + 1
                );

                // Emit success event
                self.emit(AuctionComplete {
                    nft: auction.nft,
                    token: auction.token,
                    nft_id: auction.nft_id,
                    winning_amount: winning_bid.amount,
                    auctioneer: auction.auctioneer,
                    winner: winning_bid.bidder
                });
            }
            Option::None => {
                panic!('No valid bids with sufficient funds');
            }
        }
    }

    fn try_execute_bid(bid: Bid, auction: Auction) -> Option<()> {
        // Check token allowance
        let allowance = IERC20::allowance(auction.token, bid.bidder, get_contract_address());
        if allowance < bid.amount {
            return Option::None;
        }

        // Check token balance
        let balance = IERC20::balance_of(auction.token, bid.bidder);
        if balance < bid.amount {
            return Option::None;
        }

        // Try executing the transfers
        match execute_transfers(auction, bid) {
            Option::Some(_) => Option::Some(()),
            Option::None => Option::None
        }
    }

    fn execute_transfers(auction: Auction, bid: Bid) -> Option<()> {
        // Attempt NFT transfer first
        match IERC721::transfer_from(
            auction.nft,
            auction.auctioneer,
            bid.bidder,
            auction.nft_id
        ) {
            Result::Ok(_) => {
                // If NFT transfer succeeds, try token transfer
                match IERC20::transfer_from(
                    auction.token,
                    bid.bidder,
                    auction.auctioneer,
                    bid.amount
                ) {
                    Result::Ok(_) => Option::Some(()),
                    Result::Err(_) => {
                        // If token transfer fails, revert NFT transfer
                        IERC721::transfer_from(
                            auction.nft,
                            bid.bidder,
                            auction.auctioneer,
                            auction.nft_id
                        );
                        Option::None
                    }
                }
            }
            Result::Err(_) => Option::None
        }
    }
}
