# 🕌 Islamic Finance-Compliant Lending Platform

A Sharia-compliant lending platform built on Stacks blockchain using Clarity smart contracts. This platform enables profit-sharing based lending without interest (riba), adhering to Islamic finance principles.

## ✨ Features

- 🚫 **Interest-Free Lending**: No riba (interest) - uses profit-sharing model
- 🤝 **Profit Sharing**: Lenders receive a percentage of business profits
- 💰 **Lending Pool**: Multiple lenders can contribute to a shared pool
- 📊 **Credit Profiles**: Track borrower history and reputation
- ⏰ **Time-Based Contracts**: Defined loan durations with automatic expiry
- 🔒 **Default Management**: Handle non-performing loans

## 🏗️ Architecture

The smart contract implements the following Islamic finance concepts:

- **Mudarabah**: Profit-sharing partnership between lender and borrower
- **Risk Sharing**: Both parties share business risks
- **Asset-Backed**: Loans are tied to specific business ventures
- **Transparent**: All terms are clearly defined upfront

## 🚀 Getting Started

### Prerequisites

- Clarinet CLI installed
- Stacks wallet for testing

### Installation

```bash
git clone <repository-url>
cd islamic-lending-platform
clarinet console
```

## 📖 Usage Guide

### For Lenders 💼

1. **Deposit Funds**
```clarity
(contract-call? .islamic-lending deposit-funds u1000000)
```

2. **Approve Loans**
```clarity
(contract-call? .islamic-lending approve-loan u1 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

3. **Withdraw Available Funds**
```clarity
(contract-call? .islamic-lending withdraw-funds u500000)
```

### For Borrowers 🏪

1. **Request a Loan**
```clarity
(contract-call? .islamic-lending request-loan u1000000 u10 u1000 "Halal restaurant expansion")
```

2. **Repay Loan with Profit Share**
```clarity
(contract-call? .islamic-lending repay-loan u1)
```

### Query Functions 🔍

**Get Loan Details**
```clarity
(contract-call? .islamic-lending get-loan u1)
```

**Check Lender Info**
```clarity
(contract-call? .islamic-lending get-lender-info 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

**View Borrower Profile**
```clarity
(contract-call? .islamic-lending get-borrower-profile 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG)
```

**Calculate Repayment Amount**
```clarity
(contract-call? .islamic-lending calculate-repayment u1)
```

## 🔧 Contract Functions

### Public Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `deposit-funds` | Add funds to lending pool | `amount: uint` |
| `request-loan` | Submit loan application | `amount, profit-share, duration, description` |
| `approve-loan` | Approve pending loan | `loan-id, lender` |
| `repay-loan` | Repay loan with profit | `loan-id` |
| `mark-default` | Mark loan as defaulted | `loan-id` |
| `withdraw-funds` | Withdraw available funds | `amount` |

### Read-Only Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `get-loan` | Retrieve loan details | Loan data |
| `get-lender-info` | Get lender statistics | Lender profile |
| `get-borrower-profile` | Get borrower history | Borrower profile |
| `calculate-repayment` | Calculate total repayment | Amount due |
| `is-loan-expired` | Check if loan expired | Boolean |

## 🎯 Loan States

- **pending**: Loan requested, awaiting approval
- **active**: Loan approved and funds disbursed
- **completed**: Loan successfully repaid
- **defaulted**: Loan payment overdue

## ⚖️ Islamic Finance Compliance

This platform adheres to key Islamic finance principles:

- ❌ **No Riba**: Zero interest charges
- ✅ **Profit Sharing**: Returns based on business success
- ✅ **Risk Sharing**: Both parties assume business risks
- ✅ **Asset Backing**: Loans tied to real business activities
- ✅ **Transparency**: All terms disclosed upfront

## 🧪 Testing

Run the test suite:

```bash
clarinet test
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

This project is licensed under the MIT License.

## 🆘 Support

For questions
