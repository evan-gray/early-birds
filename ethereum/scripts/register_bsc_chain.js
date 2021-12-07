// run this script with truffle exec

const jsonfile = require("jsonfile");
const NFT = artifacts.require("NFT");
const NFTImplementationFullABI = jsonfile.readFileSync(
  "../build/contracts/NFTImplementation.json"
).abi;

module.exports = async function(callback) {
  try {
    const accounts = await web3.eth.getAccounts();
    const initialized = new web3.eth.Contract(
      NFTImplementationFullABI,
      NFT.address
    );

    // Register the BSC endpoint on Eth
    await initialized.methods
      .registerChain(
        4,
        "0x000000000000000000000000B349FB172D6D5f693b0aA1C6eEc4c61cFd6846f4"
      )
      .send({
        value: 0,
        from: accounts[0],
        gasLimit: 2000000,
      });

    callback();
  } catch (e) {
    callback(e);
  }
};
