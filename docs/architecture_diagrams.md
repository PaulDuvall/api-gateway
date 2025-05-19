# Hello World API Architecture Diagrams

This document provides visual representations of the Hello World API architecture using Mermaid diagrams.

## System Architecture

```mermaid
flowchart TD
    User([User/Client]) -->|HTTP Request with API Key| APIG[API Gateway]
    APIG -->|Throttling| UP[Usage Plan]
    UP -->|Rate Limit: 2 req/min| APIG
    APIG -->|Forward Request| Lambda[AWS Lambda Function]
    Lambda -->|Process Request| Lambda
    Lambda -->|Read Config| SSM[Parameter Store]
    Lambda -->|Write Logs| CW[CloudWatch Logs]
    APIG -->|HTTP Response| User
    
    subgraph AWS Cloud
        APIG
        Lambda
        SSM
        CW
        UP
    end
    
    style User fill:#f9f,stroke:#333,stroke-width:2px
    style APIG fill:#ff9,stroke:#333,stroke-width:2px
    style Lambda fill:#9cf,stroke:#333,stroke-width:2px
    style SSM fill:#9f9,stroke:#333,stroke-width:2px
    style CW fill:#fcf,stroke:#333,stroke-width:2px
    style UP fill:#f96,stroke:#333,stroke-width:2px
```

## Deployment Architecture

```mermaid
flowchart TD
    Dev([Developer]) -->|git push| GH[GitHub Repository]
    GH -->|Trigger| GHWF[GitHub Actions Workflow]
    GHWF -->|Assume Role via OIDC| IAM[IAM Role]
    GHWF -->|Deploy| CF[CloudFormation]
    CF -->|Create/Update| Resources[AWS Resources]
    
    subgraph AWS Resources
        APIG[API Gateway]
        Lambda[Lambda Function]
        SSM[Parameter Store]
        APIKey[API Key]
        UP[Usage Plan]
    end
    
    Resources --> APIG
    Resources --> Lambda
    Resources --> SSM
    Resources --> APIKey
    Resources --> UP
    
    style Dev fill:#f9f,stroke:#333,stroke-width:2px
    style GH fill:#9cf,stroke:#333,stroke-width:2px
    style GHWF fill:#9cf,stroke:#333,stroke-width:2px
    style CF fill:#ff9,stroke:#333,stroke-width:2px
    style IAM fill:#f96,stroke:#333,stroke-width:2px
    style Resources fill:#9f9,stroke:#333,stroke-width:2px
```

## API Key Management Workflow

```mermaid
sequenceDiagram
    participant User as Developer
    participant Script as manage_api_key.sh
    participant AWS as AWS API Gateway
    participant CF as CloudFormation
    
    User->>Script: ./manage_api_key.sh create <stack> <stage>
    Script->>CF: Get API ID from stack
    CF-->>Script: Return API ID
    Script->>AWS: Create API Key
    AWS-->>Script: Return API Key ID
    Script->>AWS: Create Usage Plan
    AWS-->>Script: Return Usage Plan ID
    Script->>AWS: Associate API Key with Usage Plan
    Script->>AWS: Update API methods to require key
    Script-->>User: Display success message
    
    User->>Script: ./manage_api_key.sh get-api-key <stack>
    Script->>CF: Get API Key ID from stack
    CF-->>Script: Return API Key ID
    Script->>AWS: Get API Key Value
    AWS-->>Script: Return API Key Value
    Script-->>User: Display API Key Value and usage examples
    
    User->>Script: ./manage_api_key.sh list
    Script->>AWS: List API Keys
    AWS-->>Script: Return API Keys list
    Script-->>User: Display API Keys
    
    User->>Script: ./manage_api_key.sh delete <key-id>
    Script->>AWS: Delete API Key
    AWS-->>Script: Confirm deletion
    Script-->>User: Display success message
```

## Deployment Process

