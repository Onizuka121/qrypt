// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/QryptGiftCard.sol";

contract RedeemGiftCard is Script {
    function run() external {
        uint256 pk_bob = vm.envUint("PRIVATE_KEY_BOB");
        address bob = vm.addr(pk_bob);

        //raccgliamo i dati per riscattare
        QryptGiftCard q = QryptGiftCard(vm.envAddress("C_ADDR"));
        uint256 giftId = vm.envUint("GIFT_ID");
        string memory segreto = vm.envString("SEGRETO");
        uint256 ephPrivKey = vm.envUint("EPHEMERAL_PRIVKEY");

        // costruiamo adesso il messaggio come nel contrato in QryptGiftCard:
        // keccak256("QRYPT_REDEEM", address(this), giftId, recipient)
        bytes32 message = keccak256(
            abi.encodePacked("QRYPT_REDEEM", address(q), giftId, bob)
        );
        bytes32 ethSignedMessage = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", message)
        );

        // firmiamo con l'indirizzo del walet effimero 
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ephPrivKey, ethSignedMessage);
        bytes memory sig = abi.encodePacked(r, s, v);

        //inzia trasazione -> fa il redeem -> fine transazione
        vm.startBroadcast(pk_bob);
        q.redeem(giftId, segreto, sig, payable(bob));
        vm.stopBroadcast();
    }
}