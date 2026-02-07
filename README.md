# 🛡️ VeilLend

> **Private Lending. Starknet Speed.**

**VeilLend** is a privacy-first decentralized lending protocol built on **Starknet**. It leverages **Zero-Knowledge (ZK)** cryptography to enable users to deposit, borrow, and transact with complete financial privacy.

---

## 🏆 Hackathon Track: Privacy
This project is built specifically for the **Privacy Track**, implementing:
- **Confidential Transactions**: Shielded pools for depositing and withdrawing assets without revealing the link between sender and receiver.
- **ZK Protocol Implementation**: Custom implementation of a **Commit-Reveal Scheme** using **Poseidon Hashing** (Starknet's native hash).
- **Shielded Wallet UI**: A privacy-focused mobile interface that masks sensitive balances and integrates directly with Starknet wallets.

---

## 🏗️ Architecture

The project follows a modern, layered architecture:

| Component | Tech Stack | Description |
| :--- | :--- | :--- |
| **Smart Contracts** | **Cairo 2.x** | On-chain logic for Lending Pools, ZK Shielding, and Asset Management. |
| **Mobile App** | **React Native (Expo)** | Cross-platform mobile wallet interface with "Privacy Mode" and Starknet SDK integration. |
| **Backend API** | **NestJS** | Relayer service, indexer, and off-chain data aggregator backed by **Supabase**. |
| **Database** | **PostgreSQL (Supabase)** | Stores encrypted user profiles, transaction history, and active positions. |

---

## 🔐 Smart Contracts (Cairo)

Located in `/contracts`, our smart contracts power the privacy engine:

### 1. **ZK Shielded Pool (`zk_shield.cairo`)**
- Implements a **Commit-Reveal** privacy scheme.
- **Deposit**: Users generate a secret off-chain, hash it (Poseidon), and deposit funds with the `commitment`.
- **Withdraw**: Users provide the `secret` (nullifier) to prove ownership without revealing their identity.
- **Privacy**: The on-chain state only tracks hashed commitments, breaking the link between deposit and withdrawal.

### 2. **Lending Pool (`lending_pool.cairo`)**
- Standard DeFi logic for **Supply**, **Borrow**, and **Repay**.
- Integrated with `ERC20` tokens (ETH, USDC).
- Emits events for real-time indexing.

---

## 📱 Mobile App Features

- **🛡️ Shielded Dashboard**: Toggle "Privacy Mode" to mask balances and positions from prying eyes (or shoulder surfers).
- **🔑 Starknet Login**: Authenticate securely using cryptographic signatures (Argent/Braavos) via `starknet-react`.
- **⚡ Fast Actions**: One-tap Deposit, Borrow, and Repay flows.
- **🔄 Real-time Updates**: Live synchronization with on-chain data via the Backend API.

---

## 🚀 Getting Started

### Prerequisites
- **Node.js** (v18+)
- **Scarb** (for Cairo contracts)
- **Expo Go** (for mobile testing)

### 1. Smart Contracts
```bash
cd contracts
scarb build
# Deploy artifacts from target/dev/
```

### 2. Backend API
```bash
cd veilend-backend
npm install
# Setup .env with SUPABASE_URL and SUPABASE_KEY
npm run start:dev
# Swagger Docs available at http://localhost:3000/api
```

### 3. Mobile App
```bash
cd mobile-app
npm install --legacy-peer-deps
npx expo start
# Scan QR code with Expo Go
```

---

## 🛠️ Tech Deep Dive: ZK Privacy Flow

1.  **Client-Side**: User selects "Shielded Deposit". App generates a random `secret`.
2.  **Hashing**: App computes `commitment = Poseidon(secret)`.
3.  **On-Chain**: App calls `deposit_shielded(amount, commitment)`.
4.  **Storage**: Contract stores `commitment` mapped to `amount`.
5.  **Withdrawal**: User provides `secret` to a fresh address. Contract verifies `Poseidon(secret) == commitment` and transfers funds.

---

## 📜 License
MIT
