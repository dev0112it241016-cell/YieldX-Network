const { ethers } = require("hardhat");

async function main() {
  const YieldXNetwork = await ethers.getContractFactory("YieldXNetwork");
  const yieldXNetwork = await YieldXNetwork.deploy();

  await yieldXNetwork.deployed();

  console.log("YieldXNetwork contract deployed to:", yieldXNetwork.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
