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

    // Register the Eth endpoint on BSC
    await initialized.methods
      .registerChain(
        2,
        "0x0000000000000000000000006793E8E0E8ac22d71c65c2bf82e9B142dEf9eCDb"
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
