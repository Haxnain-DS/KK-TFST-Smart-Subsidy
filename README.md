# KK-TFST: Fertilizer Smart Subsidy System

This project implements a blockchain-based smart subsidy management system for fertilizer distribution. [cite_start]It utilizes a dual-contract architecture to separate eligibility logic from supply chain settlement[cite: 37, 38].

## Project Overview

[cite_start]The system is designed to prevent fraud and ensure transparency in government subsidies by tracking the lifecycle of a subsidy token ("GFS") from issuance to redemption[cite: 167].

### Core Components

1.  [cite_start]**EligibilityRegistry.sol**: A database contract that maintains a registry of verified farmers, their CNIC hashes, and land records[cite: 112, 124].
2.  [cite_start]**FertilizerSupplyChain.sol**: An ERC20-based contract that handles the issuance of subsidy tokens, transfers to dealers, and final settlement/burning of tokens for fiat redemption[cite: 150].

## Workflow Diagram

```mermaid
sequenceDiagram
    participant Govt as Government (Admin)
    participant Reg as EligibilityRegistry
    participant Chain as SupplyChain
    participant Farmer
    participant Dealer

    Govt->>Reg: registerFarmer(Address, CNIC, LandSize)
    Govt->>Chain: authorizeDealer(DealerAddress)
    Govt->>Chain: issueSubsidy(Farmer, Amount)
    Chain->>Reg: isEligible(Farmer)?
    Reg-->>Chain: Returns True
    Chain->>Farmer: Mints "GFS" Tokens
    Farmer->>Dealer: transfer(Tokens) for Fertilizer Bags
    Dealer->>Chain: redeemForSettlement(Amount, BankDetails)
    Chain->>Dealer: Burns Tokens & Emits Settlement Event