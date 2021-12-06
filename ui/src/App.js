import { createNonce, parseSequenceFromLogEth } from "@certusone/wormhole-sdk";
import getSignedVAAWithRetry from "@certusone/wormhole-sdk/lib/esm/rpc/getSignedVAAWithRetry";
import { hexlify, hexStripZeros, hexZeroPad } from "@ethersproject/bytes";
import { JsonRpcProvider } from "@ethersproject/providers";
import {
  AppBar,
  Button,
  Card,
  CardContent,
  CircularProgress,
  Toolbar,
  Tooltip,
  Typography,
} from "@mui/material";
import { Box } from "@mui/system";
import { useCallback, useEffect, useState } from "react";
import { useEthereumProvider } from "./EthereumProviderContext";
import { NFTImplementation__factory } from "./ethers-contracts";

const WORMHOLE_RPC_HOSTS = ["http://localhost:7071"];
const BSC_CONTRACT_ADDRESS = "0xc34175A79ACca40392bECD22ff10fAeBFE780Ae7";
const BSC_RPC = "http://localhost:8546";
const ETH_CONTRACT_ADDRESS = "0xc34175A79ACca40392bECD22ff10fAeBFE780Ae7";
const ETH_RPC = "http://localhost:8545";

const chainToColor = (c) =>
  c === -1
    ? "red"
    : c === 2
    ? "rgb(69,74,117)"
    : c === 4
    ? "#F0B90B"
    : "lightgray";
const chainToName = (c) =>
  c === -1
    ? "Error"
    : c === 2
    ? "Ethereum"
    : c === 4
    ? "Binance Smart Chain"
    : "[In Transit]";
const chainToNetwork = (c) =>
  hexStripZeros(hexlify(c === 2 ? 1337 : c === 4 ? 1397 : 0));
const chainToContract = (c) =>
  c === 2 ? ETH_CONTRACT_ADDRESS : c === 4 ? BSC_CONTRACT_ADDRESS : "";

function NFTSquare({ tokenId, chainId }) {
  const { provider, signer, signerAddress } = useEthereumProvider();
  const handleClick = useCallback(() => {
    if (!signer) return;
    if (chainId !== 2 && chainId !== 4) return;
    (async () => {
      await provider.send("wallet_switchEthereumChain", [
        { chainId: chainToNetwork(chainId) },
      ]);
      const toChain = chainId === 2 ? 4 : 2;
      const sendNFT = NFTImplementation__factory.connect(
        chainToContract(chainId),
        signer
      );
      console.log(tokenId);
      console.log(await sendNFT.tokenURI(tokenId));
      const sendTx = await sendNFT.wormholeTransfer(
        tokenId,
        toChain,
        hexZeroPad(signerAddress, 32),
        createNonce()
      );
      const sendReceipt = await sendTx.wait();
      console.log(sendReceipt);
      const sequence = parseSequenceFromLogEth(
        sendReceipt,
        await sendNFT.wormhole()
      );
      const { vaaBytes } = await getSignedVAAWithRetry(
        WORMHOLE_RPC_HOSTS,
        chainId,
        chainToContract(chainId),
        sequence.toString()
      );
      console.log(vaaBytes);
      await provider.send("wallet_switchEthereumChain", [
        { chainId: chainToNetwork(toChain) },
      ]);
      const recNFT = NFTImplementation__factory.connect(
        chainToContract(toChain),
        signer
      );
      const recTx = await recNFT.completeWormholeTransfer(vaaBytes);
      const recReceipt = await recTx.wait();
      console.log(recReceipt);
    })();
  }, [tokenId, chainId, provider, signer, signerAddress]);

  return (
    <Tooltip title={`Current Chain: ${chainToName(chainId)}`}>
      <Box
        sx={{
          height: 20,
          width: 20,
          m: 2,
          backgroundColor: chainToColor(chainId),
          ":hover": {
            border: "4px solid lightgreen",
            cursor: "pointer",
          },
        }}
        onClick={handleClick}
      ></Box>
    </Tooltip>
  );
}

function App() {
  const { connect, disconnect, signerAddress } = useEthereumProvider();
  const [state, setState] = useState([]);
  useEffect(() => {
    (async () => {
      const bscProvider = new JsonRpcProvider(BSC_RPC);
      const bscNFT = NFTImplementation__factory.connect(
        BSC_CONTRACT_ADDRESS,
        bscProvider
      );
      const bscOwners = [];
      for (let i = 1; i <= 20; i++) {
        try {
          const owner = await bscNFT.ownerOf(i);
          bscOwners.push(owner);
        } catch (e) {
          // owner query for nonexistent token
          bscOwners.push(undefined);
        }
      }
      console.log("bscOwners", bscOwners);
      const ethProvider = new JsonRpcProvider(ETH_RPC);
      const ethNFT = NFTImplementation__factory.connect(
        ETH_CONTRACT_ADDRESS,
        ethProvider
      );
      const ethOwners = [];
      for (let i = 1; i <= 20; i++) {
        try {
          const owner = await ethNFT.ownerOf(i);
          ethOwners.push(owner);
        } catch (e) {
          // owner query for nonexistent token
          ethOwners.push(undefined);
        }
      }
      console.log("ethOwners", ethOwners);
      const currentChain = [];
      for (let i = 0; i <= 19; i++) {
        if (bscOwners[i] && ethOwners[i]) {
          console.error("this shouldn't be owned on multiple chains at once!");
          currentChain.push(-1);
        } else if (bscOwners[i]) {
          currentChain.push(4);
        } else if (ethOwners[i]) {
          currentChain.push(2);
        } else {
          currentChain.push(0);
        }
      }
      setState(currentChain);
    })();
  }, []);
  return (
    <>
      <AppBar position="static">
        <Toolbar>
          <Typography variant="h6" component="h1" sx={{ flexGrow: 1 }}>
            Early Birds
          </Typography>
          {signerAddress ? (
            <Button
              variant="outlined"
              color="inherit"
              onClick={disconnect}
              sx={{ textTransform: "none" }}
            >
              {signerAddress.substr(0, 5)}
              ...
              {signerAddress.substr(signerAddress.length - 3)}
            </Button>
          ) : (
            <Button variant="contained" color="secondary" onClick={connect}>
              Connect Wallet
            </Button>
          )}
        </Toolbar>
      </AppBar>
      <Card
        sx={{
          m: 2,
          textAlign: "center",
        }}
        elevation={4}
      >
        <CardContent>
          <Typography variant="h5" sx={{ mb: 2 }}>
            Current Distribution
          </Typography>
          {state.length === 0 ? (
            <CircularProgress />
          ) : (
            <>
              <Box
                sx={{
                  display: "flex",
                  flexWrap: "wrap",
                  maxWidth: 260,
                  margin: "auto",
                }}
              >
                {state.map((c, idx) => (
                  <NFTSquare key={idx} tokenId={idx} chainId={c} />
                ))}
              </Box>
            </>
          )}
        </CardContent>
      </Card>
    </>
  );
}

export default App;
