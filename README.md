# WhatWeBuy - Infrastructure as Code

Terraform infrastructure for deploying the WhatWeBuy platform on Google Cloud Platform.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     whatwebuy.ai Domain                      │
│                   (GoDaddy → Cloud DNS)                      │
└─────────────────────┬───────────────────────────────────────┘
                      │
        ┌─────────────┴─────────────┐
        │                           │
        ▼                           ▼
┌──────────────┐          ┌──────────────────┐
│ app.whatwebuy│          │ api.whatwebuy.ai │
│   (Webapp)   │          │   (API Gateway)  │
└──────┬───────┘          └────────┬─────────┘
       │                           │
       │                           ▼
       │              ┌────────────────────────┐
       │              │   Cloud Run Services   │
       │              ├────────────────────────┤
       │              │ • catalog-products     │
       │              │ • catalog-categories   │
       └──────────────│ • consumer-transactions│
                      │ • consumer-enrich      │
                      └──────┬─────────────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
    ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
    │  Firestore  │  │Cloud Storage│  │   Secret    │
    │  Database   │  │   Bucket    │  │   Manager   │
    └─────────────┘  └─────────────┘  └─────────────┘
```

## Services Deployed

### Catalog API Services
- **catalog-products** (Port 3001): Product catalog management
- **catalog-categories** (Port 3002): Category hierarchy management

### Consumer API Services
- **consumer-transactions** (Port 3003): Transaction storage and analytics
- **consumer-enrich** (Port 3004): Receipt enrichment pipeline with Migros integration

### Frontend
- **consumer-webapp**: React SPA for transaction visualization

## Infrastructure Components

### Core Resources
- **Firestore Database**: Shared NoSQL database for all services
- **Cloud Storage Bucket**: Storage for CSV/PDF receipt files
- **Secret Manager**: Secure credential storage (Migros login, API keys)

### Networking & SSL
- **Global Load Balancers**: HTTPS endpoints with SSL certificates
- **Cloud DNS**: Domain mapping for whatwebuy.ai
- **SSL Certificates**: Managed SSL for api.whatwebuy.ai and app.whatwebuy.ai

### CI/CD
- **GitHub Actions**: Automated terraform plan/apply on PR/merge
- **GCS Backend**: Terraform state stored in dedicated bucket

## Prerequisites

1. **GCP Project**: Create a new GCP project
2. **Domain**: Register whatwebuy.ai domain (GoDaddy or similar)
3. **GCP CLI**: Install and configure `gcloud`
4. **Terraform**: Install Terraform >= 1.5.0
5. **GitHub**: Repository for ops-infrastructure

## Setup Instructions

### 1. Create Terraform State Bucket

```bash
export GCP_PROJECT_ID="your-project-id"
export GCP_REGION="europe-west6"

# Create bucket for Terraform state
gsutil mb -p $GCP_PROJECT_ID -l $GCP_REGION gs://whatwebuy-terraform-state
gsutil versioning set on gs://whatwebuy-terraform-state

# Enable required APIs
gcloud services enable compute.googleapis.com \
  cloudresourcemanager.googleapis.com \
  iam.googleapis.com \
  --project=$GCP_PROJECT_ID
```

### 2. Set Up Workload Identity Federation for GitHub Actions

```bash
# Create a workload identity pool
gcloud iam workload-identity-pools create "github" \
  --project="${GCP_PROJECT_ID}" \
  --location="global" \
  --display-name="GitHub Actions Pool"

# Create a provider in the pool
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --project="${GCP_PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="github" \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# Create a service account for GitHub Actions
gcloud iam service-accounts create github-actions \
  --display-name="GitHub Actions" \
  --project="${GCP_PROJECT_ID}"

# Grant necessary permissions to the service account
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:github-actions@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/editor"

# Allow GitHub Actions to impersonate the service account
export REPO_OWNER="your-github-username"
export REPO_NAME="ops-infrastructure"

gcloud iam service-accounts add-iam-policy-binding \
  "github-actions@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
  --project="${GCP_PROJECT_ID}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github/attribute.repository/${REPO_OWNER}/${REPO_NAME}"

# Get the workload identity provider resource name
gcloud iam workload-identity-pools providers describe github-provider \
  --project="${GCP_PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="github" \
  --format="value(name)"
```

### 3. Configure GitHub Secrets

Add these secrets to your GitHub repository:

- `GCP_PROJECT_ID`: Your GCP project ID
- `GCP_SERVICE_ACCOUNT`: github-actions@PROJECT_ID.iam.gserviceaccount.com
- `GCP_WORKLOAD_IDENTITY_PROVIDER`: Full resource name from step 2

### 4. Initialize Terraform

```bash
cd terraform

