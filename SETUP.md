# Quick Setup Guide

## Prerequisites Checklist

- [ ] GCP Project created
- [ ] GCP CLI (`gcloud`) installed and configured
- [ ] Terraform >= 1.5.0 installed
- [ ] Domain registered (whatwebuy.ai)
- [ ] GitHub repository created for ops-infrastructure

## Step-by-Step Setup

### 1. GCP Project Setup (5 minutes)

```bash
# Set your project ID
export GCP_PROJECT_ID="whatwebuy-prod"
export GCP_REGION="europe-west6"

# Set as default project
gcloud config set project $GCP_PROJECT_ID

# Enable billing (required)
# Visit: https://console.cloud.google.com/billing

# Enable required APIs
gcloud services enable \
  compute.googleapis.com \
  cloudresourcemanager.googleapis.com \
  iam.googleapis.com \
  --project=$GCP_PROJECT_ID
```

### 2. Create Terraform State Bucket (2 minutes)

```bash
# Create bucket
gsutil mb -p $GCP_PROJECT_ID -l $GCP_REGION gs://whatwebuy-terraform-state

# Enable versioning
gsutil versioning set on gs://whatwebuy-terraform-state

# Verify
gsutil ls -L -b gs://whatwebuy-terraform-state
```

### 3. Set Up Workload Identity for GitHub (10 minutes)

```bash
# Get your project number
export PROJECT_NUMBER=$(gcloud projects describe $GCP_PROJECT_ID --format='value(projectNumber)')
export GITHUB_ORG="your-github-username"
export REPO_NAME="ops-infrastructure"

# Create workload identity pool
gcloud iam workload-identity-pools create "github" \
  --project="${GCP_PROJECT_ID}" \
  --location="global" \
  --display-name="GitHub Actions Pool"

# Create OIDC provider
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --project="${GCP_PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="github" \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# Create service account
gcloud iam service-accounts create github-actions \
  --display-name="GitHub Actions Service Account" \
  --project="${GCP_PROJECT_ID}"

# Grant permissions
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:github-actions@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/editor"

gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:github-actions@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/iam.securityAdmin"

# Allow GitHub to impersonate service account
gcloud iam service-accounts add-iam-policy-binding \
  "github-actions@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
  --project="${GCP_PROJECT_ID}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github/attribute.repository/${GITHUB_ORG}/${REPO_NAME}"

# Get workload identity provider (copy this for GitHub secrets)
gcloud iam workload-identity-pools providers describe github-provider \
  --project="${GCP_PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="github" \
  --format="value(name)"
```

### 4. Configure GitHub Secrets (3 minutes)

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add these secrets:

1. **GCP_PROJECT_ID**: `whatwebuy-prod` (your project ID)
2. **GCP_SERVICE_ACCOUNT**: `github-actions@whatwebuy-prod.iam.gserviceaccount.com`
3. **GCP_WORKLOAD_IDENTITY_PROVIDER**: Output from previous command (looks like `projects/123.../locations/global/...`)

### 5. Configure Terraform Variables (2 minutes)

```bash
cd terraform

# Copy example file
cp ../terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

Update:
```hcl
gcp_project_id = "whatwebuy-prod"
gcp_region     = "europe-west6"
environment    = "production"
domain_name    = "whatwebuy.ai"
github_org     = "your-github-username"
```

### 6. Initial Terraform Apply (5 minutes)

```bash
# Initialize
terraform init

# Validate configuration
terraform validate

# See what will be created
terraform plan

# Apply (this will create all infrastructure)
terraform apply
```

Type `yes` when prompted.

### 7. Configure DNS in GoDaddy (5 minutes)

After Terraform completes:

```bash
# Get IP addresses
terraform output dns_records
```

Log in to GoDaddy DNS management for whatwebuy.ai:

Add these A records:
- **Name**: `api`, **Value**: [API IP], **TTL**: 600
- **Name**: `app`, **Value**: [Webapp IP], **TTL**: 600
- **Name**: `@`, **Value**: [Webapp IP], **TTL**: 600

### 8. Update Secrets (3 minutes)

```bash
# Migros credentials for enrichment service
echo -n "your-migros-email@example.com" | \
  gcloud secrets versions add migros-email --data-file=-

echo -n "your-migros-password" | \
  gcloud secrets versions add migros-password --data-file=-

# Verify
gcloud secrets versions list migros-email
gcloud secrets versions list migros-password
```

### 9. Verify Deployment (5 minutes)

```bash
# Check Cloud Run services
gcloud run services list --region=$GCP_REGION

# Get service URLs
terraform output cloud_run_services

# Test health endpoints
curl https://catalog-products-XXX.run.app/health
curl https://catalog-categories-XXX.run.app/health
curl https://consumer-transactions-XXX.run.app/health
```

### 10. Wait for SSL Certificates (15-60 minutes)

```bash
# Check SSL certificate status
gcloud compute ssl-certificates list --global

# Wait for status to change from PROVISIONING to ACTIVE
watch -n 60 'gcloud compute ssl-certificates list --global'
```

Once ACTIVE, test:
```bash
curl https://api.whatwebuy.ai/health
curl https://app.whatwebuy.ai
```

## Verification Checklist

- [ ] Terraform state bucket created and versioned
- [ ] Workload Identity configured for GitHub Actions
- [ ] GitHub secrets added
- [ ] Terraform apply completed successfully
- [ ] DNS A records added to GoDaddy
- [ ] Secrets updated in Secret Manager
- [ ] Cloud Run services are healthy
- [ ] SSL certificates are active
- [ ] Custom domains are accessible

## Next Steps

1. **Deploy Application Images**: Set up CI/CD in catalog-api, consumer-api, and consumer-webapp repos
2. **Test APIs**: Use Postman or curl to test endpoints
3. **Monitor**: Set up Cloud Monitoring alerts
4. **Backup**: Schedule Firestore exports

## Troubleshooting

### Terraform fails with permission errors
```bash
# Grant additional permissions
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:github-actions@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/compute.admin"
```

### SSL certificate stuck in PROVISIONING
- Verify DNS records are correct
- Wait 15-60 minutes
- Check: `gcloud compute ssl-certificates describe whatwebuy-api-ssl --global`

### Can't access Cloud Run services
```bash
# Make services public
gcloud run services add-iam-policy-binding catalog-products \
  --region=$GCP_REGION \
  --member="allUsers" \
  --role="roles/run.invoker"
```

## Support

- GCP Console: https://console.cloud.google.com
- Terraform Docs: https://registry.terraform.io/providers/hashicorp/google
- GitHub Actions Logs: Check workflow runs
