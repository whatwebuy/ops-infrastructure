# Quick Start Guide

Get WhatWeBuy infrastructure up and running in 30 minutes.

## Prerequisites (5 min)

- [ ] GCP account with billing enabled
- [ ] `gcloud` CLI installed ([Download](https://cloud.google.com/sdk/docs/install))
- [ ] Terraform >= 1.5.0 installed ([Download](https://www.terraform.io/downloads))
- [ ] GitHub account
- [ ] Domain registered (whatwebuy.ai)

## Setup Steps

### 1. Clone Repository (1 min)

```bash
git clone https://github.com/YOUR_ORG/ops-infrastructure.git
cd ops-infrastructure
```

### 2. Run Setup Script (10 min)

```bash
chmod +x scripts/setup-gcp.sh
./scripts/setup-gcp.sh
```

This script will:
- Enable required GCP APIs
- Create Terraform state bucket
- Set up Workload Identity for GitHub Actions
- Create service accounts
- Generate terraform.tfvars

Follow the prompts to enter:
- GCP Project ID
- GCP Region
- GitHub Organization
- Repository Name

### 3. Configure GitHub Secrets (2 min)

Go to: `https://github.com/YOUR_ORG/ops-infrastructure/settings/secrets/actions`

Add three secrets (values provided by setup script):
- `GCP_PROJECT_ID`
- `GCP_SERVICE_ACCOUNT`
- `GCP_WORKLOAD_IDENTITY_PROVIDER`

### 4. Deploy Infrastructure (5 min)

```bash
cd terraform
terraform init
terraform plan   # Review what will be created
terraform apply  # Type 'yes' to confirm
```

Wait for deployment to complete (~5 minutes).

### 5. Configure DNS (3 min)

Get IP addresses:
```bash
terraform output dns_records
```

Log in to GoDaddy and add A records:
- `api.whatwebuy.ai` → [API IP]
- `app.whatwebuy.ai` → [Webapp IP]
- `@` (root domain) → [Webapp IP]

TTL: 600 seconds

### 6. Update Secrets (2 min)

```bash
# Migros credentials
echo -n "your-migros-email@example.com" | \
  gcloud secrets versions add migros-email --data-file=-

echo -n "your-migros-password" | \
  gcloud secrets versions add migros-password --data-file=-
```

### 7. Verify Deployment (5 min)

```bash
# Check Cloud Run services
gcloud run services list

# Test health endpoints (use URLs from output)
curl https://catalog-products-XXX.run.app/health
curl https://catalog-categories-XXX.run.app/health
curl https://consumer-transactions-XXX.run.app/health
curl https://consumer-enrich-XXX.run.app/health
```

### 8. Wait for SSL (15-60 min)

```bash
# Check SSL certificate status
gcloud compute ssl-certificates list --global

# Wait for status: ACTIVE
watch -n 60 'gcloud compute ssl-certificates list --global'
```

Once active, test custom domains:
```bash
curl https://api.whatwebuy.ai/health
curl https://app.whatwebuy.ai
```

## Next Steps

### Deploy Application Code

Set up CI/CD in each application repository to build and deploy Docker images:

1. **catalog-api**: Build and push images for catalog-products and catalog-categories
2. **consumer-api**: Build and push images for consumer-transactions and consumer-enrich
3. **consumer-webapp**: Build and push webapp image

See each repository's README for deployment instructions.

### Test the Platform

```bash
# 1. Trigger enrichment
curl -X POST https://api.whatwebuy.ai/enrich \
  -H "Content-Type: application/json" \
  -d '{
    "email": "your-migros-email@example.com",
    "password": "your-password",
    "year": 2024
  }'

# 2. View transactions
curl https://api.whatwebuy.ai/transactions

# 3. Open webapp
open https://app.whatwebuy.ai
```

### Monitor Services

```bash
# View logs
gcloud logging read "resource.type=cloud_run_revision" --limit 50

# View specific service
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=catalog-products" \
  --limit 20

# Monitor in console
open https://console.cloud.google.com/run
```

## Common Issues

### "Permission denied" errors
```bash
# Grant additional permissions to your user
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="user:YOUR_EMAIL" \
  --role="roles/editor"
```

### "Bucket already exists" error
The state bucket might exist from a previous setup. Either:
- Use the existing bucket, or
- Delete it: `gsutil rm -r gs://whatwebuy-terraform-state`

### SSL certificate not provisioning
- Verify DNS records are correct (can take 5-10 min to propagate)
- Wait 15-60 minutes for Google to provision certificate
- Check status: `gcloud compute ssl-certificates describe whatwebuy-api-ssl --global`

### Services not accessible
```bash
# Make service public
gcloud run services add-iam-policy-binding SERVICE_NAME \
  --region=REGION \
  --member="allUsers" \
  --role="roles/run.invoker"
```

## Cost Estimate

With minimal usage (testing/development):
- **Cloud Run**: $5-10/month (scales to zero)
- **Firestore**: $5-10/month
- **Cloud Storage**: $1-5/month
- **Load Balancer**: $5-10/month
- **Total**: ~$16-35/month

## Cleanup

To destroy all infrastructure:

```bash
cd terraform
terraform destroy
```

To delete the project entirely:
```bash
gcloud projects delete PROJECT_ID
```

## Support

- **Documentation**: See [README.md](README.md) and [ARCHITECTURE.md](ARCHITECTURE.md)
- **Detailed Setup**: See [SETUP.md](SETUP.md)
- **Issues**: Create GitHub issue
