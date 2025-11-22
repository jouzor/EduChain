# EduChain - Educational Crowdfunding Platform

## Overview

EduChain is a decentralized crowdfunding smart contract built on the Stacks blockchain using Clarity. It enables transparent, secure fundraising for educational initiatives and scholarship programs. The platform leverages blockchain technology to ensure trust, accountability, and efficient fund management.

## Features

- **Create Educational Initiatives**: Launch scholarship programs or educational projects with clear goals and funding targets
- **Transparent Crowdfunding**: Contributors can securely fund initiatives they believe in
- **Automatic Fund Release**: Funds are released to creators only when targets are met
- **Refund Protection**: Contributors receive full refunds if targets aren't met by the deadline
- **Platform Fees**: A 5% fee supports platform operations and maintenance
- **Immutable Records**: All transactions and contributions are recorded on the blockchain
- **Real-time Statistics**: Query platform metrics and individual contributions anytime

## Architecture

### Data Structures

**Initiatives Map**: Stores all educational projects with details including:
- Creator principal address
- Project title, description, and category
- Funding target and current amount collected
- Deadline for fundraising
- Project status (active, funded)
- Number of beneficiaries

**Contributions Map**: Tracks all individual donations with:
- Contributor address
- Amount contributed in microSTX
- Timestamp of contribution
- Withdrawal status

### Key Variables

- `next-initiative-id`: Counter for unique initiative IDs
- `platform-balance`: Total platform fees collected
- `total-funded`: Total STX amount raised across all initiatives

## Core Functions

### Public Functions (Write Operations)

#### `create-initiative`
Creates a new educational initiative.

**Parameters:**
- `title`: Project name (max 100 characters)
- `description`: Project details (max 500 characters)
- `category`: Initiative category (max 50 characters)
- `target-amount`: Funding goal in microSTX (minimum 10 STX = 10,000,000 microSTX)
- `duration-blocks`: Number of blocks until deadline
- `beneficiaries`: Estimated number of people who will benefit

**Returns:** Initiative ID on success, error code on failure

**Error Codes:**
- `u1`: Invalid amount (target must be greater than 0)
- `u2`: Below minimum funding amount

**Example:**
```clarity
(create-initiative "STEM Scholarship 2025" "Support 50 students in STEM fields" "education" u100000000 u52560 u50)
```

---

#### `contribute`
Contributes STX to an active initiative.

**Parameters:**
- `initiative-id`: ID of the target initiative
- `amount`: STX amount to contribute (in microSTX)

**Returns:** Boolean true on success, error code on failure

**Error Codes:**
- `u3`: Initiative not found
- `u4`: Invalid amount (must be greater than 0)
- `u5`: Initiative not active
- `u6`: Deadline has passed
- `u7`: Contribution would exceed target

**Example:**
```clarity
(contribute u0 u5000000) ;; Contribute 5 STX to initiative 0
```

---

#### `release-funds`
Transfers collected funds to the initiative creator after target is met.

**Parameters:**
- `initiative-id`: ID of the initiative to release funds for

**Returns:** Boolean true on success, error code on failure

**Error Codes:**
- `u8`: Initiative not found
- `u9`: Caller is not the initiative creator
- `u10`: Deadline has not been reached
- `u11`: Target amount not met
- `u12`: Initiative not active

**Requirements:**
- Caller must be the initiative creator
- Current block height must be >= deadline
- Funding target must be met or exceeded
- Status must be "active"

---

#### `withdraw-contribution`
Allows contributors to withdraw funds if target is not met after deadline.

**Parameters:**
- `initiative-id`: ID of the initiative

**Returns:** Boolean true on success, error code on failure

**Error Codes:**
- `u13`: Initiative not found
- `u14`: Contribution not found
- `u15`: Deadline has not been reached
- `u16`: Target was met (funds released)
- `u17`: Contribution already withdrawn

**Requirements:**
- Current block height must be >= deadline
- Target must NOT be met
- Contribution must not already be withdrawn

---

#### `withdraw-platform-fees`
Allows the contract deployer to collect accumulated platform fees.

**Parameters:**
- `amount`: Amount of fees to withdraw (in microSTX)

**Returns:** Boolean true on success, error code on failure

**Error Codes:**
- `u20`: Caller is not the deployer
- `u21`: Insufficient platform balance

**Requirements:**
- Caller must be the original deployer
- Amount must not exceed accumulated fees

---

### Read-Only Functions (Query Operations)

#### `get-initiative`
Retrieves detailed information about an initiative.

**Parameters:**
- `initiative-id`: ID of the initiative

**Returns:** Initiative details or error u18 if not found

---

#### `get-contribution`
Retrieves a specific contribution record.

**Parameters:**
- `contributor`: Contributor's principal address
- `initiative-id`: Initiative ID

