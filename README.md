# 🎬 Collective Film Production DAO

A decentralized autonomous organization for transparent film production funding and governance using token-based voting.

## 🌟 Features

- **💰 Crowdfunding**: Contributors receive governance tokens proportional to their STX contributions
- **🗳️ Proposal System**: Create and vote on project proposals with token-weighted voting
- **⏰ Time-Limited Voting**: 144-block voting periods for proposal decisions
- **🏛️ Treasury Management**: Secure fund allocation and automatic execution
- **👥 Member Management**: Track contributor tokens and participation history
- **🔄 Token Delegation**: Transfer governance tokens between members

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet)
- [Stacks Wallet](https://wallet.hiro.so/)

### Installation
```bash
clarinet new film-dao
cd film-dao
# Copy the contract to contracts/Collective-Film-Production-DAO.clar
```

## 📋 Contract Functions

### 💸 Contributing Funds
```clarity
(contribute u1000000) ;; Contribute 1 STX, receive 1,000,000 tokens
```

### 📝 Creating Proposals
```clarity
(create-proposal "Film Equipment" "Purchase cameras and lighting" u500000 'SP1ABC...)
```

### 🗳️ Voting on Proposals
```clarity
(vote u1 true)  ;; Vote YES on proposal 1
(vote u1 false) ;; Vote NO on proposal 1
```

### ⚡ Executing Proposals
```clarity
(execute-proposal u1) ;; Execute proposal 1 after voting period
```

### 🔄 Delegating Tokens
```clarity
(delegate-tokens 'SP1ABC... u100000) ;; Delegate 100,000 tokens
```

## 🔍 Read-Only Functions

### 📊 Get Proposal Info
```clarity
(get-proposal u1)           ;; Get proposal details
(get-proposal-status u1)    ;; Get voting status
(is-voting-open u1)         ;; Check if voting is active
```

### 💳 Check Balances
```clarity
(get-user-tokens tx-sender)    ;; Get governance tokens
(get-token-balance tx-sender)  ;; Get fungible token balance
(get-treasury-balance)         ;; Get total treasury
```

### 👤 Member Information
```clarity
(get-member-info tx-sender)    ;; Get member details
(get-vote u1 tx-sender)        ;; Get voting record
```

## ⚙️ Configuration

- **Voting Period**: 144 blocks (~24 hours)
- **Min Proposal Threshold**: 1,000 tokens
- **Token Symbol**: `film-token`

## 🛡️ Security Features

- ✅ Proposal creator must hold minimum tokens
- ✅ One vote per member per proposal
- ✅ Time-limited voting periods
- ✅ Automatic proposal execution
- ✅ Treasury balance validation

## 🎯 Use Cases

1. **🎥 Equipment Funding**: Vote on camera, lighting, and sound equipment purchases
2. **🌟 Cast & Crew**: Allocate budget for actors, directors, and production staff
3. **📍 Location Costs**: Fund location permits and rental fees
4. **🎞️ Post-Production**: Budget for editing, sound design, and color grading
5. **🚀 Marketing**: Allocate funds for film promotion and distribution

## 🔧 Development

### Testing
```bash
clarinet test
```

### Deployment
```bash
clarinet deploy
```

## 📄 License

MIT License - Build amazing films together! 🎬✨
