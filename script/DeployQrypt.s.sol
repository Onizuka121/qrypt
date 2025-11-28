// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/QryptGiftCard.sol";

contract DeployQrypt is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        QryptGiftCard q = new QryptGiftCard();
        vm.stopBroadcast();

        console2.log("QryptGiftCard deployed at:", address(q));
    }
}
