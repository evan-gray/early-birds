// contracts/NFTSetters.sol
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;

import "./NFTState.sol";

contract NFTSetters is NFTState {
    function setOwner(address owner_) internal {
        _state.owner = owner_;
    }

    function setWormhole(address wh) internal {
        _state.wormhole = payable(wh);
    }

    function setChainId(uint16 chainId_) internal {
        _state.chainId = chainId_;
    }

    function setTransferCompleted(bytes32 hash) internal {
        _state.completedTransfers[hash] = true;
    }

    function setBridgeImplementation(uint16 chainId, bytes32 bridgeContract) internal {
        _state.bridgeImplementations[chainId] = bridgeContract;
    }
}