# 🌐 Decentralized Internet Subscription DAO

A Clarity smart contract that enables communities to pool funds and collectively manage internet subscriptions through decentralized governance.

## 📋 Overview

This DAO allows community members to:
- 💰 Pool STX tokens for shared internet costs
- 🗳️ Vote on proposals for internet service providers
- 📊 Manage multiple internet subscriptions collectively
- 🏛️ Participate in decentralized governance decisions

## 🚀 Features

### 👥 Membership System
- Join the DAO by paying membership fee
- Make additional contributions to increase voting power
- Track member contributions and activity status

### 🗳️ Governance & Proposals
- Create proposals for internet service funding
- Democratic voting system with time-limited voting periods
- Automatic execution of passed proposals
- Transparent proposal tracking

### 🌐 Internet Subscription Management
- Add new internet subscriptions with provider details
- Renew existing subscriptions using pooled funds
- Track subscription costs, speeds, and funding periods
- Deactivate unused subscriptions

## 📖 Usage Instructions

### Joining the DAO
```clarity
(contract-call? .decentralized-internet-subscription join-dao)
```

### Contributing Additional Funds
```clarity
(contract-call? .decentralized-internet-subscription contribute u5000000)
```

### Creating a Proposal
```clarity
(contract-call? .decentralized-internet-subscription create-proposal 
  "Fund Fiber Internet" 
  "Proposal to fund high-speed fiber internet for 6 months"
  u30000000
  'SP1234567890ABCDEF)
```

### Voting on Proposals
```clarity
;; Vote in favor (true) or against (false)
(contract-call? .decentralized-internet-subscription vote u1 true)
```

### Executing Proposals
```clarity
(contract-call? .decentralized-internet-subscription execute-proposal u1)
```

### Adding Internet Subscriptions (Owner Only)
```clarity
(contract-call? .decentralized-internet-subscription add-internet-subscription
  "Fiber Corp"
  u5000000
  "1Gbps"
  u12)
```

## 🔍 Read-Only Functions

### Check Member Information
```clarity
(contract-call? .decentralized-internet-subscription get-member-info 'SP1234567890ABCDEF)
```

### View Proposal Details
```clarity
(contract-call? .decentralized-internet-subscription get-proposal u1)
```

### Check Total Pool Balance
```clarity
(contract-call? .decentralized-internet-subscription get-total-pool)
```

### Verify Subscription Status
```clarity
(contract-call? .decentralized-internet-subscription is-subscription-active u1)
```

## ⚙️ Configuration

- **Membership Fee**: 1 STX (1,000,000 microSTX)
- **Minimum Proposal Amount**: 0.5 STX (500,000 microSTX)
- **Voting Period**: 144 blocks (~24 hours)
- **Month Duration**: 4,320 blocks (~30 days)

## 🛡️ Security Features

- ✅ Member-only proposal creation and voting
- ✅ Owner-only subscription management
- ✅ Duplicate vote prevention
- ✅ Sufficient funds validation
- ✅ Time-based voting periods
- ✅ Automatic proposal execution

## 🏗️ Contract Architecture

The contract uses several key data structures:
- **Members Map**: Tracks member contributions and status
- **Proposals Map**: Stores governance proposals and voting results
- **Internet Subscriptions Map**: Manages active internet services
- **Votes Map**: Prevents duplicate voting

## 📊 Error Codes

| Code | Description |
|------|-------------|
| u100 | Not authorized |
| u101 | Insufficient funds |
| u102 | Invalid amount |
| u103 | Proposal not found |
| u104 | Already voted |
| u105 | Voting period ended |
| u106 | Proposal not passed |
| u107 | Already a member |
| u108 | Not a member |
| u109 | Invalid duration |

## 🤝 Contributing

This contract is designed for community internet funding and can be extended with additional features like:
- Tiered membership levels
- Reputation-based voting weights
- Multi-signature proposal execution
- Integration with real ISP APIs

---

*Built with ❤️ using Clarity and Stacks blockchain*
```


```

```
