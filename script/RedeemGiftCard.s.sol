// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/QryptGiftCard.sol";

contract RedeemGiftCard is Script {
    function run() external {
        // Bob (chi riscatta e riceve i fondi)
        uint256 bobPk = vm.envUint("PRIVATE_KEY_BOB");
        address bob = vm.addr(bobPk);

        // Contratto + parametri gift card
        QryptGiftCard q = QryptGiftCard(vm.envAddress("C_ADDR"));
        uint256 giftId = vm.envUint("GIFT_ID");
        string memory secret = vm.envString("SECRET");

        // Wallet effimero (secondo fattore)
        uint256 ephPrivKey = vm.envUint("EPHEMERAL_PRIVKEY");

        // Costruisco il messaggio come nel contratto:
        // keccak256("QRYPT_REDEEM", address(this), giftId, recipient)
        bytes32 message = keccak256(
            abi.encodePacked("QRYPT_REDEEM", address(q), giftId, bob)
        );

        // Applico il prefisso Ethereum Signed Message
        bytes32 ethSignedMessage = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", message)
        );

        // Firmo con la chiave del wallet effimero
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ephPrivKey, ethSignedMessage);
        bytes memory sig = abi.encodePacked(r, s, v);

        // Broadcast come Bob: chiama redeem e riceve i fondi
        vm.startBroadcast(bobPk);
        q.redeem(giftId, secret, sig, payable(bob));
        vm.stopBroadcast();
    }
}