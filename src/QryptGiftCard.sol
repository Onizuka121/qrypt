// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title QryptGiftCard - Gift card crypto con 2FA on-chain (segreto + wallet effimero)
/// @notice Versione semplificata per demo su chain EVM (es. Avalanche C-Chain)
contract QryptGiftCard {
    struct GiftCard {
        address sender;          // Chi ha creato la gift card (Alice)
        uint256 amount;          // Importo bloccato (es. AVAX)
        bytes32 secretHash;      // Hash del segreto (keccak256)
        address ephemeralWallet; // Wallet effimero usato come 2FA
        uint64  expiresAt;       // Timestamp di scadenza (per refund)
        bool    claimed;         // True se gia' riscattata o rimborsata
    }

    uint256 public lastGiftId;
    mapping(uint256 => GiftCard) public gifts;

    event GiftCreated(
        uint256 indexed giftId,
        address indexed sender,
        uint256 amount,
        address indexed ephemeralWallet,
        uint64 expiresAt
    );

    event GiftClaimed(
        uint256 indexed giftId,
        address indexed recipient,
        uint256 amount
    );

    event GiftRefunded(
        uint256 indexed giftId,
        address indexed sender,
        uint256 amount
    );

    function createGiftCard(
        bytes32 secretHash,
        address ephemeralWallet,
        uint64 durationSeconds
    ) external payable returns (uint256 giftId) {
        require(msg.value > 0, "Importo nullo");
        require(secretHash != bytes32(0), "Secret hash obbligatorio");
        require(ephemeralWallet != address(0), "Ephemeral wallet obbligatorio");
        require(durationSeconds > 0, "Durata deve essere > 0");

        giftId = ++lastGiftId;

        gifts[giftId] = GiftCard({
            sender: msg.sender,
            amount: msg.value,
            secretHash: secretHash,
            ephemeralWallet: ephemeralWallet,
            expiresAt: uint64(block.timestamp) + durationSeconds,
            claimed: false
        });

        emit GiftCreated(
            giftId,
            msg.sender,
            msg.value,
            ephemeralWallet,
            uint64(block.timestamp) + durationSeconds
        );
    }

    function redeem(
        uint256 giftId,
        string calldata secret,
        bytes calldata signature,
        address payable recipient
    ) external {
        GiftCard storage g = gifts[giftId];

        require(!g.claimed, "Gia' riscattata o rimborsata");
        require(g.amount > 0, "Gift inesistente");
        require(block.timestamp <= g.expiresAt, "Gift scaduta");
        require(recipient != address(0), "Recipient non valido");

        bytes32 providedHash = keccak256(abi.encodePacked(secret));
        require(providedHash == g.secretHash, "Segreto non valido");

        bytes32 message = keccak256(
            abi.encodePacked("QRYPT_REDEEM", address(this), giftId, recipient)
        );

        address recovered = _recoverSigner(message, signature);
        require(recovered == g.ephemeralWallet, "Firma non valida");

        g.claimed = true;
        uint256 amount = g.amount;
        g.amount = 0;

        (bool ok, ) = recipient.call{value: amount}("");
        require(ok, "Trasferimento fallito");

        emit GiftClaimed(giftId, recipient, amount);
    }

    function refund(uint256 giftId) external {
        GiftCard storage g = gifts[giftId];

        require(msg.sender == g.sender, "Solo il creatore puo' richiedere il rimborso");
        require(!g.claimed, "Gia' riscattata o rimborsata");
        require(block.timestamp > g.expiresAt, "Non ancora scaduta");
        require(g.amount > 0, "Importo nullo");

        g.claimed = true;
        uint256 amount = g.amount;
        g.amount = 0;

        (bool ok, ) = payable(g.sender).call{value: amount}("");
        require(ok, "Rimborso fallito");

        emit GiftRefunded(giftId, g.sender, amount);
    }

    function _recoverSigner(
        bytes32 message,
        bytes memory signature
    ) internal pure returns (address) {
        require(signature.length == 65, "Firma non valida");

        bytes32 ethSignedMessage = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", message)
        );

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        if (v < 27) {
            v += 27;
        }

        require(v == 27 || v == 28, "Valore v non valido");

        return ecrecover(ethSignedMessage, v, r, s);
    }
}
