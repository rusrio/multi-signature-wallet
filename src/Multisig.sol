// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract OffChainMultisig is EIP712 {
    using ECDSA for bytes32;

    error OffChainMultisig_TxAlreadyExecuted();
    error OffChainMultisig_NotEnoughSignatures();
    error OffChainMultisig_InvalidSigner();
    error OffChainMultisig_TxFailed();
    error OffChainMultisig_SignerNotUnique();
    error OffChainMultisig_ThresholdMustBeEqualOrLessThanOwners();


    address[] private owners;
    mapping(address => bool) public isOwner;
    uint public threshold;
    // mapping to prevent replay attacks
    mapping(uint => bool) public isExecutedTx; 

    bytes32 private constant TX_TYPEHASH = keccak256("Transaction(address to,uint256 value,bytes data,uint256 nonce)");

    constructor(address[] memory _owners, uint _threshold) EIP712("Multisig", "1") {
        if(threshold > _owners.length){revert OffChainMultisig_ThresholdMustBeEqualOrLessThanOwners();}
        owners = _owners;
        threshold = _threshold;
        for(uint i=0; i<_owners.length; i++) {
            isOwner[_owners[i]] = true;
        }
    }

    function executeWithSignatures(
        address to, 
        uint256 value, 
        bytes memory data, 
        uint256 nonce, 
        bytes[] memory signatures
    ) external {
        require(!isExecutedTx[nonce], OffChainMultisig_TxAlreadyExecuted());
        require(signatures.length >= threshold, OffChainMultisig_NotEnoughSignatures());

        // recreate the message that owners signed offchain
        bytes32 structHash = keccak256(abi.encode(
            TX_TYPEHASH,
            to,
            value,
            keccak256(data),
            nonce
        ));
        
        // follow the OpenZeppelin's EIP712 implementation
        bytes32 digest = _hashTypedDataV4(structHash);

        address lastSigner = address(0); 
        
        for (uint i = 0; i < signatures.length; i++) {
            address signer = digest.recover(signatures[i]);
            
            require(isOwner[signer], OffChainMultisig_InvalidSigner());
            require(signer > lastSigner, OffChainMultisig_SignerNotUnique());
            
            lastSigner = signer;
        }

        // execute transaction
        isExecutedTx[nonce] = true;
        (bool success, ) = to.call{value: value}(data);
        require(success, OffChainMultisig_TxFailed());
    }

    function getOwners() public view returns(address[] memory){
        return owners;
    }
}