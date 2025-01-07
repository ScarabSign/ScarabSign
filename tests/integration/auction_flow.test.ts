describe('Full Auction Flow Integration', () => {
    let devnet: any;
    let provider: Provider;
    let coordinator: P2PAuctionCoordinator;
    let auctionContract: Contract;
    let accounts: Account[];

    beforeAll(async () => {
        // Setup similar to p2p tests
        devnet = await createLocalStarknetNetwork({
            seed: 42,
            port: 5051
        });
        
        provider = new Provider({ sequencer: { baseUrl: 'http://localhost:5051' } });
        
        // Deploy contracts and setup accounts
        const result = await deployTestContracts(provider);
        auctionContract = result.auctionContract;
        accounts = result.accounts;

        // Initialize coordinator
        coordinator = new P2PAuctionCoordinator(
            auctionContract.address,
            await provider.getChainId(),
            'http://localhost:5051'
        );
        await coordinator.initialize();
    });

    afterAll(async () => {
        await devnet.close();
    });

    test('should execute full auction flow from p2p to on-chain settlement', async () => {
        // Create auction
        await coordinator.createAuction(/* ... */);

        // Collect bids off-chain
        await coordinator.placeBid('2000000000000000000');
        await coordinator.placeBid('3000000000000000000');

        // Finalize auction and get signed bid chain
        const completion = await coordinator.finalizeAuction();

        // Submit to contract
        const receipt = await auctionContract.invoke(
            'consume_auction',
            [completion.signature.v, completion.signature.r, completion.signature.s, completion.auction]
        );

        // Verify chain state
        expect(receipt.status).toBe('ACCEPTED');

        // Verify NFT and token transfers
        // Add verification of final state here
    });
});
