import { ethers } from "hardhat";
import { expect } from "chai";
import {
  DexRewardsContract,
  DEXBaseContract,
  MockRewardToken,
} from "..contracts/typechain/index";

describe("DEX and Rewards Simulation", function () {
  let dexBaseContract: DEXBaseContract;
  let dexRewardsContract: DexRewardsContract;
  let mockRewardToken: MockRewardToken;
  let accounts: any[];

  before(async function () {
    accounts = await ethers.getSigners();

    const MockRewardToken = await ethers.getContractFactory("MockRewardToken");
    mockRewardToken = await MockRewardToken.deploy();
    await mockRewardToken.deployed();

    const DexRewardsContract = await ethers.getContractFactory(
      "DexRewardsContract"
    );
    dexRewardsContract = await DexRewardsContract.deploy(
      mockRewardToken.address
    );
    await dexRewardsContract.deployed();

    const DEXBaseContract = await ethers.getContractFactory("DEXBaseContract");
    dexBaseContract = await DEXBaseContract.deploy(
      mockRewardToken.address,
      dexRewardsContract.address,
      true
    );
    await dexBaseContract.deployed();

    // Assuming the DEXRewardsContract needs to know the DEXBaseContract address
    await dexRewardsContract.setDexBaseContract(dexBaseContract.address);
  });

  it("Simulates transactions over five periods with four traders", async function () {
    // Example: Give all traders some tokens (mock setup)
    for (let i = 0; i < 4; i++) {
      await mockRewardToken.transfer(
        accounts[i].address,
        ethers.utils.parseEther("1000")
      );
    }

    // Simulate trading activity and rewards over five periods
    for (let period = 0; period < 5; period++) {
      // Example trading activity
      await dexBaseContract.openPosition(
        ethers.utils.parseEther("100"),
        true,
        1,
        { from: accounts[0].address }
      );
      await dexBaseContract.openPosition(
        ethers.utils.parseEther("50"),
        false,
        1,
        { from: accounts[1].address }
      );

      // Move to the next period by adjusting time (simplified, adjust according to your contract's time handling)
      await ethers.provider.send("evm_increaseTime", [30 * 24 * 60 * 60]); // 30 days
      await ethers.provider.send("evm_mine", []);

      // Claim rewards at the end of the period (simplified logic)
      await dexRewardsContract.claimRewards({ from: accounts[0].address });
      await dexRewardsContract.claimRewards({ from: accounts[1].address });
    }
  });
});
