// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/QryptGiftCard.sol";

contract CreateGiftCard is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY"); // Alice
        address alice = vm.addr(pk);

        address contractAddress = vm.envAddress("C_ADDR");
        QryptGiftCard q = QryptGiftCard(contractAddress);

        string memory secret = "hackathon-secret-123";
        bytes32 secretHash = keccak256(abi.encodePacked(secret));

        uint256 ephPrivKey = 0xBEEF;
        address ephAddr = vm.addr(ephPrivKey);

        vm.startBroadcast(pk);

        uint64 durationSeconds = 3600;
        uint256 amount = 0.1 ether;

        uint256 giftId = q.createGiftCard{value: amount}(
            secretHash,
            ephAddr,
            durationSeconds
        );

        vm.stopBroadcast();

        console2.log("=== QRYPT GIFT CARD DATA ===");
        console2.log("Alice (sender):", alice);
        console2.log("Contract:", contractAddress);
        console2.log("GiftId:", giftId);
        console2.log("Secret:", secret);
        console2.log("Ephemeral private key (decimale):");
        console2.logUint(ephPrivKey);
        console2.log("Ephemeral address:", ephAddr);

        console2.log("JSON payload:");
        console2.log(
            string(
                abi.encodePacked(
                    "{\"contractAddress\":\"",
                    vm.toString(contractAddress),
                    "\",\"giftId\":\"",
                    vm.toString(giftId),
                    "\",\"secret\":\"",
                    secret,
                    "\",\"ephemeralPrivKey\":\"",
                    vm.toString(ephPrivKey),
                    "\"}"
                )
            )
        );
    }
}
