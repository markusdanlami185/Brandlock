# 🔒 Brandlock - On-Chain Trademark Protocol

## 🚀 Overview

Brandlock is a **first-to-file trademark registration system** built on the Stacks blockchain. It enables users to claim, register, and manage trademark rights in a decentralized, transparent, and immutable way.

## ✨ Features

- 🏷️ **Register Trademarks** - First-come, first-served trademark registration
- ⏰ **Time-Limited Claims** - Trademarks expire and need renewal
- 💰 **Fee-Based System** - Registration and renewal fees prevent spam
- 🔄 **Transfer Ownership** - Transfer trademark rights to other users
- 📊 **Query System** - Check availability and ownership status
- 🛡️ **Secure & Immutable** - Blockchain-based proof of ownership

## 🛠️ Core Functions

### Public Functions

#### `register-trademark`
Register a new trademark with category and description.
```clarity
(register-trademark "MYBRAND" "Technology" "Software solutions company")
```

#### `renew-trademark`
Extend the expiration date of your trademark.
```clarity
(renew-trademark "MYBRAND")
```

#### `transfer-trademark`
Transfer ownership to another principal.
```clarity
(transfer-trademark "MYBRAND" 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

#### `deactivate-trademark`
Voluntarily deactivate your trademark.
```clarity
(deactivate-trademark "MYBRAND")
```

### Read-Only Functions

#### `get-trademark`
Get complete trademark information.
```clarity
(get-trademark "MYBRAND")
```

#### `is-trademark-available`
Check if a trademark name is available for registration.
```clarity
(is-trademark-available "NEWBRAND")
```

#### `get-trademark-owner`
Get the current owner of a trademark.
```clarity
(get-trademark-owner "MYBRAND")
```

## 💸 Fee Structure

- **Registration Fee**: 1 STX (1,000,000 microSTX)
- **Renewal Fee**: 0.5 STX (500,000 microSTX)
- **Claim Duration**: 52,560 blocks (~1 year)

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet with STX tokens

### Installation

1. Clone the repository
```bash
git clone <repository-url>
cd brandlock
```

2. Check contract syntax
```bash
clarinet check
```

3. Run tests
```bash
clarinet test
```

4. Deploy to testnet
```bash
clarinet deploy --testnet
```

## 📝 Usage Examples

### Register Your First Trademark
```clarity
;; Register a trademark for your tech startup
(contract-call? .Brandlock register-trademark "TECHCORP" "Technology" "Innovative software solutions")
```

### Check Availability
```clarity
;; Check if a name is available
(contract-call? .Brandlock is-trademark-available "MYBRAND")
```

### Renew Before Expiration
```clarity
;; Renew your trademark to extend ownership
(contract-call? .Brandlock renew-trademark "TECHCORP")
```

## 🔧 Contract Administration

Only the contract owner can:
- Update registration fees
- Update renewal fees  
- Modify claim duration

## ⚠️ Important Notes

- Trademark names are **case-sensitive**
- Maximum name length: 50 characters
- Trademarks expire after the claim duration
- Expired trademarks become available for re-registration
- All transactions require appropriate STX fees

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is open source and available under the MIT License.

## 🆘 Support

For questions and support, please open an issue in the GitHub repository.