**Returns:** Contribution details or error u19 if not found

---

#### `is-initiative-active`
Checks if an initiative is currently accepting contributions.

**Parameters:**
- `initiative-id`: Initiative ID

**Returns:** Boolean true if active, false otherwise

---

#### `get-platform-stats`
Returns overall platform statistics.

**Returns:** Object containing:
- `platform-balance`: Total fees collected (in microSTX)
- `total-funded`: Total amount raised across all initiatives (in microSTX)
- `total-initiatives`: Total number of initiatives created

---

#### `get-total-initiatives`
Returns the total count of initiatives created.

**Returns:** Unsigned integer count

---

#### `get-platform-balance`
Returns accumulated platform fees.

**Returns:** Balance in microSTX

---

#### `get-total-funded`
Returns total amount raised across all initiatives.

**Returns:** Total in microSTX

---

## Workflow

### Creating and Funding an Initiative

1. **Creator launches initiative** using `create-initiative` with funding goal and deadline
2. **Contributors discover initiative** and review details using `get-initiative`
3. **Contributors fund initiative** using `contribute` to send STX
4. **Platform collects 5% fee** on each contribution
5. **Deadline arrives**

### Two Possible Outcomes

**If Target Met:**
- Creator calls `release-funds` to receive collected amount (minus 5% platform fee)
- Initiative status changes to "funded"

**If Target Not Met:**
- Contributors call `withdraw-contribution` to recover their STX
- Funds are automatically returned to their wallets

## Constants

- `PLATFORM-FEE-PERCENTAGE`: 5% - Fee deducted from successful campaigns
- `MINIMUM-FUNDING-AMOUNT`: 10,000,000 microSTX (10 STX) - Minimum project target
- `DEPLOYER`: Original contract deployer address

## Error Codes Reference

| Code | Meaning |
|------|---------|
| u1 | Target amount must be greater than 0 |
| u2 | Target below minimum funding amount |
| u3 | Initiative not found |
| u4 | Contribution amount must be greater than 0 |
| u5 | Initiative is not active |
| u6 | Initiative deadline has passed |
| u7 | Contribution would exceed target |
| u8 | Initiative not found |
| u9 | Only initiative creator can release funds |
| u10 | Deadline has not been reached |
| u11 | Funding target not met |
| u12 | Initiative is not active |
| u13 | Initiative not found |
| u14 | Contribution record not found |
| u15 | Deadline has not been reached |
| u16 | Target was met (no refunds) |
| u17 | Contribution already withdrawn |
| u18 | Initiative not found |
| u19 | Contribution not found |
| u20 | Only deployer can withdraw fees |
| u21 | Insufficient platform balance |

## Security Features

- **No Reentrancy Risk**: Uses `as-contract` for secure transfers
- **Immutable Records**: All transactions recorded on blockchain
- **Access Control**: Only creators can release funds, only deployer can collect fees
- **Atomic Operations**: Fund transfers use `try!` to ensure atomicity
- **Type Safety**: Clarity's static typing prevents common vulnerabilities

## Gas Considerations

- Initiative creation: Moderate gas cost (map insertion + variable update)
- Contributing: Higher gas cost (multiple map updates + STX transfer)
- Releasing funds: Moderate gas cost (status update + STX transfer)
- Queries: Minimal gas cost (read-only operations)

## Usage Examples

### Example 1: Launch a Scholarship Initiative

```clarity
(contract-call? .educhain create-initiative
  "University STEM Scholarship 2025"
  "Provide scholarships to 50 underrepresented students in STEM fields"
  "scholarship"
  u500000000  ;; 500 STX target
  u52560      ;; 1 year deadline (approximately)
  u50         ;; 50 beneficiaries
)
```

### Example 2: Contribute to an Initiative

```clarity
(contract-call? .educhain contribute
  u0          ;; Initiative ID
  u10000000   ;; 10 STX contribution
)
```

### Example 3: Check Initiative Status

```clarity
(contract-call? .educhain get-initiative u0)
```

### Example 4: Retrieve Platform Statistics

```clarity
(contract-call? .educhain get-platform-stats)
```

## Deployment

1. Deploy the contract to the Stacks blockchain using `clarity-cli` or a Stacks IDE
2. The deployer address is automatically set as the contract owner
3. Begin creating initiatives and accepting contributions

## Future Enhancements

- Multi-tier rewards for contributors
- Milestone-based fund releases
- Integration with NFT badges for donors
- DAO governance for platform decisions
- Support for multiple funding tokens
- Dispute resolution mechanism

## Support

For issues, feature requests, or questions, contact the EduChain development team or open an issue in the project repository.

## License

This smart contract is provided as-is for educational and fundraising purposes on the Stacks blockchain.