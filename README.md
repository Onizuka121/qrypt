<p align="center">
  <img src="download.png" width="400">
</p>

**Secure, frictionless crypto transfers via QR codes.**  
QRYPT is a peer-to-peer payment system on Avalanche that replaces wallet addresses with secret codes. Send crypto without asking for addresses — just share a QR / payload and let the recipient redeem it.

> 🧪 Hackathon project – originally built during a 24-hour Avalanche hackathon.

---

## Table of Contents

* [Overview](#overview)
* [Key Features](#key-features)
* [How It Works](#how-it-works)
  * [1. Create a gift card](#1-create-a-gift-card)
  * [2. Share the QR / payload](#2-share-the-qr--payload)
  * [3. Redeem the funds](#3-redeem-the-funds)
* [Smart Contract Design](#smart-contract-design)
* [Getting Started](#getting-started)
  * [1. Environment Setup](#1-environment-setup)
  * [2. Contract Deployment](#2-contract-deployment)
  * [3. Gift Card Creation](#3-gift-card-creation)
  * [4. Gift Card Redemption](#4-gift-card-redemption)

---

## Overview

QRYPT lets you send AVAX like a **digital gift card**:

- The **sender** deposits funds into a smart contract and generates a QR / JSON payload.
- The **receiver** just scans or pastes the payload to claim the funds into their own wallet.
- Under the hood, each gift card is protected by a **2-factor mechanism on-chain** (a secret + an ephemeral wallet), which mitigates simple front-running attacks while keeping the UX “scan & receive”.

This repository contains the **Solidity smart contract** and **Foundry tooling** used to deploy and test the core protocol.

---

## Key Features

- **Gift-card–style transfers** – Send AVAX without asking for the recipient’s address in advance.
- **On-chain 2FA** – Each gift is protected by:
  - a **secret** (known only to sender + receiver),
  - an **ephemeral wallet** (private key embedded in the QR/payload).
- **Front-running resistance** – An attacker who only sees the secret in the mempool cannot redeem the funds without the ephemeral private key.
- **Refunds** – If a gift is not redeemed (or after an optional expiry), the sender can reclaim their funds.
- **Event-driven** – Creation, redemption and refunds emit events for easy indexing and frontend integration.
- **Avalanche-ready** – Designed for Avalanche C-Chain / Fuji, but works on any EVM-compatible network.

---

## How It Works

At a high level, QRYPT turns a deposit into a claimable “ticket” secured by two factors.

### 1. Create a gift card

1. The sender chooses:
   - an amount of AVAX,
   - a random **secret** string,
   - an **ephemeral wallet** (address + private key) generated on the client.
2. The frontend hashes the secret and calls the smart contract function to create a gift card, sending the AVAX along with:
   - `secretHash = keccak256(secret)`,
   - `ephemeralWallet` address,
   - (optionally) an expiry time.
3. The contract stores the gift on-chain and emits a `GiftCreated` event with a unique `giftId`.

The frontend then encodes a payload (for example in a QR code) containing:
- the contract address,
- the `giftId`,
- the **plain secret**,
- the **ephemeral private key**.

Only whoever sees this payload has both factors.

### 2. Share the QR / payload

The sender can share the gift via:

- QR code (printed or on screen),
- chat message,
- email, etc.

No need to know the receiver’s wallet address in advance.

### 3. Redeem the funds

When the receiver wants to redeem:

1. The frontend reads the payload and reconstructs:
   - contract address,
   - `giftId`,
   - `secret`,
   - ephemeral private key.
2. It connects to the receiver’s real wallet (MetaMask / Core Wallet) and computes the same message the contract expects:
   - `hash = keccak256("QRYPT_REDEEM", contract, giftId, recipientAddress)`,
   - then signs that hash **with the ephemeral private key**.
3. It calls `redeem(giftId, secret, signature, recipientAddress)` on the contract.
4. The contract verifies:
   - the secret matches `secretHash`,
   - the signature is valid and the signer is exactly `ephemeralWallet`,
   - the gift has not been claimed or refunded.
5. If all checks pass, the contract transfers the AVAX to the receiver’s wallet and marks the gift as claimed.

Result: even if someone sees the **secret** in the mempool, they **cannot** forge the signature from the ephemeral wallet and therefore cannot steal the funds.

---

## Smart Contract Design

The main contract (e.g. `QryptGiftCard.sol`) manages a mapping of gifts:

- `sender`: original funder of the gift card,
- `amount`: value in wei,
- `secretHash`: hash of the secret,
- `ephemeralWallet`: address expected to sign the redeem message,
- `expiresAt` (optional): timestamp for expiry,
- `claimed`: whether the gift has been redeemed,
- `refunded`: whether the gift has been refunded.

Core functions:

- `createGiftCard(secretHash, ephemeralWallet, expiresAt) payable`
  - Requires `msg.value > 0`.
  - Stores the new gift and emits `GiftCreated(giftId, sender, amount, expiresAt)`.

- `redeem(giftId, secret, signature, recipient)`
  - Verifies:
    - the gift exists and is not claimed/refunded,
    - optional expiry (if used),
    - `keccak256(secret) == secretHash`,
    - `ECDSA.recover(toEthSignedMessageHash(message), signature) == ephemeralWallet`.
  - Transfers `amount` to `recipient`.
  - Marks `claimed = true` and emits `GiftClaimed(giftId, recipient)`.

- `refund(giftId)`
  - Can only be called by `sender`.
  - Checks that the gift is not claimed and (if using expiry) has expired.
  - Transfers `amount` back to `sender`.
  - Marks `refunded = true` and emits `GiftRefunded(giftId, sender)`.

Events let off-chain indexers and frontends build a full history of created / redeemed / refunded cards.

---

# Getting Started

This section outlines the end-to-end execution flow for deploying, initializing, and redeeming QRYPT gift cards using the provided Foundry scripts.
All commands target Avalanche Fuji by default but are compatible with any EVM-based network.

---

## 1. Environment Setup

Ensure the following components are available in your environment:

### **Foundry Toolchain**

Install and update:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### **Network Configuration**

```bash
export RPC_URL="https://api.avax-test.network/ext/bc/C/rpc"
```

### **Operator Keys**

Define two funded test accounts:

```bash
export PRIVATE_KEY_JOHN=0x<sender_private_key>   # gift creator
export PRIVATE_KEY_BOB=0x<recipient_private_key> # gift redeemer
```

Each must hold sufficient AVAX to cover transactions.

---

## 2. Contract Deployment

Deploy the QryptGiftCard contract using John’s key:

```bash
forge script script/DeployQrypt.s.sol:DeployQrypt \
  --rpc-url $RPC_URL \
  --broadcast \
  -vvvv
```

The script outputs:

```
QryptGiftCard deployed at: 0x<address>
```

Register the deployed instance:

```bash
export C_ADDR=0x<address>
```

---

## 3. Gift Card Creation

Initialize a gift card using John’s wallet:

```bash
forge script script/CreateGiftCard.s.sol:CreateGiftCard \
  --rpc-url $RPC_URL \
  --broadcast \
  -vvvv
```

The script returns key parameters:

```
GiftId: <GIFT_ID>
segreto: <SECRET>
Ephemeral private key: <EPHEMERAL_PRIVKEY>
Ephemeral address: <EPHEMERAL_ADDRESS>
```

Expose these as environment variables for redemption:

```bash
export GIFT_ID=<GIFT_ID>
export SEGRETO="<SECRET>"
export EPHEMERAL_PRIVKEY=<EPHEMERAL_PRIVKEY>
```

> **Note:** The demo script uses fixed secrets and ephemeral keys for reproducibility.
> Production-grade flows must dynamically generate and protect these values client-side.

---

## 4. Gift Card Redemption

Redeem the gift card using Bob’s wallet:

```bash
forge script script/RedeemGiftCard.s.sol:RedeemGiftCard \
  --rpc-url $RPC_URL \
  --broadcast \
  -vvvv
```

The redeem script:

* Reconstructs the expected `QRYPT_REDEEM` signed payload
* Signs it using the ephemeral private key
* Calls `redeem()` on-chain on behalf of Bob

Upon success, Bob receives the transferred AVAX.

You may verify the resulting balance:

```bash
cast balance $(cast wallet address --private-key $PRIVATE_KEY_BOB) --rpc-url $RPC_URL
```
