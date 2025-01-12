const hre = require('hardhat')
const SignerWithAddress = require('@nomiclabs/hardhat-ethers/signers')
const { expect,assert } = require('chai')
const {
  encrypt,
  recoverPersonalSignature,
  recoverTypedSignature,
  TypedMessage,
  MessageTypes,
  SignTypedDataVersion
} = require('@metamask/eth-sig-util');

const { deployEnglishAuction } = require('../scripts/deploy.js')
const { Bid, Auction, AuctionAuthSig } = require('./type-hashes.js')
function* idMaker() {
  var index = 0;
  while (true)
    yield index++;
}

describe("English Auction", async () => {
  
  const genId = idMaker()
  const auctionedNFTId = 0
  const million = hre.ethers.utils.parseEther('1000000')
  const hundredThousand = hre.ethers.utils.parseEther('100000')
  const tenThousand = hre.ethers.utils.parseEther('10000')
  const thousand = hre.ethers.utils.parseEther('1000')
  const hundred = hre.ethers.utils.parseEther('100')
  const deadline = Math.floor(new Date().getTime() / 1000) + 3600
  let chainId
  let domain
  let englishAuctionAddr
  let exampleTokenAddr
  let exampleNftAddr
  let accounts
  let deployer
  let auctioneer
  let bidder1
  let bidder2
  let bidder3
  
  before(async () => {
    chainId = (await hre.ethers.provider.getNetwork()).chainId
    // Stage of Actors
    accounts = await hre.ethers.getSigners();
    deployer = accounts[0]
    auctioneer = accounts[1]
    bidder1 = accounts[2]
    bidder2 = accounts[3]
    bidder3 = accounts[4]

    // deploy, loaded contract instances
    ;({englishAuctionAddr, exampleTokenAddr, exampleNftAddr} = await deployEnglishAuction())
    exampleToken = await hre.ethers.getContractAt('ExampleToken', exampleTokenAddr)
    exampleNFT = await hre.ethers.getContractAt('ExampleNFT', exampleNftAddr)
    englishAuction = await hre.ethers.getContractAt('EnglishAuction', englishAuctionAddr)
    
    domain = {
      name:  'EnglishAuction',
      version: '1',
      chainId: chainId,
      verifyingContract: englishAuctionAddr
    }

    // nft for auctioneer to auction
    await exampleNFT.connect(deployer).safeTransferFrom(deployer.address,auctioneer.address, auctionedNFTId, 1, 0xf18)
    // authorizes auction contract to move nft
    await exampleNFT.connect(auctioneer).setApprovalForAll(englishAuctionAddr, true)

    //preloading example token for bidders
    await Promise.all(
      [bidder1,bidder2,bidder3].map(async (account, i) => {
        await exampleToken.connect(deployer).transfer(account.address,  million)
        // approves auction contract to move bidders funds
        await exampleToken.connect(account).approve(englishAuctionAddr, hundredThousand)
      })
    )
  })

  it("allows an auctioneer to create an auction for a nft in base token", async () => {
    const nftBalanceBidder1_initial = await exampleNFT.balanceOf(bidder1.address, auctionedNFTId)
    const tokenBalanceBidder1_initial = await exampleToken.balanceOf(bidder1.address)
    const tokenBalanceAuctioneer_initial = await exampleToken.balanceOf(auctioneer.address)

    // auctioneer creates an auction by starting the Auction Permit Chain
    let createAuction = {
      auctioneer: auctioneer.address,
      auctioneerNonce: (await englishAuction.usedNonces(auctioneer.address)).toString(),
      nft: exampleNftAddr,
      nftId: auctionedNFTId,
      token: exampleTokenAddr,
      bidStart: thousand,
      deadline:  deadline,
    }


    const auctionAuthSigHash = ethers.utils.keccak256(await auctioneer._signTypedData(
      domain,
      { AuctionAuthSig },
      createAuction
    ))


    let auction = {
      ...createAuction,
      auctionSigHash: auctionAuthSigHash,
      bids: [],
      bidSigs: []
    }

    // bidder can add a bid to the bid and bidSig arrays
    const bid1LatestNonce = (await englishAuction.usedNonces(bidder1.address)).toString()
    const bid1Price = hundred;
    const bid1 = {
      bidder: bidder1.address,
      amount: bid1Price,
      bidderNonce: bid1LatestNonce,
      auctionSigHash: auctionAuthSigHash
    }
    const bidSig1 = await bidder1._signTypedData(
      domain,
      { Bid },
      bid1
    )
    // auctioneer pushes bid into the permit chain
    auction.bids.push(bid1)
    auction.bidSigs.push(bidSig1)
    
    const auctionSig = await auctioneer._signTypedData(
      domain,
      { Auction, Bid },
      auction
    )
    const auctionSigNo0x = auctionSig.substring(2)
    const r = '0x' + auctionSigNo0x.substring(0,64);
    const s = '0x' + auctionSigNo0x.substring(64,128);
    const v = parseInt(auctionSigNo0x.substring(128,130), 16)

    // Auctioneer consumes the auction on chain
    await englishAuction.connect(auctioneer).consumeAuction(v,r,s, auction)

    const nftBalanceBidder1_final = await exampleNFT.balanceOf(bidder1.address, auctionedNFTId)
    const tokenBalanceBidder1_final = await exampleToken.balanceOf(bidder1.address)
    const tokenBalanceAuctioneer_final = await exampleToken.balanceOf(auctioneer.address)

    expect(nftBalanceBidder1_initial).to.equal(0)
    expect(nftBalanceBidder1_final).to.equal(1)
    expect(tokenBalanceBidder1_initial.sub(tokenBalanceBidder1_final)).to.equal(bid1Price)
    expect(tokenBalanceAuctioneer_final.sub(tokenBalanceAuctioneer_initial)).to.equal(bid1Price)
    
    const bid1LatestNonce2 = await englishAuction.connect(bidder1).usedNonces(bidder1.address)
    expect((bid1LatestNonce2).sub(bid1LatestNonce)).to.equal(1)
  })

  it("Takes highest bid contractually", async () => {
    await exampleNFT.connect(deployer).safeTransferFrom(deployer.address,auctioneer.address, auctionedNFTId, 1, 0x9e3779)

    const nftBalanceBidder1_initial = await exampleNFT.balanceOf(bidder1.address, auctionedNFTId)
    const nftBalanceBidder2_initial = await exampleNFT.balanceOf(bidder2.address, auctionedNFTId)
    const tokenBalanceBidder1_initial = await exampleToken.balanceOf(bidder1.address)
    const tokenBalanceBidder2_initial = await exampleToken.balanceOf(bidder2.address)
    const tokenBalanceAuctioneer_initial = await exampleToken.balanceOf(auctioneer.address)
    
    let createAuction = {
      auctioneer: auctioneer.address,
      auctioneerNonce: (await englishAuction.usedNonces(auctioneer.address)).toString(),
      nft: exampleNftAddr,
      nftId: auctionedNFTId,
      token: exampleTokenAddr,
      bidStart: thousand,
      deadline:  deadline,
    }

    const auctionAuthSigHash = ethers.utils.keccak256(await auctioneer._signTypedData(
      domain,
      { AuctionAuthSig },
      createAuction
    ))

    let auction = {
      ...createAuction,
      auctionSigHash: auctionAuthSigHash,
      bids: [],
      bidSigs: []
    }


    // bidder can add a bid to the bid and bidSig arrays
    const bid1LatestNonce = (await englishAuction.usedNonces(bidder1.address)).toString()
    const bidPrice1 = thousand
    const bid1 = {
      bidder: bidder1.address,
      amount: bidPrice1,
      bidderNonce: bid1LatestNonce,
      auctionSigHash: auctionAuthSigHash
    }
    const bidSig1 = await bidder1._signTypedData(
      domain,
      { Bid },
      bid1
    )
    // auctioneer pushes bid into the permit chain
    auction.bids.push(bid1)
    auction.bidSigs.push(bidSig1)
    
    // bidder 2 can add a bid to the bid and bidSig arrays
    const bid2LatestNonce = (await englishAuction.usedNonces(bidder2.address)).toString()
    const bidPrice2 = hundred
    const bid2 = {
      bidder: bidder2.address,
      amount: bidPrice2,
      bidderNonce: bid2LatestNonce,
      auctionSigHash: auctionAuthSigHash
    }
    const bidSig2 = await bidder2._signTypedData(
      domain,
      { Bid },
      bid2
    )
    // auctioneer pushes bid into the permit chain
    auction.bids.push(bid2)
    auction.bidSigs.push(bidSig2)

    const auctionSig = await auctioneer._signTypedData(
      domain,
      { Auction, Bid },
      auction
    )
    const auctionSigNo0x = auctionSig.substring(2)
    const r = '0x' + auctionSigNo0x.substring(0,64);
    const s = '0x' + auctionSigNo0x.substring(64,128);
    const v = parseInt(auctionSigNo0x.substring(128,130), 16)
    

    // Auctioneer consumes the auction on chain
    await englishAuction.connect(auctioneer).consumeAuction(v,r,s, auction)

    const nftBalanceBidder1_final = await exampleNFT.balanceOf(bidder1.address, auctionedNFTId)
    const nftBalanceBidder2_final = await exampleNFT.balanceOf(bidder2.address, auctionedNFTId)
    const tokenBalanceBidder1_final = await exampleToken.balanceOf(bidder1.address)
    const tokenBalanceBidder2_final = await exampleToken.balanceOf(bidder2.address)
    const tokenBalanceAuctioneer_final = await exampleToken.balanceOf(auctioneer.address)

    expect(nftBalanceBidder1_final.sub(nftBalanceBidder1_initial)).to.equal(1)
    expect(nftBalanceBidder2_final.sub(nftBalanceBidder2_initial)).to.equal(0)
    expect(tokenBalanceBidder1_initial.sub(tokenBalanceBidder1_final)).to.equal(bidPrice1)
    expect(tokenBalanceBidder2_initial.sub(tokenBalanceBidder2_final)).to.equal(0)
    expect(tokenBalanceAuctioneer_final.sub(tokenBalanceAuctioneer_initial)).to.equal(bidPrice1)

  })
  it("fails if bids are not sorted from highest to lowest", async () => {
    await exampleNFT.connect(deployer).safeTransferFrom(deployer.address,auctioneer.address, auctionedNFTId, 1, 0x9e3779)

    const nftBalanceBidder1_initial = await exampleNFT.balanceOf(bidder1.address, auctionedNFTId)
    const nftBalanceBidder2_initial = await exampleNFT.balanceOf(bidder2.address, auctionedNFTId)
    const tokenBalanceBidder1_initial = await exampleToken.balanceOf(bidder1.address)
    const tokenBalanceBidder2_initial = await exampleToken.balanceOf(bidder2.address)
    const tokenBalanceAuctioneer_initial = await exampleToken.balanceOf(auctioneer.address)
    
    let createAuction = {
      auctioneer: auctioneer.address,
      auctioneerNonce: (await englishAuction.usedNonces(auctioneer.address)).toString(),
      nft: exampleNftAddr,
      nftId: auctionedNFTId,
      token: exampleTokenAddr,
      bidStart: thousand,
      deadline:  deadline,
    }

    const auctionAuthSigHash = ethers.utils.keccak256(await auctioneer._signTypedData(
      domain,
      { AuctionAuthSig },
      createAuction
    ))

    let auction = {
      ...createAuction,
      auctionSigHash: auctionAuthSigHash,
      bids: [],
      bidSigs: []
    }


    // bidder can add a bid to the bid and bidSig arrays
    const bid1LatestNonce = (await englishAuction.usedNonces(bidder1.address)).toString()
    const bidPrice1 = hundred
    const bid1 = {
      bidder: bidder1.address,
      amount: bidPrice1,
      bidderNonce: bid1LatestNonce,
      auctionSigHash: auctionAuthSigHash
    }
    const bidSig1 = await bidder1._signTypedData(
      domain,
      { Bid },
      bid1
    )
    // auctioneer pushes bid into the permit chain
    auction.bids.push(bid1)
    auction.bidSigs.push(bidSig1)
    
    // bidder 2 can add a bid to the bid and bidSig arrays
    const bid2LatestNonce = (await englishAuction.usedNonces(bidder2.address)).toString()
    const bidPrice2 = thousand
    const bid2 = {
      bidder: bidder2.address,
      amount: bidPrice2,
      bidderNonce: bid2LatestNonce,
      auctionSigHash: auctionAuthSigHash
    }
    const bidSig2 = await bidder2._signTypedData(
      domain,
      { Bid },
      bid2
    )
    // auctioneer pushes bid into the permit chain
    auction.bids.push(bid2)
    auction.bidSigs.push(bidSig2)

    const auctionSig = await auctioneer._signTypedData(
      domain,
      { Auction, Bid },
      auction
    )
    const auctionSigNo0x = auctionSig.substring(2)
    const r = '0x' + auctionSigNo0x.substring(0,64);
    const s = '0x' + auctionSigNo0x.substring(64,128);
    const v = parseInt(auctionSigNo0x.substring(128,130), 16)
    

    // Auctioneer consumes the auction on chain
    //
    await expect(
     englishAuction.connect(auctioneer).consumeAuction(v,r,s, auction)
    ).to.be.revertedWith('Please order the bids from highest to smallest prior to consuming, this saves gas')

  })

  it("goes to next highest highest bidder doesnt approve token to auction contract", async () => {
    await exampleNFT.connect(deployer).safeTransferFrom(deployer.address,auctioneer.address, auctionedNFTId, 1, 0x9e3779)

    const nftBalanceBidder1_initial = await exampleNFT.balanceOf(bidder1.address, auctionedNFTId)
    const nftBalanceBidder2_initial = await exampleNFT.balanceOf(bidder2.address, auctionedNFTId)
    const tokenBalanceBidder1_initial = await exampleToken.balanceOf(bidder1.address)
    const tokenBalanceBidder2_initial = await exampleToken.balanceOf(bidder2.address)
    const tokenBalanceAuctioneer_initial = await exampleToken.balanceOf(auctioneer.address)
    
    let createAuction = {
      auctioneer: auctioneer.address,
      auctioneerNonce: (await englishAuction.usedNonces(auctioneer.address)).toString(),
      nft: exampleNftAddr,
      nftId: auctionedNFTId,
      token: exampleTokenAddr,
      bidStart: thousand,
      deadline:  deadline,
    }

    const auctionAuthSigHash = ethers.utils.keccak256(await auctioneer._signTypedData(
      domain,
      { AuctionAuthSig },
      createAuction
    ))

    let auction = {
      ...createAuction,
      auctionSigHash: auctionAuthSigHash,
      bids: [],
      bidSigs: []
    }


    // bidder removes allowance on auction contract
    await exampleToken.connect(bidder1).approve(englishAuction.address, 0)
    const bid1LatestNonce = (await englishAuction.usedNonces(bidder1.address)).toString()
    const bidPrice1 = thousand
    const bid1 = {
      bidder: bidder1.address,
      amount: bidPrice1,
      bidderNonce: bid1LatestNonce,
      auctionSigHash: auctionAuthSigHash
    }
    const bidSig1 = await bidder1._signTypedData(
      domain,
      { Bid },
      bid1
    )
    // auctioneer pushes bid into the permit chain
    auction.bids.push(bid1)
    auction.bidSigs.push(bidSig1)
    
    // bidder 2 can add a bid to the bid and bidSig arrays
    const bid2LatestNonce = (await englishAuction.usedNonces(bidder2.address)).toString()
    const bidPrice2 = hundred
    const bid2 = {
      bidder: bidder2.address,
      amount: bidPrice2,
      bidderNonce: bid2LatestNonce,
      auctionSigHash: auctionAuthSigHash
    }
    const bidSig2 = await bidder2._signTypedData(
      domain,
      { Bid },
      bid2
    )
    // auctioneer pushes bid into the permit chain
    auction.bids.push(bid2)
    auction.bidSigs.push(bidSig2)

    const auctionSig = await auctioneer._signTypedData(
      domain,
      { Auction, Bid },
      auction
    )
    const auctionSigNo0x = auctionSig.substring(2)
    const r = '0x' + auctionSigNo0x.substring(0,64);
    const s = '0x' + auctionSigNo0x.substring(64,128);
    const v = parseInt(auctionSigNo0x.substring(128,130), 16)
    

    // Auctioneer consumes the auction on chain
    await englishAuction.connect(auctioneer).consumeAuction(v,r,s, auction)

    const nftBalanceBidder1_final = await exampleNFT.balanceOf(bidder1.address, auctionedNFTId)
    const nftBalanceBidder2_final = await exampleNFT.balanceOf(bidder2.address, auctionedNFTId)
    const tokenBalanceBidder1_final = await exampleToken.balanceOf(bidder1.address)
    const tokenBalanceBidder2_final = await exampleToken.balanceOf(bidder2.address)
    const tokenBalanceAuctioneer_final = await exampleToken.balanceOf(auctioneer.address)

    expect(nftBalanceBidder1_final.sub(nftBalanceBidder1_initial)).to.equal(0)
    expect(nftBalanceBidder2_final.sub(nftBalanceBidder2_initial)).to.equal(1)
    expect(tokenBalanceBidder1_initial.sub(tokenBalanceBidder1_final)).to.equal(0)
    expect(tokenBalanceBidder2_initial.sub(tokenBalanceBidder2_final)).to.equal(bidPrice2)
    expect(tokenBalanceAuctioneer_final.sub(tokenBalanceAuctioneer_initial)).to.equal(bidPrice2)

  })
})
