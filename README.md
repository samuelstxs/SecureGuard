# SecureGuard Insurance Protocol

A decentralized insurance protocol built on Stacks blockchain for protecting digital assets through smart contracts.

## Overview

SecureGuard provides a trustless insurance mechanism where users can:
- Create insurance policies for digital assets
- Pay premiums in STX tokens
- Submit claims for covered losses
- Receive automated payouts for approved claims

## Features

- **Policy Creation**: Users can create custom insurance policies with specified coverage amounts and durations
- **Premium Calculation**: Automated premium calculation based on coverage amount and policy duration
- **Claims Processing**: Structured claim submission and processing workflow
- **Multi-Asset Support**: Support for various digital asset types
- **Transparent Operations**: All transactions and policy data stored on-chain

## Smart Contract Functions

### Public Functions

- `create-policy(coverage-amount, duration-blocks, asset-type)` - Create a new insurance policy
- `submit-claim(policy-id, claim-amount)` - Submit a claim for a policy
- `process-claim(claim-id, approved)` - Process pending claims (owner only)
- `cancel-policy(policy-id)` - Cancel an active policy

### Read-Only Functions

- `get-policy(policy-id)` - Retrieve policy details
- `get-claim(claim-id)` - Retrieve claim information
- `get-user-policies(user)` - Get all policies for a user
- `get-premium-estimate(coverage-amount, duration-blocks)` - Calculate premium estimate
- `get-total-premium-pool()` - Get total premium pool balance
- `is-policy-valid(policy-id)` - Check if policy is active and valid

## Usage Example

```clarity
;; Create a policy for 1000 STX coverage for 1 year
(contract-call? .secureguard create-policy u1000000000 u52560 "digital-assets")

;; Submit a claim for 500 STX
(contract-call? .secureguard submit-claim u1 u500000000)
```

## Development

### Prerequisites

- Clarinet
- Stacks CLI

### Testing

```bash
clarinet check
clarinet test
```

### Deployment

```bash
clarinet deploy --network testnet
```

## Security Considerations

- All premium calculations are performed on-chain
- Claims require manual approval to prevent fraudulent payouts
- Policy ownership is verified for all operations
- Contract includes comprehensive error handling

## License

MIT License