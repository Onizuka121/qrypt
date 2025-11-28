// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/QryptGiftCard.sol";

contract QryptGiftCardTest is Test {
    QryptGiftCard public q;
    address public alice;
    address public bob;

    function setUp() public {
        q = new QryptGiftCard();
        alice = address(0xA11CE);
        bob   = address(0xB0B);
        vm.deal(alice, 10 ether);
    }

    function testCreateGiftCard() public {
        string memory secret = "segretone-di-test";
        bytes32 secretHash = keccak256(abi.encodePacked(secret));

        vm.prank(alice);
        q.createGiftCard{value: 1 ether}(
            secretHash,
            address(0xEFFE),
            3600
        );

        uint256 giftId = q.lastGiftId();

        (
            address sender,
            uint256 amount,
            bytes32 storedHash,
            address eph,
            uint64 expiresAt,
            bool claimed
        ) = q.gifts(giftId);

        assertEq(sender, alice);
        assertEq(amount, 1 ether);
        assertEq(storedHash, secretHash);
        assertEq(eph, address(0xEFFE));
        assertGt(expiresAt, 0);
        assertEq(claimed, false);
    }

    function testRedeemWith2FA() public {
        string memory secret = "secondo-segreto";
        bytes32 secretHash = keccak256(abi.encodePacked(secret));

        uint256 ephPrivKey = 0x1234;
        address ephAddr = vm.addr(ephPrivKey);

        vm.prank(alice);
        q.createGiftCard{value: 2 ether}(
            secretHash,
            ephAddr,
            3600
        );

        uint256 giftId = q.lastGiftId();

        bytes32 message = keccak256(
            abi.encodePacked("QRYPT_REDEEM", address(q), giftId, bob)
        );
        bytes32 ethSignedMessage = _toEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ephPrivKey, ethSignedMessage);
        bytes memory sig = abi.encodePacked(r, s, v);

        uint256 bobBalanceBefore = bob.balance;

        vm.prank(bob);
        q.redeem(giftId, secret, sig, payable(bob));

        (
            ,
            uint256 amountAfter,
            ,
            ,
            ,
            bool claimed
        ) = q.gifts(giftId);

        assertTrue(claimed);
        assertEq(amountAfter, 0);

        uint256 bobBalanceAfter = bob.balance;
        assertEq(bobBalanceAfter, bobBalanceBefore + 2 ether);
    }

    function testRefundAfterExpiry() public {
        string memory secret = "terzo-segreto";
        bytes32 secretHash = keccak256(abi.encodePacked(secret));

        vm.prank(alice);
        q.createGiftCard{value: 0.5 ether}(
            secretHash,
            address(0xEEEE),
            10
        );

        uint256 giftId = q.lastGiftId();

        vm.warp(block.timestamp + 20);

        uint256 aliceBefore = alice.balance;

        vm.prank(alice);
        q.refund(giftId);

        uint256 aliceAfter = alice.balance;
        assertEq(aliceAfter, aliceBefore + 0.5 ether);

        (
            ,
            uint256 amountAfter,
            ,
            ,
            ,
            bool claimed
        ) = q.gifts(giftId);

        assertTrue(claimed);
        assertEq(amountAfter, 0);
    }

    function _toEthSignedMessageHash(bytes32 message) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", message)
        );
    }
}
