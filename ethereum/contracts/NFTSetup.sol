// contracts/NFTSetup.sol
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./NFTSetters.sol";

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Upgrade.sol";

contract NFTSetup is NFTSetters, Context, ERC1967Upgrade {
    function setup(
        address implementation,
        uint16 chainId,
        address wormhole
    ) public {
        setOwner(_msgSender());

        setChainId(chainId);

        setWormhole(wormhole);

        _upgradeTo(implementation);
    }
}
