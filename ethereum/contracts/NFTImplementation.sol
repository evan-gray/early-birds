// contracts/NFTImplementation.sol
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;

import "./NFTGetters.sol";
import "./NFTSetters.sol";
import "./NFTStructs.sol";
import "./libraries/external/BytesLib.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

// Based on the OpenZepplin ERC721 implementation, licensed under MIT
contract NFTImplementation is NFTGetters, NFTSetters, Context, IERC721, IERC721Metadata, ERC165 {
    using BytesLib for bytes;
    using Address for address;
    using Strings for uint256;

    // Initiate a Transfer over Wormhole
    function wormholeTransfer(uint256 tokenID, uint16 recipientChain, bytes32 recipient, uint32 nonce) public payable returns (uint64 sequence) {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenID), "ERC721: transfer caller is not owner nor approved");
        string memory uriString = tokenURI(tokenID);
        burn(tokenID);
        sequence = logTransfer(NFTStructs.Transfer({
            tokenID      : tokenID,
            uri          : uriString,
            to           : recipient,
            toChain      : recipientChain
        }), msg.value, nonce);
    }

    function logTransfer(NFTStructs.Transfer memory transfer, uint256 callValue, uint32 nonce) internal returns (uint64 sequence) {
        bytes memory encoded = encodeTransfer(transfer);

        sequence = wormhole().publishMessage{
            value : callValue
        }(nonce, encoded, 15);
    }

    function completeWormholeTransfer(bytes memory encodedVm) public {
        _completeWormholeTransfer(encodedVm);
    }

    // Execute a Wormhole Transfer message
    function _completeWormholeTransfer(bytes memory encodedVm) internal {
        (IWormhole.VM memory vm, bool valid, string memory reason) = wormhole().parseAndVerifyVM(encodedVm);

        require(valid, reason);
        require(verifyBridgeVM(vm), "invalid emitter");

        NFTStructs.Transfer memory transfer = parseTransfer(vm.payload);

        require(!isTransferCompleted(vm.hash), "transfer already completed");
        setTransferCompleted(vm.hash);

        require(transfer.toChain == chainId(), "invalid target chain");

        // transfer bridged NFT to recipient
        address transferRecipient = address(uint160(uint256(transfer.to)));

        mint(transferRecipient, transfer.tokenID, transfer.uri);
    }

    function verifyBridgeVM(IWormhole.VM memory vm) internal view returns (bool){
        if (bridgeContracts(vm.emitterChainId) == vm.emitterAddress) {
            return true;
        }

        return false;
    }

    function encodeTransfer(NFTStructs.Transfer memory transfer) public pure returns (bytes memory encoded) {
        encoded = abi.encodePacked(
            uint8(1),
            transfer.tokenID,
            uint8(bytes(transfer.uri).length),
            transfer.uri,
            transfer.to,
            transfer.toChain
        );
    }

    function parseTransfer(bytes memory encoded) public pure returns (NFTStructs.Transfer memory transfer) {
        uint index = 0;

        uint8 payloadID = encoded.toUint8(index);
        index += 1;

        require(payloadID == 1, "invalid Transfer");

        transfer.tokenID = encoded.toUint256(index);
        index += 32;

        uint8 len_uri = encoded.toUint8(index);
        index += 1;

        transfer.uri = string(encoded.slice(index, len_uri));
        index += len_uri;

        transfer.to = encoded.toBytes32(index);
        index += 32;

        transfer.toChain = encoded.toUint16(index);
        index += 2;

        require(encoded.length == index, "invalid Transfer");
    }

    function registerChain(uint16 chainId_, bytes32 bridgeContract_) public onlyOwner {
        setBridgeImplementation(chainId_, bridgeContract_);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC165, IERC165) returns (bool) {
        return
        interfaceId == type(IERC721).interfaceId ||
        interfaceId == type(IERC721Metadata).interfaceId ||
        super.supportsInterface(interfaceId);
    }

    function balanceOf(address owner_) public view override returns (uint256) {
        require(owner_ != address(0), "ERC721: balance query for the zero address");
        return _state.balances[owner_];
    }

    function ownerOf(uint256 tokenId) public view override returns (address) {
        address owner_ = _state.owners[tokenId];
        require(owner_ != address(0), "ERC721: owner query for nonexistent token");
        return owner_;
    }

    function name() public view override returns (string memory) {
        return _state.name;
    }

    function symbol() public view override returns (string memory) {
        return _state.symbol;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        return _state.tokenURIs[tokenId];
    }

    function owner() public view returns (address) {
        return _state.owner;
    }

    function approve(address to, uint256 tokenId) public override {
        address owner_ = NFTImplementation.ownerOf(tokenId);
        require(to != owner_, "ERC721: approval to current owner");

        require(
            _msgSender() == owner_ || isApprovedForAll(owner_, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    function getApproved(uint256 tokenId) public view override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _state.tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) public override {
        require(operator != _msgSender(), "ERC721: approve to caller");

        _state.operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    function isApprovedForAll(address owner_, address operator) public view override returns (bool) {
        return _state.operatorApprovals[owner_][operator];
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return _state.owners[tokenId] != address(0);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner_ = NFTImplementation.ownerOf(tokenId);
        return (spender == owner_ || getApproved(tokenId) == spender || isApprovedForAll(owner_, spender));
    }

    function mint(address to, uint256 tokenId, string memory uri) public onlyOwner {
        _mint(to, tokenId, uri);
    }

    function _mint(address to, uint256 tokenId, string memory uri) internal {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _state.balances[to] += 1;
        _state.owners[tokenId] = to;
        _state.tokenURIs[tokenId] = uri;

        emit Transfer(address(0), to, tokenId);
    }

    function burn(uint256 tokenId) public onlyOwner {
        _burn(tokenId);
    }

    function _burn(uint256 tokenId) internal {
        address owner_ = NFTImplementation.ownerOf(tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _state.balances[owner_] -= 1;
        delete _state.owners[tokenId];

        emit Transfer(owner_, address(0), tokenId);
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal {
        require(NFTImplementation.ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _state.balances[from] -= 1;
        _state.balances[to] += 1;
        _state.owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function _approve(address to, uint256 tokenId) internal {
        _state.tokenApprovals[tokenId] = to;
        emit Approval(NFTImplementation.ownerOf(tokenId), to, tokenId);
    }

    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "caller is not the owner");
        _;
    }
}
