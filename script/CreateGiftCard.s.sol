// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/QryptGiftCard.sol";

contract CreateGiftCard is Script {
    function run() external {
        uint256 pk_john = vm.envUint("PRIVATE_KEY_JOHN");
        //calcoliamo indirizzo di Johnnnn
        address john = vm.addr(pk_john);

        address contractAddress = vm.envAddress("C_ADDR");
        //creiamo istanza per usare il contract 
        QryptGiftCard q = QryptGiftCard(contractAddress);

        string memory segreto = "hackathon-segreto-123";
        bytes32 segretoHash = keccak256(abi.encodePacked(segreto));

        // private key per indirizzo del wallet effimero SEMPLIFICATA (per demo) 
        uint256 ephPrivKey = 0xBEEF;
        //calc indirizzo del wallet effimero
        address ephAddr = vm.addr(ephPrivKey);

        //contract firmato come John
        vm.startBroadcast(pk_john);
        //IMPORTO
        uint256 amount = 0.1 ether;
        //crea gift card
        uint256 giftId = q.createGiftCard{value: amount}(
            segretoHash,
            ephAddr
        );
        //fine transaction
        vm.stopBroadcast();

        console2.log("------------------------------ DATI GENERATI ---------------------");
        console2.log("John (sender):", john);
        console2.log("Contract:", contractAddress);
        console2.log("GiftId:", giftId);
        console2.log("segreto:", segreto);
        console2.log("Ephemeral private key:");
        console2.logUint(ephPrivKey);
        console2.log("Ephemeral address:", ephAddr);

    }
}
