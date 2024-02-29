import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Deploy MockRewardToken
  const MockRewardToken = await ethers.getContractFactory("MockRewardToken");
  const mockRewardToken = await MockRewardToken.deploy(); // Directly returns the contract instance
  await mockRewardToken.deploymentTransaction()?.wait();
  console.log("MockRewardToken deployed to:", mockRewardToken.getAddress());

  // Deploy DexRewardsContract with the address of MockRewardToken
  const DexRewardsContract = await ethers.getContractFactory(
    "DexRewardsContract"
  );
  const dexRewardsContract = await DexRewardsContract.deploy(
    mockRewardToken.getAddress()
  );
  await dexRewardsContract.deploymentTransaction()?.wait();
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
  await dexBaseContract.deploymentTransaction()?.wait();
  console.log("DEXBaseContract deployed to:", dexBaseContract.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
