import { ethers } from "hardhat";
import { expect } from "chai";
import {
  DexRewardsContract,
  DEXBaseContract,
  MockRewardToken,
} from "../typechain";

describe("DEX and Rewards Simulation", function () {
  let dexBaseContract: DEXBaseContract;
  let dexRewardsContract: DexRewardsContract;
  let mockRewardToken: MockRewardToken;
  let accounts: any[];

  before(async function () {
    accounts = await ethers.getSigners();

    // Deploy MockRewardToken
    const MockRewardTokenFactory = await ethers.getContractFactory(
      "MockRewardToken"
    );
    mockRewardToken = await MockRewardTokenFactory.deploy();
    await mockRewardToken.waitForDeployment();
    console.log("MockRewardToken deployed to:", mockRewardToken.getAddress());

    // Deploy DexRewardsContract (assuming Ownable's constructor does not actually take parameters)
    const DexRewardsContractFactory = await ethers.getContractFactory(
      "DexRewardsContract"
    );
    dexRewardsContract = await DexRewardsContractFactory.deploy(
      mockRewardToken.getAddress(),
      accounts[0].address
    );
    await dexRewardsContract.waitForDeployment();
    console.log(
      "DexRewardsContract deployed to:",
      dexRewardsContract.getAddress()
    );

    // Deploy DEXBaseContract
    const DEXBaseContractFactory = await ethers.getContractFactory(
      "DEXBaseContract"
    );
    dexBaseContract = await DEXBaseContractFactory.deploy(
      mockRewardToken.getAddress(),
      dexRewardsContract.getAddress(),
      true
    );
    await dexBaseContract.waitForDeployment();
    await dexRewardsContract.setDexBaseContract(
      await dexBaseContract.getAddress()
    );
    console.log("DEXBaseContract deployed to:", dexBaseContract.getAddress());

    // Transfer tokens to other accounts for trading
    for (let i = 1; i <= 4; i++) {
      await mockRewardToken.transfer(
        accounts[i].address,
        ethers.parseEther("1000")
      );
      console.log(`Transferred 1000 tokens to account ${i}`);
    }
    await mockRewardToken.transfer(
      await dexRewardsContract.getAddress(),
      ethers.parseEther("100000")
    );
    await dexRewardsContract.transferOwnership(
      await dexBaseContract.getAddress()
    );
  });
  it("Simulates transactions over five periods with four traders", async function () {
    for (let period = 0; period < 5; period++) {
      console.log("Starting period", period);
      console.log("Opening positions for accounts 1 and 2");
      const approve = await mockRewardToken
        .connect(accounts[1])
        .approve(await dexBaseContract.getAddress(), ethers.parseEther("100"));
      await mockRewardToken
        .connect(accounts[2])
        .approve(await dexBaseContract.getAddress(), ethers.parseEther("50"));
      await dexBaseContract
        .connect(accounts[1])
        .openPosition(ethers.parseEther("100"), true, 1);
      console.log("Opened position for account 1");
      await ethers.provider.send("evm_mine", []);
      await dexBaseContract
        .connect(accounts[2])
        .openPosition(ethers.parseEther("50"), false, 1);
      console.log("Opened position for account 2");
      await ethers.provider.send("evm_mine", []);

      await ethers.provider.send("evm_increaseTime", [30 * 24 * 60 * 60]); // 30 days
      console.log("Time increased by 30 days");

      await dexRewardsContract.connect(accounts[1]).claimRewards();
      await dexRewardsContract.connect(accounts[2]).claimRewards();
    }
  });
});