# Create terraform.tfvars
cat > terraform.tfvars <<EOF
gcp_project_id = "your-project-id"
gcp_region     = "europe-west6"
environment    = "production"
domain_name    = "whatwebuy.ai"
github_org     = "your-github-org"
EOF

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply infrastructure
terraform apply
```

### 5. Configure DNS in GoDaddy

After applying Terraform, configure these A records in GoDaddy:

```bash
# Get the IP addresses
terraform output dns_records
```

Add in GoDaddy DNS management:
- **Type**: A, **Name**: `api`, **Value**: [API IP from output], **TTL**: 300
- **Type**: A, **Name**: `app`, **Value**: [Webapp IP from output], **TTL**: 300
- **Type**: A, **Name**: `@`, **Value**: [Webapp IP from output], **TTL**: 300

### 6. Update Secrets in Secret Manager

```bash
# Update Migros credentials
echo -n "your-email@example.com" | gcloud secrets versions add migros-email --data-file=-
echo -n "your-password" | gcloud secrets versions add migros-password --data-file=-

# Update API keys (if needed)
echo -n '{"some_api": "key_value"}' | gcloud secrets versions add api-keys --data-file=-
```

## Deployment Workflow

### Manual Deployment
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### Automated CI/CD
1. **Pull Request**: Creates a plan and comments on PR
2. **Merge to Main**: Automatically applies changes
3. **State Management**: Stored in GCS bucket

## Service URLs

After deployment:
- **API Gateway**: https://api.whatwebuy.ai
- **Webapp**: https://app.whatwebuy.ai or https://whatwebuy.ai
- **Direct Cloud Run URLs**: See `terraform output cloud_run_services`

## API Endpoints

### Catalog API
- `GET /products` - List products
- `GET /products/:id` - Get product details
- `POST /products` - Bulk upsert products
- `GET /categories` - List categories
- `GET /categories/:id` - Get category details
- `POST /categories` - Bulk upsert categories

### Consumer API
- `GET /transactions` - List transactions with filters
- `GET /transactions/:id` - Get transaction details
- `POST /transactions` - Bulk upsert transactions
- `POST /enrich` - Trigger enrichment pipeline

## Monitoring & Logs

```bash
# View Cloud Run logs
gcloud logging read "resource.type=cloud_run_revision" --limit 50

# View specific service logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=catalog-products" --limit 50

# Monitor Cloud Run metrics
gcloud monitoring dashboards list
```

## Cost Optimization

- **Cloud Run**: Pay per request, scales to zero
- **Firestore**: Pay per read/write operation
- **Cloud Storage**: Lifecycle policies move old files to Nearline (30 days) and delete after 90 days
- **Load Balancers**: Minimal cost for low traffic

Estimated monthly cost: $10-50 for low traffic

## Maintenance

### Update Terraform Version
```bash
# In .github/workflows/terraform.yml, update:
TF_VERSION: '1.6.0'
```

### Rotate Secrets
```bash
gcloud secrets versions add migros-password --data-file=- < new_password.txt
```

### Backup Firestore
```bash
gcloud firestore export gs://whatwebuy-terraform-state/firestore-backups
```

## Troubleshooting

### SSL Certificate Not Provisioning
- Verify DNS records are correct (A records pointing to load balancer IPs)
- Wait 15-60 minutes for certificate provisioning
- Check: `gcloud compute ssl-certificates describe whatwebuy-api-ssl --global`

### Cloud Run Service Not Accessible
- Verify IAM policies allow public access
- Check Cloud Run service logs
- Ensure environment variables are set correctly

### Terraform State Locked
```bash
# If state is stuck
terraform force-unlock LOCK_ID
```

## Security Considerations

1. **Secret Management**: Never commit secrets to Git
2. **IAM Policies**: Use least privilege principle
3. **Network Security**: Cloud Run services behind load balancer
4. **SSL/TLS**: Enforce HTTPS only (HTTP redirects to HTTPS)
5. **Service Accounts**: Each service has dedicated SA with minimal permissions

## Contributing

1. Create a feature branch
2. Make changes to Terraform files
3. Open PR (triggers `terraform plan`)
4. Review plan in PR comment
5. Merge to main (triggers `terraform apply`)

## Support

For issues or questions:
- Check logs: `gcloud logging read`
- Review terraform outputs: `terraform output`
- GCP Console: https://console.cloud.google.com

## License

Private - All rights reserved
