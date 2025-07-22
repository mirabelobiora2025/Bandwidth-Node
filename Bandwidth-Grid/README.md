# Decentralized Bandwidth Sharing Smart Contract

A Clarity smart contract that enables users to share and monetize bandwidth in a decentralized peer-to-peer network on the Stacks blockchain.

## Overview

This smart contract creates a marketplace where users can either provide their excess bandwidth to earn STX tokens or consume bandwidth from providers by paying with STX. The system includes reputation scoring, quality ratings, and automated payment processing.

## Features

- **Dual Role System**: Users can be providers (selling bandwidth) or consumers (buying bandwidth)
- **Reputation System**: Both providers and consumers have reputation scores (0-100) that affect their ability to participate
- **Quality Ratings**: Consumers can rate session quality, which impacts provider reputation
- **Automated Payments**: Smart contract handles payments with platform fees
- **Geographic Location**: Providers can specify their location for better matching
- **Performance Metrics**: Detailed analytics for providers including uptime and data served
- **Emergency Controls**: Contract owner can pause operations if needed

## Contract Architecture

### Data Structures

#### Providers
- **Bandwidth Capacity**: Total available bandwidth in Mbps
- **Available Bandwidth**: Currently unused bandwidth
- **Price per MB**: Cost in microSTX per megabyte
- **Reputation Score**: 0-100 score based on service quality
- **Location**: Geographic location string
- **Uptime Percentage**: Historical uptime (0-10000 where 10000 = 100%)

#### Consumers
- **Balance**: Prepaid STX balance for purchasing bandwidth
- **Total Consumed**: Historical data consumption in MB
- **Reputation Score**: 0-100 score based on payment history
- **Sessions Count**: Number of completed sessions

#### Sessions
- **Bandwidth Allocated**: Reserved bandwidth in Mbps
- **Data Consumed**: Actual data transferred in MB
- **Duration**: Start and end block heights
- **Cost**: Total session cost in microSTX
- **Quality Score**: Consumer-provided rating (1-100)

## Getting Started

### For Providers

1. **Register as Provider**
   ```clarity
   (contract-call? .bandwidth-sharing register-provider 
     u100    ;; 100 Mbps capacity
     u1000   ;; 1000 microSTX per MB
     "New York, US")  ;; Location
   ```

2. **Update Settings** (optional)
   ```clarity
   (contract-call? .bandwidth-sharing update-provider-settings
     (some u800)  ;; New price: 800 microSTX per MB
     (some u200)  ;; New capacity: 200 Mbps
     (some true)) ;; Active status
   ```

3. **Withdraw Earnings**
   ```clarity
   (contract-call? .bandwidth-sharing withdraw-earnings u50000000) ;; 50 STX
   ```

### For Consumers

1. **Register as Consumer**
   ```clarity
   (contract-call? .bandwidth-sharing register-consumer u100000000) ;; 100 STX initial balance
   ```

2. **Add Balance** (when needed)
   ```clarity
   (contract-call? .bandwidth-sharing add-balance u50000000) ;; Add 50 STX
   ```

3. **Start Session**
   ```clarity
   (contract-call? .bandwidth-sharing start-session
     'SP1ABC...PROVIDER  ;; Provider's principal
     u50)               ;; 50 Mbps required
   ```

4. **End Session**
   ```clarity
   (contract-call? .bandwidth-sharing end-session
     u123  ;; Session ID
     u500) ;; 500 MB consumed
   ```

5. **Rate Session Quality**
   ```clarity
   (contract-call? .bandwidth-sharing rate-session
     u123  ;; Session ID
     u85)  ;; Quality score (85/100)
   ```

## Read-Only Functions

### Get Information
```clarity
;; Get provider details
(contract-call? .bandwidth-sharing get-provider 'SP1ABC...PROVIDER)

;; Get consumer details  
(contract-call? .bandwidth-sharing get-consumer 'SP1DEF...CONSUMER)

;; Get session information
(contract-call? .bandwidth-sharing get-session u123)

;; Get contract statistics
(contract-call? .bandwidth-sharing get-contract-stats)
```

### Utility Functions
```clarity
;; Calculate session cost
(contract-call? .bandwidth-sharing calculate-session-cost u500 u1000) ;; 500 MB at 1000 microSTX/MB

;; Check if provider can serve bandwidth
(contract-call? .bandwidth-sharing can-provider-serve 'SP1ABC...PROVIDER u50)

;; Get platform fee for amount
(contract-call? .bandwidth-sharing get-platform-fee u1000000) ;; Fee for 1 STX
```

## Economics

### Fee Structure
- **Platform Fee**: 2.5% of each transaction
- **Payment Flow**: Consumer → Contract → Provider (minus platform fee)
- **Currency**: All payments in microSTX (1 STX = 1,000,000 microSTX)

### Reputation System
- **Initial Score**: 75/100 for new users
- **Minimum Required**: 50/100 to participate
- **Provider Updates**: Based on quality ratings from consumers
- **Consumer Updates**: Based on payment history and session behavior

## Security Features

### Access Controls
- **Provider Functions**: Only registered providers can update settings and withdraw
- **Consumer Functions**: Only session participants can end sessions and rate quality
- **Owner Functions**: Emergency pause and platform fee withdrawal

### Validation Checks
- Sufficient balance verification before session start
- Bandwidth availability confirmation
- Reputation threshold enforcement
- Session state validation
- Amount and parameter validation

### Error Handling
The contract includes comprehensive error codes:
- `ERR_UNAUTHORIZED (u100)`: Permission denied
- `ERR_INVALID_AMOUNT (u101)`: Invalid payment amount
- `ERR_INSUFFICIENT_BALANCE (u102)`: Not enough balance
- `ERR_PROVIDER_NOT_FOUND (u103)`: Provider doesn't exist
- `ERR_SESSION_ALREADY_ACTIVE (u106)`: User has active session
- `ERR_REPUTATION_TOO_LOW (u112)`: Below minimum reputation

## Contract Administration

### Owner Functions
```clarity
;; Pause contract operations
(contract-call? .bandwidth-sharing set-contract-pause true)

;; Withdraw platform fees
(contract-call? .bandwidth-sharing withdraw-platform-fees u25000000) ;; 25 STX
```

## Deployment Requirements

### Prerequisites
- Stacks blockchain node access
- Clarity CLI tools
- STX tokens for deployment costs

### Deployment Steps
1. Deploy contract to Stacks testnet/mainnet
2. Verify contract functions
3. Set initial parameters if needed
4. Announce contract address to users

## Integration Examples

### Frontend Integration
```javascript
// Start a bandwidth session
const startSession = async (providerAddress, bandwidthMbps) => {
  const txOptions = {
    contractAddress: 'ST1ABC...CONTRACT',
    contractName: 'bandwidth-sharing',
    functionName: 'start-session',
    functionArgs: [
      principalCV(providerAddress),
      uintCV(bandwidthMbps)
    ]
  };
  
  return await openContractCall(txOptions);
};
```

### Monitoring and Analytics
- Track provider performance metrics by period
- Monitor contract statistics for network health
- Analyze reputation trends and session quality