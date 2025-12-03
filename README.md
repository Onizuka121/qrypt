# QRYPT

**Secure, frictionless crypto transfers via QR codes.**  
QRYPT is a peer-to-peer payment system on Avalanche that replaces wallet addresses with secret codes. Send crypto without asking for addresses — just share a QR / payload and let the recipient redeem it.

> 🧪 Hackathon project – originally built during a 24-hour Avalanche hackathon.

---

## Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [How It Works](#how-it-works)
  - [1. Create a gift card](#1-create-a-gift-card)
  - [2. Share the QR / payload](#2-share-the-qr--payload)
  - [3. Redeem the funds](#3-redeem-the-funds)
- [Smart Contract Design](#smart-contract-design)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Build & Test](#build--test)
  - [Local Development (Anvil)](#local-development-anvil)
  - [Deploying to Avalanche](#deploying-to-avalanche)
- [Usage Examples](#usage-examples)
  - [Create a gift card](#create-a-gift-card)
  - [Redeem a gift card](#redeem-a-gift-card)
  - [Refund a gift card](#refund-a-gift-card)
- [Security Notes](#security-notes)
- [Roadmap / Ideas](#roadmap--ideas)
- [License](#license)

---

## Overview

QRYPT lets you send AVAX like a **digital gift card**:

- The **sender** deposits funds into a smart contract and generates a QR / JSON payload.
- The **receiver** just scans or pastes the payload to claim the funds into their own wallet.
- Under the hood, each gift card is protected by a **2-factor mechanism on-chain** (a secret + an ephemeral wallet), which mitigates simple front-running attacks while keeping the UX “scan & receive”.

This repository contains the **Solidity smart contract** and **Foundry tooling** used to deploy and test the core protocol.

---

## Key Features

- 🎁 **Gift-card–style transfers** – Send AVAX without asking for the recipient’s address in advance.
- 🔒 **On-chain 2FA** – Each gift is protected by:
  - a **secret** (known only to sender + receiver),
  - an **ephemeral wallet** (private key embedded in the QR/payload).
- 🛡 **Front-running resistance** – An attacker who only sees the secret in the mempool cannot redeem the funds without the ephemeral private key.
- 💸 **Refunds** – If a gift is not redeemed (or after an optional expiry), the sender can reclaim their funds.
- 📡 **Event-driven** – Creation, redemption and refunds emit events for easy indexing and frontend integration.
- 🌉 **Avalanche-ready** – Designed for Avalanche C-Chain / Fuji, but works on any EVM-compatible network.

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

## Project Structure

The repository follows a standard Foundry layout:

```text
.
├── src/                # Solidity contracts (QRYPT core logic)
│   └── QryptGiftCard.sol
├── script/             # Deployment and interaction scripts
│   ├── DeployQrypt.s.sol
│   └── RedeemGiftCard.s.sol
├── broadcast/          # Forge broadcast logs (per-network deployment outputs)
├── lib/                # External libraries (e.g. forge-std)
├── test/               # Contract tests (if present)
├── foundry.toml        # Foundry configuration
├── foundry.lock        # Lockfile for dependencies
└── README.md           # You are here
Note: the exact filenames may vary depending on the version you are looking at, but the overall structure is standard Foundry.

Getting Started
Prerequisites
Foundry (Forge, Cast, Anvil)

A working Avalanche RPC endpoint (Fuji testnet or C-Chain mainnet)

A funded EOA private key for deploying (for testnet, faucet AVAX is enough)

Installation
bash
Copia codice
git clone https://github.com/Onizuka121/qrypt.git
cd qrypt

# Install Foundry dependencies (if using git submodules / forge-std)
forge install
If the project uses git submodules for lib/, also run:

bash
Copia codice
git submodule update --init --recursive
Build & Test
bash
Copia codice
# Compile contracts
forge build

# Run tests
forge test
Local Development (Anvil)
To experiment locally:

bash
Copia codice
# Start a local EVM node
anvil

# In another terminal, deploy the contract to Anvil
forge script script/DeployQrypt.s.sol:DeployQrypt \
  --rpc-url http://127.0.0.1:8545 \
  --private-key <ANVIL_PRIVATE_KEY> \
  --broadcast
Replace <ANVIL_PRIVATE_KEY> with one of the keys printed by Anvil.

Deploying to Avalanche
Example deployment to Avalanche Fuji:

bash
Copia codice
export RPC_URL_FUJI="https://api.avax-test.network/ext/bc/C/rpc"
export PRIVATE_KEY_DEPLOYER="0x..."

forge script script/DeployQrypt.s.sol:DeployQrypt \
  --rpc-url $RPC_URL_FUJI \
  --private-key $PRIVATE_KEY_DEPLOYER \
  --broadcast
After deployment, copy the contract address from the Forge broadcast output; it will be used by frontends, scripts, or QR payloads.

Usage Examples
Below are high-level examples using Forge scripts; exact names may differ depending on your version.

Create a gift card
A sample script might:

Read env variables:

PRIVATE_KEY_ALICE

SECRET

EPHEMERAL_PRIVKEY

Compute secretHash and ephemeralWallet.

Call createGiftCard with msg.value = amount.

Run it with:

bash
Copia codice
forge script script/CreateGiftCard.s.sol:CreateGiftCard \
  --rpc-url $RPC_URL_FUJI \
  --private-key $PRIVATE_KEY_ALICE \
  --broadcast
The script can log a JSON payload that you can encode as a QR code.

Redeem a gift card
The RedeemGiftCard script typically:

Reads:

CONTRACT_ADDRESS

GIFT_ID

SECRET

EPHEMERAL_PRIVKEY

PRIVATE_KEY_BOB

Rebuilds the message hash, signs it with the ephemeral private key, and calls redeem.

Example:

bash
Copia codice
forge script script/RedeemGiftCard.s.sol:RedeemGiftCard \
  --rpc-url $RPC_URL_FUJI \
  --private-key $PRIVATE_KEY_BOB \
  --broadcast
After confirmation, Bob’s wallet should receive the AVAX.

Refund a gift card
A simple RefundGiftCard script can:

Read:

CONTRACT_ADDRESS

GIFT_ID

PRIVATE_KEY_ALICE

Call refund(giftId) from the sender.

Only eligible gifts (not yet claimed and, if expiry is used, expired) will be successfully refunded.

Security Notes
Experimental / Hackathon code – QRYPT was built as a hackathon prototype and has not been professionally audited.

Use at your own risk – Do not use this code as-is to secure significant real-world funds.

Threat model – The design specifically aims to mitigate:

simple mempool front-running on the secret,

trivial theft of claim codes shared off-chain.

It does not protect against a compromised device, stolen QR/payload, malicious frontends, or sophisticated on-chain attacks.

Before any production use, the contract should undergo:

a full security review,

additional testing and fuzzing,

possibly formal verification and professional auditing.

Roadmap / Ideas
Potential future work includes:

A production-ready frontend with:

QR generation and scanning,

history of created / redeemed / refunded gifts,

better UX around status and errors.

Telegram / bot integrations for giveaways and rewards.

Multi-chain support (other EVM chains).

Extended claim conditions (e.g. time locks, whitelists, claim limits).

License
The license for this project has not been specified yet.
Before open-sourcing or using this code in production, add a LICENSE file (for example MIT, Apache-2.0, etc.) according to your needs.

makefile
Copia codice
::contentReference[oaicite:0]{index=0}
