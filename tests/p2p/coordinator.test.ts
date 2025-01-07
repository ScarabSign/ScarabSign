import { describe, expect, test, beforeAll, afterAll } from 'vitest';
import { P2PAuctionCoordinator } from '../../src/p2p/coordinator';
import { createLocalStarknetNetwork } from '@shardlabs/starknet-devnet';
import { Account, Provider, Contract } from 'starknet';
import { mockLibp2pNode } from '../mocks/libp2p';

describe('P2P Auction Coordinator', () => {
    let devnet: any;
    let provider: Provider;
    let coordinator1: P2PAuctionCoordinator;
    let coordinator2: P2PAuctionCoordinator;
    let auctionContract: Contract;
    let tokenContract: Contract;
    let nftContract: Contract;

    beforeAll(async () => {
        // Start local Starknet devnet
        devnet = await createLocalStarknetNetwork({
            seed: 42,
            port: 5050
        });
        
        provider = new Provider({ sequencer: { baseUrl: 'http://localhost:5050' } });
        
        // Deploy test contracts
        const result = await deployTestContracts(provider);
        auctionContract = result.auctionContract;
        tokenContract = result.tokenContract;
        nftContract = result.nftContract;

        // Initialize coordinators with different mock libp2p nodes
        coordinator1 = new P2PAuctionCoordinator(
            auctionContract.address,
            await provider.getChainId(),
            'http://localhost:5050'
        );
        coordinator1.setLibp2pNode(await mockLibp2pNode('peer1'));

        coordinator2 = new P2PAuctionCoordinator(
            auctionContract.address,
            await provider.getChainId(),
            'http://localhost:5050'
        );
        coordinator2.setLibp2pNode(await mockLibp2pNode('peer2'));

        await coordinator1.initialize();
        await coordinator2.initialize();
    });

    afterAll(async () => {
        await devnet.close();
    });

    test('should create new auction and broadcast to peers', async () => {
        const nftId = '1';
        const startPrice = '1000000000000000000'; // 1 token
        const deadline = Math.floor(Date.now() / 1000) + 3600;

        // Create auction from coordinator1
        await coordinator1.createAuction(
            nftContract.address,
            nftId,
            tokenContract.address,
            startPrice,
            deadline
        );

        // Wait for coordinator2 to receive auction
        await new Promise(resolve => setTimeout(resolve, 100));

        // Check if coordinator2 received and processed the auction
        const auction = coordinator2.getCurrentAuction();
        expect(auction).toBeDefined();
        expect(auction.nftContract).toBe(nftContract.address);
        expect(auction.nftId).toBe(nftId);
    });

    test('should handle bids and maintain correct order', async () => {
        // Place bids from both coordinators
        await coordinator2.placeBid('2000000000000000000'); // 2 tokens
        await new Promise(resolve => setTimeout(resolve, 100));

        await coordinator1.placeBid('3000000000000000000'); // 3 tokens
        await new Promise(resolve => setTimeout(resolve, 100));

        // Check bid order in both coordinators
        const auction1 = coordinator1.getCurrentAuction();
        const auction2 = coordinator2.getCurrentAuction();

        expect(auction1.bids.length).toBe(2);
        expect(auction2.bids.length).toBe(2);

        // Verify bids are ordered by amount (highest first)
        expect(auction1.bids[0].amount).toBe('3000000000000000000');
        expect(auction1.bids[1].amount).toBe('2000000000000000000');
    });

    test('should validate token balance and allowance before accepting bid', async () => {
        // Try to place bid without sufficient balance
        await expect(
            coordinator2.placeBid('999999000000000000000000') // Very large amount
        ).rejects.toThrow('Insufficient balance or allowance');
    });

    test('should finalize auction and prepare on-chain submission', async () => {
        const completion = await coordinator1.finalizeAuction();

        expect(completion.bids).toBeDefined();
        expect(completion.bids.length).toBe(2);
        expect(completion.signature).toBeDefined();

        // Verify the bid chain is properly ordered and signed
        const signedBids = completion.bids;
        expect(signedBids[0].amount).toBe('3000000000000000000');
        expect(signedBids[1].amount).toBe('2000000000000000000');
        expect(signedBids[0].signature).toBeDefined();
        expect(signedBids[1].signature).toBeDefined();
    });
});
