// contracts/NFTStructs.sol
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;

contract NFTStructs {
    struct Transfer {
        // PayloadID uint8 = 1
        // TokenID of the token
        uint256 tokenID;
        // URI of the token metadata (UTF-8)
        string uri;
        // Address of the recipient. Left-zero-padded if shorter than 32 bytes
        bytes32 to;
        // Chain ID of the recipient
        uint16 toChain;
    }
}
