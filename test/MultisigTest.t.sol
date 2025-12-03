// SPDX License Identifier: MIT

pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {OffChainMultisig} from "src/Multisig.sol";
import {MockContract} from "./mocks/MockContract.sol";

contract OffChainMultisigTest is Test {
    OffChainMultisig public multisig;

    struct Owner {
        address addr;
        uint256 pk;
    }

    Owner[] public owners;
    uint256 constant THRESHOLD = 3;

    bytes32 private constant TX_TYPEHASH = keccak256("Transaction(address to,uint256 value,bytes data,uint256 nonce)");

    function setUp() public {

        string[3] memory labels = ["alice", "bob", "charlie"];
        
        for(uint i=0; i<3; i++){
            (address addr, uint256 pk) = makeAddrAndKey(labels[i]);
            owners.push(Owner(addr, pk));
        }

        _sortOwners();

        address[] memory ownerAddrs = new address[](3);
        ownerAddrs[0] = owners[0].addr;
        ownerAddrs[1] = owners[1].addr;
        ownerAddrs[2] = owners[2].addr;

        multisig = new OffChainMultisig(ownerAddrs, THRESHOLD);
        
        vm.deal(address(multisig), 10 ether);
    }

    function test_ExecuteSimpleTransfer() public {
        address recipient = makeAddr("recipient");
        uint256 value = 1 ether;
        bytes memory data = ""; // empty data for eth transfers
        uint256 nonce = 0;

        bytes32 digest = _getEIP712Digest(recipient, value, data, nonce);

        bytes[] memory signatures = new bytes[](3);
        signatures[0] = _sign(owners[0].pk, digest);
        signatures[1] = _sign(owners[1].pk, digest);
        signatures[2] = _sign(owners[2].pk, digest);

        uint256 balBefore = recipient.balance;
        multisig.executeWithSignatures(recipient, value, data, nonce, signatures);
        uint256 balAfter = recipient.balance;

        assertEq(balAfter - balBefore, 1 ether, "ETH not received");
        assertTrue(multisig.isExecutedTx(nonce), "nonce should be marked as executed");
    }

    function test_ExecuteSetValueOnMock() public {

        MockContract mock = new MockContract(2);
        uint256 newValue = 8;

        bytes memory data = abi.encodeWithSelector(MockContract.setValue.selector, newValue);
        
        address to = address(mock);
        uint256 value = 0; 
        uint256 nonce = 0;

        bytes32 digest = _getEIP712Digest(to, value, data, nonce);

        bytes[] memory signatures = new bytes[](3);
        signatures[0] = _sign(owners[0].pk, digest);
        signatures[1] = _sign(owners[1].pk, digest);
        signatures[2] = _sign(owners[2].pk, digest);

        multisig.executeWithSignatures(to, value, data, nonce, signatures);

        assertEq(mock.value(), newValue, "Value not updated in mockContract");
    }

    function test_RevertIf_SignaturesUnsorted() public {
        address recipient = makeAddr("recipient");
        bytes32 digest = _getEIP712Digest(recipient, 1 ether, "", 0);

        bytes[] memory signatures = new bytes[](3);
        signatures[0] = _sign(owners[1].pk, digest); 
        signatures[1] = _sign(owners[0].pk, digest); 
        signatures[2] = _sign(owners[2].pk, digest); 

        vm.expectRevert(OffChainMultisig.OffChainMultisig_SignerNotUnique.selector);
        multisig.executeWithSignatures(recipient, 1 ether, "", 0, signatures);
    }

    function test_RevertIf_InvalidSigner() public {
        address recipient = makeAddr("recipient");
        bytes32 digest = _getEIP712Digest(recipient, 1 ether, "", 0);

        (, uint256 hackerPk) = makeAddrAndKey("attacker");
        
        bytes[] memory signatures = new bytes[](3);
        signatures[0] = _sign(owners[0].pk, digest); 
        signatures[1] = _sign(hackerPk, digest);   // invalid firm
        signatures[2] = _sign(owners[2].pk, digest); 

        vm.expectRevert(OffChainMultisig.OffChainMultisig_InvalidSigner.selector);
        multisig.executeWithSignatures(recipient, 1 ether, "", 0, signatures);
    }

    /* //////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    ////////////////////////////////////////////////////////////// */

    function _sign(uint256 pk, bytes32 digest) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }

    function _getEIP712Digest(address to, uint256 value, bytes memory data, uint256 nonce) internal view returns (bytes32) {

        bytes32 domainSeparator = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes("Multisig")),
            keccak256(bytes("1")),       
            block.chainid,
            address(multisig)
        ));

        bytes32 structHash = keccak256(abi.encode(
            TX_TYPEHASH,
            to,
            value,
            keccak256(data),
            nonce
        ));

        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }

    function _sortOwners() internal {
        for (uint i = 0; i < owners.length - 1; i++) {
            for (uint j = 0; j < owners.length - i - 1; j++) {
                if (owners[j].addr > owners[j + 1].addr) {
                    Owner memory temp = owners[j];
                    owners[j] = owners[j + 1];
                    owners[j + 1] = temp;
                }
            }
        }
    }
}