```mermaid
stateDiagram-v2
    [*] --> Setup: ./run.sh setup
    Setup --> Test: ./run.sh test
    Test --> Package: ./run.sh package
    Package --> Deploy: ./run.sh cloudformation
    Deploy --> Verify: ./run.sh test-api
    
    Setup: Set up Python virtual environment
    Setup: Install dependencies
    
    Test: Run unit tests
    Test: Verify Lambda function
    
    Package: Create deployment package
    Package: Zip Lambda function
    
    Deploy: Deploy with CloudFormation
    Deploy: Create/update resources
    Deploy: Configure API Gateway
    
    Verify: Test API with API Key
    Verify: Verify throttling
    
    Verify --> [*]
```

## Component Relationships

```mermaid
erDiagram
    API-GATEWAY ||--o{ LAMBDA : invokes
    API-GATEWAY ||--|| API-KEY : requires
    API-KEY ||--|| USAGE-PLAN : associated-with
    USAGE-PLAN ||--|| THROTTLING : configures
    LAMBDA ||--o{ PARAMETER-STORE : reads-from
    LAMBDA ||--o{ CLOUDWATCH : logs-to
    GITHUB-ACTIONS ||--|| OIDC : authenticates-via
    GITHUB-ACTIONS ||--|| CLOUDFORMATION : deploys
    CLOUDFORMATION ||--o{ AWS-RESOURCES : creates
```

## Security Architecture

```mermaid
flowchart TD
    Client([Client]) -->|Request with API Key| APIG[API Gateway]
    APIG -->|Validate| APIKey[API Key]
    APIG -->|Throttle| UP[Usage Plan]
    APIG -->|Forward| Lambda[Lambda Function]
    
    subgraph Security Controls
        APIKey
        UP[Usage Plan/Throttling]
        IAMRole[IAM Role with Least Privilege]
        OIDC[OIDC Authentication]
    end
    
    Lambda -->|Assume| IAMRole
    GHWF[GitHub Actions] -->|Authenticate| OIDC
    OIDC -->|Temporary Credentials| AWS[AWS Services]
    
    style Client fill:#f9f,stroke:#333,stroke-width:2px
    style APIG fill:#ff9,stroke:#333,stroke-width:2px
    style Lambda fill:#9cf,stroke:#333,stroke-width:2px
    style Security fill:#f96,stroke:#333,stroke-width:2px
```

## Planned Enhancements Architecture

```mermaid
flowchart TD
    Client([Client]) -->|GET Request| APIG[API Gateway]
    Client -->|POST Request| APIG
    Client -->|Request Presigned URL| APIG
    Client -->|Upload File| S3[S3 Bucket]
    
    APIG -->|Process GET| Lambda[Lambda Function]
    APIG -->|Process POST| Lambda
    APIG -->|Generate Presigned URL| Lambda
    
    Lambda -->|Create Presigned URL| S3
    Lambda -->|Store Metadata| DDB[DynamoDB]
    Lambda -->|Query Metadata| DDB
    
    subgraph AWS Cloud
        APIG
        Lambda
        S3
        DDB
        CW[CloudWatch]
    end
    
    Lambda -->|Log Events| CW
    
    style Client fill:#f9f,stroke:#333,stroke-width:2px
    style APIG fill:#ff9,stroke:#333,stroke-width:2px
    style Lambda fill:#9cf,stroke:#333,stroke-width:2px
    style S3 fill:#9f9,stroke:#333,stroke-width:2px
    style DDB fill:#f96,stroke:#333,stroke-width:2px
    style CW fill:#fcf,stroke:#333,stroke-width:2px
```

## File Upload Sequence

```mermaid
sequenceDiagram
    participant Client
    participant APIG as API Gateway
    participant Lambda
    participant S3
    participant DDB as DynamoDB
    
    Client->>APIG: Request presigned URL (with API Key)
    APIG->>Lambda: Forward request
    Lambda->>S3: Generate presigned URL
    S3-->>Lambda: Return presigned URL
    Lambda->>APIG: Return presigned URL to client
    APIG-->>Client: Presigned URL response
    
    Client->>S3: Upload file directly using presigned URL
    S3-->>Client: Upload confirmation
    
    S3->>Lambda: Trigger on S3 event (file uploaded)
    Lambda->>DDB: Store file metadata
    Lambda->>S3: Set lifecycle policy based on metadata
```
