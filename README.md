# Off-Chain Multi-Signature Wallet
A multisignature wallet implementation that shifts the approval process off-chain using EIP-712 structured data signatures.

This contract allows owners to sign messages for free. A single executor then submits the transaction along with the collected signatures, paying the gas fee only once.

```mermaid
graph TD

    Start([Call: executeWithSignatures]) --> Checks{Basic Checks}
    
    Checks -- "Nonce Used OR Sigs < Threshold" --> Revert1[REVERT]
    Checks -- Pass --> Hash[Compute EIP-712 Digest]

    subgraph Verification_Loop [Signature Verification Loop]
        Hash --> Recover[Recover Signer from Signature]
        Recover --> IsOwner{Is Owner?}
        
        IsOwner -- No --> Revert2[REVERT: Invalid Signer]
        IsOwner -- Yes --> IsSorted{Signer > LastSigner?}
        
        IsSorted -- No --> Revert3[REVERT: Unsorted/Duplicate]
        IsSorted -- Yes --> UpdateLast[LastSigner = Signer]
        
        UpdateLast --> MoreSigs{More Signatures?}
        MoreSigs -- Yes --> Recover
    end

    MoreSigs -- No --> MarkNonce[Storage: Mark Nonce as Used]
    MarkNonce --> Execute[Low-Level Call to Target]
    
    Execute --> Success{Call Success?}
    Success -- No --> Revert4[REVERT: Tx Failed]
    Success -- Yes --> End([Event: Transaction Executed])

    
    linkStyle default stroke:#333333,stroke-width:1px;
    
    style Start fill:#ffffff,stroke:#000000,stroke-width:2px,color:#000000
    
    style Revert1 fill:#e0e0e0,stroke:#000000,stroke-width:1px,color:#000000
    style Revert2 fill:#e0e0e0,stroke:#000000,stroke-width:1px,color:#000000
    style Revert3 fill:#e0e0e0,stroke:#000000,stroke-width:1px,color:#000000
    style Revert4 fill:#e0e0e0,stroke:#000000,stroke-width:1px,color:#000000
    
    style End fill:#ffffff,stroke:#000000,stroke-width:4px,color:#000000
    
    style Verification_Loop fill:#ffffff,stroke:#666666,stroke-dasharray: 5 5,color:#000000
