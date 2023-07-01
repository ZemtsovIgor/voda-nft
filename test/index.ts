import chai, {assert, expect} from 'chai';
import ChaiAsPromised from "chai-as-promised";
import CollectionConfig from "./../config/CollectionConfig";
import { NftContractType } from "../lib/ContractProvider";
import { artifacts, contract, ethers } from "hardhat";
import { parseEther } from "ethers/lib/utils";
// @ts-ignore
import {BN, constants, expectEvent, expectRevert, time} from "@openzeppelin/test-helpers";

const VODANFT = artifacts.require("./VODAVSTB.sol");
const TBCCFinanceFactory = artifacts.require("./test/TBCCFinanceFactory.sol");
const TBCCFinancePair = artifacts.require("./test/TBCCFinancePair.sol");
const TBCCFinanceRouter = artifacts.require("./test/TBCCFinanceRouter.sol");
const MockERC20 = artifacts.require("./test/MockERC20.sol");
const WBNB = artifacts.require("./test/WBNB.sol");
const DEFAULT_COST = parseEther("0.01");
const VOOLA_MAX_SUPPLY = parseEther("100000000000000000").toString();

chai.use(ChaiAsPromised);

contract(
  CollectionConfig.contractName,
  ([
    owner,
    holder,
    externalUser,
    minterTester,
    alice,
    bob,
    carol,
    david,
    erin,
  ]) => {
    let result: any;
    let contract!: NftContractType;
    let wrappedBNB: any;
    let usdt: any;
    let tbccFinanceFactory: any;
    let tbccFinanceRouter: any;
    let pairBNBUSDT: any;

    before(async function () {
      // Deploy Factory
      tbccFinanceFactory = await TBCCFinanceFactory.new(alice, { from: alice });

      // Deploy Wrapped BNB
      wrappedBNB = await WBNB.new({ from: alice });
      await wrappedBNB.mintTokens(VOOLA_MAX_SUPPLY, { from: alice });

      // Deploy Router
      tbccFinanceRouter = await TBCCFinanceRouter.new(
        tbccFinanceFactory.address,
        wrappedBNB.address,
        { from: alice }
      );

      // Deploy USDT
      usdt = await MockERC20.new("USDT", "USDT", VOOLA_MAX_SUPPLY, { from: alice });

      // Create 2 LP tokens
      result = await tbccFinanceFactory.createPair(
        wrappedBNB.address,
        usdt.address,
        { from: alice }
      );
      pairBNBUSDT = await TBCCFinancePair.at(result.logs[0].args[2]);

      contract = await VODANFT.new(
        wrappedBNB.address,
        pairBNBUSDT.address,
        carol,
        david,
        CollectionConfig.tokenName,
        CollectionConfig.tokenSymbol,
        { from: owner }
      );
    });

    // Check ticker, symbols, supply, and owner are correct
    describe("All contracts are deployed correctly", async () => {
      it("MinterTester distributes tokens to accounts", async () => {
        // transfer BNB to 3 accounts
        await wrappedBNB.transfer(owner, parseEther("1000").toString(), {
          from: alice,
        });
        await wrappedBNB.transfer(holder, parseEther("4").toString(), {
          from: alice,
        });
        await wrappedBNB.transfer(externalUser, parseEther("30").toString(), {
          from: alice,
        });
        await wrappedBNB.transfer(bob, parseEther("100000").toString(), {
          from: alice,
        });

        // transfer USDT to 3 accounts
        await usdt.transfer(bob, parseEther("10000000").toString(), {
          from: alice,
        });

        await contract.setPaused(true);
        await contract.setCost(10);
      });
    });

    describe("Check initial data", async () => {
      it("Check VSTB data", async function () {
        expect(await contract.name()).to.equal(CollectionConfig.tokenName);
        expect(await contract.symbol()).to.equal(CollectionConfig.tokenSymbol);
        expect((await contract.bnbCost()).toString()).to.equal(DEFAULT_COST);
        expect(await contract.paused()).to.equal(true);
      });
    });

    describe("Before any sale", async () => {
      it("User adds liquidity to LP tokens", async function () {
        const deadline = new BN(await time.latest()).add(new BN("100"));

        await wrappedBNB.approve(
          tbccFinanceRouter.address,
          constants.MAX_UINT256,
          { from: bob }
        );

        await usdt.approve(tbccFinanceRouter.address, constants.MAX_UINT256, {
          from: bob,
        });

        // 1 BNB = 300 USDT
        let result = await tbccFinanceRouter.addLiquidityETH(
          usdt.address,
          parseEther("300000"), // 300k token USDT
          parseEther("300000"), // 300k token USDT
          parseEther("1000"), // 1,000 BNB
          bob,
          deadline,
          { from: bob, value: parseEther("1000").toString() }
        );

        expectEvent.inTransaction(
          result.receipt.transactionHash,
          usdt,
          "Transfer",
          {
            from: bob,
            to: pairBNBUSDT.address,
            value: parseEther("300000").toString(),
          }
        );

        assert.equal(
          String(await wrappedBNB.balanceOf(pairBNBUSDT.address)),
          parseEther("1000").toString()
        );
        assert.equal(
          String(await usdt.balanceOf(pairBNBUSDT.address)),
          parseEther("300000").toString()
        );
      });

      it("Before any sale", async function () {
        // Nobody should be able to mint from a paused contract
        await expectRevert(
          contract.mintNFT(alice, { from: holder }),
          "The contract is paused!"
        );
        await expectRevert(
          contract.mintNFT(alice, { from: owner }),
          "The contract is paused!"
        );

        // The owner should always be able to run mintForAddress
        result = await contract.mintForAddress(owner, { from: owner });

        // Obtain gas used from the receipt
        expectEvent(result, "Transfer", {
          from: "0x0000000000000000000000000000000000000000",
          to: owner,
          tokenId: "1",
        });

        await contract.mintForAddress(alice, { from: owner });

        await expectRevert(
          contract.mintForAddress(holder, { from: holder }),
          "Ownable: caller is not the owner"
        );

        // Check balances
        result = await contract.balanceOf(owner);
        assert.equal(result, 1);

        result = await contract.balanceOf(holder);
        assert.equal(result, 0);

        result = await contract.balanceOf(externalUser);
        assert.equal(result, 0);
      });
    });

    describe("Minting", async () => {
      it("Pre-sale (same as public sale)", async function () {
        await contract.setPaused(false);

        result = await contract.bnbCost();
        assert.equal(result.toString(), parseEther("0.01").toString());

        result = await wrappedBNB.balanceOf(holder);
        assert.equal(result.toString(), parseEther("4").toString());

        result = await contract.getPrice(pairBNBUSDT.address, true);
        assert.equal(
          result.toString(),
          parseEther("0.003333333333333333").toString()
        );

        result = await contract.mintNFT(alice,{
          from: holder,
          value: parseEther("1").toString(),
        });

        // Obtain gas used from the receipt
        expectEvent(result, "Transfer", {
          from: "0x0000000000000000000000000000000000000000",
          to: holder,
          tokenId: "3",
        });

        result = await wrappedBNB.approve(
          contract.address,
          parseEther("2").toString(),
          { from: holder }
        );

        result = await wrappedBNB.balanceOf(holder);
        assert.equal(result.toString(), parseEther("4").toString());

        result = await contract.bnbCost();
        assert.equal(
          result.toString(),
          parseEther("0.03333333333333333").toString()
        );

        await expectRevert(
          contract.mintNFT(alice, {
            from: holder,
            value: parseEther("1").toString(),
          }),
          "VSBT already exists"
        );

        result = await contract.mintNFT(alice, {
          from: externalUser,
          value: parseEther("1").toString(),
        });

        // Obtain gas used from the receipt
        expectEvent(result, "Transfer", {
          from: "0x0000000000000000000000000000000000000000",
          tokenId: "4",
        });

        // Sending insufficient funds
        await expectRevert(
          contract.mintNFT(alice, { from: minterTester }),
          "Insufficient funds!"
        );

        await contract.mintNFT(holder, {
          from: bob,
          value: parseEther("1").toString(),
        });

        // Pause pre-sale
        await contract.setPaused(true);
        // await contract.setCost(200);
      });

      it("Owner only functions", async function () {
        await expectRevert(
          contract.mintForAddress(externalUser,{
            from: externalUser,
          }),
          "Ownable: caller is not the owner"
        );
        await expectRevert(
          contract.setCost(200, { from: externalUser }),
          "Ownable: caller is not the owner"
        );
        await expectRevert(
          contract.setPaused(false, { from: externalUser }),
          "Ownable: caller is not the owner"
        );
        await expectRevert(
          contract.withdraw({ from: externalUser }),
          "Ownable: caller is not the owner"
        );
      });

      it("Wallet of owner", async function () {
        result = await contract.tokenIdOf(owner);
        assert.equal(result.toString(), "1");

        result = await contract.tokenIdOf(alice);
        assert.equal(result.toString(), "2");

        result = await contract.tokenIdOf(holder);
        assert.equal(result.toString(), "3");

        result = await contract.tokenIdOf(externalUser);
        assert.equal(result.toString(), "4");
      });

    });

    describe("Referrals functions", async () => {
      it("get referrals", async () => {
        result = await contract.getReferrals(alice);
        assert.equal(result.toString(), `${holder},${externalUser}`);

        result = await contract.getReferrals(holder);
        assert.equal(result.toString(), `${bob}`);
      });

      it("get inviter", async () => {
        result = await contract.getInviter(alice);
        assert.equal(result.toString(), constants.ZERO_ADDRESS);

        result = await contract.getInviter(holder);
        assert.equal(result.toString(), `${alice}`);
      });

      it("Get referrals amount", async () => {
        result = await contract.getReferralsAmountForTwoLevels(alice);
        assert.equal(result.toString(), "3");

        result = await contract.getReferralsAmountForTwoLevels(holder);
        assert.equal(result.toString(), "1");
      });

      it("Get reward sum", async () => {
        const bnbCost = await contract.bnbCost();

        result = await contract.getRewardSum(alice);
        assert.equal(
          result.toString(),
          bnbCost.mul(BN(3)).mul(BN(10)).div(BN(100)).toString()
        );

        result = await contract.getRewardSum(holder);
        assert.equal(
          result.toString(),
          bnbCost.mul(BN(1)).mul(BN(10)).div(BN(100)).toString()
        );
      });

      it("Claim", async () => {
        const bnbCost = await contract.bnbCost();

        const sumBefore = await ethers.provider.getBalance(alice);
        assert.equal(sumBefore.toString(), "9999969008947557791224");

        result = await contract.claim({ from: alice });

        // Obtain gas used from the receipt
        expectEvent(result, "Claimed", {
          user: alice,
          reward: bnbCost.mul(BN(3)).mul(BN(10)).div(BN(100)).toString(),
        });

        const sumAfter = await ethers.provider.getBalance(alice);
        assert.equal(sumAfter.toString(), "9999978908933221742888");

        // Pause pre-sale
        await contract.setPaused(false);
      });
    });

    describe("Whitelisting works as intended", async () => {
      it("Token URI generation", async () => {
        const uriPrefix = "ipfs://__COLLECTION_CID__/1.json";

        // Reveal collection
        await contract.setBaseTokenURI(uriPrefix);

        const image0 = await contract.tokenURI(0);
        const image1 = await contract.tokenURI(1);
        const image2 = await contract.tokenURI(2);
        const image3 = await contract.tokenURI(3);
        const image4 = await contract.tokenURI(4);
        const image5 = await contract.tokenURI(5);

        console.info("image0", image0);
        console.info("image1", image1);
        console.info("image2", image2);
        console.info("image3", image3);
        console.info("image4", image4);
        console.info("image5", image5);
      });
    });
  }
);
