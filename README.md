# Off-Chain Multi-Signature Wallet
A multisignature wallet implementation that shifts the approval process off-chain using EIP-712 structured data signatures.

This contract allows owners to sign messages for free. A single executor then submits the transaction along with the collected signatures, paying the gas fee only once.

```mermaid
sequenceDiagram
    participant Owner1
    participant Owner2
    participant Executor (Relayer)
    participant Multisig Contract
    participant Target Contract

    Note over Owner1, Owner2: Off-Chain Actions (Gasless)
    Owner1->>Owner1: Sign Typed Data (Tx Details + Nonce)
    Owner2->>Owner2: Sign Typed Data (Tx Details + Nonce)
    
    Owner1->>Executor (Relayer): Send Signature
    Owner2->>Executor (Relayer): Send Signature

    Note over Executor (Relayer): On-Chain Action (Pays Gas)
    Executor (Relayer)->>Multisig Contract: executeWithSignatures(to, val, data, sigs[])
    
    activate Multisig Contract
    Multisig Contract->>Multisig Contract: Verify EIP712 Domain
    Multisig Contract->>Multisig Contract: Recover Signers & Check Threshold
    Multisig Contract->>Multisig Contract: Enforce Sort (Signer A < Signer B)
    Multisig Contract->>Multisig Contract: Mark Nonce as Used
    
    Multisig Contract->>Target Contract: Low-level Call (value, data)
    Target Contract-->>Multisig Contract: Success
    deactivate Multisig Contract
