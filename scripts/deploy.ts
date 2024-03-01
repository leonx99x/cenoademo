import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.getAddress());

  // Deploy MockRewardToken
  const MockRewardToken = await ethers.getContractFactory("MockRewardToken");
  const mockRewardToken = await MockRewardToken.deploy();
  await mockRewardToken.waitForDeployment();
  console.log("MockRewardToken deployed to:", mockRewardToken.address);

  // Deploy DexRewardsContract with the address of MockRewardToken
  const DexRewardsContract = await ethers.getContractFactory(
    "DexRewardsContract"
  );
  const dexRewardsContract = await DexRewardsContract.deploy(
    mockRewardToken.getAddress()
  );
  await dexRewardsContract.waitForDeployment();
  console.log(
    "DexRewardsContract deployed to:",
    dexRewardsContract.getAddress()
  );

  // Deploy DEXBaseContract with the required parameters
  const DEXBaseContract = await ethers.getContractFactory("DEXBaseContract");
  const dexBaseContract = await DEXBaseContract.deploy(
    mockRewardToken.getAddress(),
    dexRewardsContract.getAddress(),
    true
  );
  await dexBaseContract.waitForDeployment();
  await dexRewardsContract.setDexBaseContract(dexBaseContract.getAddress());
  console.log("DEXBaseContract deployed to:", dexBaseContract.getAddress());
  console.log("MockRewardToken address:", mockRewardToken.getAddress());
  console.log("DexRewardsContract address:", dexRewardsContract.getAddress());
  console.log("DEXBaseContract address:", dexBaseContract.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
