require("dotenv").config({ path: "../.env" });

// CONFIG
const chainId = process.env.INIT_CHAIN_ID;
const wormholeAddress = process.env.INIT_WORMHOLE_ADDRESS;

const NFT = artifacts.require("NFT");
const NFTImplementation = artifacts.require("NFTImplementation");
const NFTSetup = artifacts.require("NFTSetup");

module.exports = async function(deployer) {
  // deploy setup
  await deployer.deploy(NFTSetup);

  // deploy implementation
  await deployer.deploy(NFTImplementation);

  // encode initialisation data
  const setup = new web3.eth.Contract(NFTSetup.abi, NFTSetup.address);
  const initData = setup.methods
    .setup(NFTImplementation.address, chainId, wormholeAddress)
    .encodeABI();

  // deploy proxy
  await deployer.deploy(NFT, NFTSetup.address, initData);
};
