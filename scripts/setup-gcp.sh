#!/bin/bash
set -e

# WhatWeBuy GCP Infrastructure Setup Script
# This script automates the initial GCP setup for Terraform

echo "🚀 WhatWeBuy Infrastructure Setup"
echo "=================================="
echo ""

# Check if required tools are installed
command -v gcloud >/dev/null 2>&1 || { echo "❌ gcloud CLI is required but not installed. Aborting." >&2; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo "❌ Terraform is required but not installed. Aborting." >&2; exit 1; }

echo "✅ Required tools found"
echo ""

# Prompt for configuration
read -p "Enter GCP Project ID [whatwebuy-prod]: " GCP_PROJECT_ID
GCP_PROJECT_ID=${GCP_PROJECT_ID:-whatwebuy-prod}

read -p "Enter GCP Region [europe-west6]: " GCP_REGION
GCP_REGION=${GCP_REGION:-europe-west6}

read -p "Enter GitHub Organization/Username: " GITHUB_ORG
if [ -z "$GITHUB_ORG" ]; then
    echo "❌ GitHub organization is required"
    exit 1
fi

read -p "Enter GitHub Repository Name [ops-infrastructure]: " REPO_NAME
REPO_NAME=${REPO_NAME:-ops-infrastructure}

echo ""
echo "Configuration:"
echo "  Project ID: $GCP_PROJECT_ID"
echo "  Region: $GCP_REGION"
echo "  GitHub: $GITHUB_ORG/$REPO_NAME"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Set project
echo ""
echo "📝 Setting GCP project..."
gcloud config set project $GCP_PROJECT_ID

# Get project number
PROJECT_NUMBER=$(gcloud projects describe $GCP_PROJECT_ID --format='value(projectNumber)')
echo "Project Number: $PROJECT_NUMBER"

# Enable required APIs
echo ""
echo "🔧 Enabling required APIs..."
gcloud services enable \
  compute.googleapis.com \
  cloudresourcemanager.googleapis.com \
  iam.googleapis.com \
  --project=$GCP_PROJECT_ID

# Create Terraform state bucket
echo ""
echo "📦 Creating Terraform state bucket..."
if gsutil ls -b gs://whatwebuy-terraform-state >/dev/null 2>&1; then
    echo "⚠️  Bucket already exists, skipping..."
else
    gsutil mb -p $GCP_PROJECT_ID -l $GCP_REGION gs://whatwebuy-terraform-state
    gsutil versioning set on gs://whatwebuy-terraform-state
    echo "✅ Bucket created with versioning enabled"
fi

# Create Workload Identity Pool
echo ""
echo "🔐 Setting up Workload Identity for GitHub Actions..."

if gcloud iam workload-identity-pools describe github --project=$GCP_PROJECT_ID --location=global >/dev/null 2>&1; then
    echo "⚠️  Workload identity pool already exists, skipping..."
else
    gcloud iam workload-identity-pools create "github" \
      --project="${GCP_PROJECT_ID}" \
      --location="global" \
      --display-name="GitHub Actions Pool"
    echo "✅ Workload identity pool created"
fi

# Create OIDC provider
if gcloud iam workload-identity-pools providers describe github-provider --workload-identity-pool=github --project=$GCP_PROJECT_ID --location=global >/dev/null 2>&1; then
    echo "⚠️  OIDC provider already exists, skipping..."
else
    gcloud iam workload-identity-pools providers create-oidc "github-provider" \
      --project="${GCP_PROJECT_ID}" \
      --location="global" \
      --workload-identity-pool="github" \
      --display-name="GitHub Provider" \
      --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
      --issuer-uri="https://token.actions.githubusercontent.com"
    echo "✅ OIDC provider created"
fi

# Create service account
echo ""
echo "👤 Creating GitHub Actions service account..."
if gcloud iam service-accounts describe github-actions@${GCP_PROJECT_ID}.iam.gserviceaccount.com >/dev/null 2>&1; then
    echo "⚠️  Service account already exists, skipping..."
else
    gcloud iam service-accounts create github-actions \
      --display-name="GitHub Actions Service Account" \
      --project="${GCP_PROJECT_ID}"
    echo "✅ Service account created"
fi

# Grant permissions
echo ""
echo "🔑 Granting permissions..."
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:github-actions@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/editor" \
  --condition=None >/dev/null 2>&1

gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:github-actions@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/iam.securityAdmin" \
  --condition=None >/dev/null 2>&1

echo "✅ Permissions granted"

# Allow GitHub to impersonate service account
echo ""
echo "🔗 Configuring Workload Identity binding..."
gcloud iam service-accounts add-iam-policy-binding \
  "github-actions@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
  --project="${GCP_PROJECT_ID}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github/attribute.repository/${GITHUB_ORG}/${REPO_NAME}" \
  >/dev/null 2>&1

echo "✅ Workload Identity binding configured"

# Get workload identity provider
WORKLOAD_IDENTITY_PROVIDER=$(gcloud iam workload-identity-pools providers describe github-provider \
  --project="${GCP_PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="github" \
  --format="value(name)")

# Create terraform.tfvars
echo ""
echo "📝 Creating terraform.tfvars..."
cat > terraform/terraform.tfvars <<EOF
gcp_project_id = "$GCP_PROJECT_ID"
gcp_region     = "$GCP_REGION"
environment    = "production"
domain_name    = "whatwebuy.ai"
github_org     = "$GITHUB_ORG"

github_repos = {
  catalog_api  = "catalog-api"
  consumer_api = "consumer-api"
  webapp       = "consumer-webapp"
}
EOF

echo "✅ terraform.tfvars created"

# Summary
echo ""
echo "✨ Setup Complete!"
echo "=================="
echo ""
echo "Next steps:"
echo ""
echo "1. Add these secrets to your GitHub repository ($GITHUB_ORG/$REPO_NAME):"
echo "   Settings → Secrets and variables → Actions → New repository secret"
echo ""
echo "   GCP_PROJECT_ID:"
echo "   $GCP_PROJECT_ID"
echo ""
echo "   GCP_SERVICE_ACCOUNT:"
echo "   github-actions@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
echo ""
echo "   GCP_WORKLOAD_IDENTITY_PROVIDER:"
echo "   $WORKLOAD_IDENTITY_PROVIDER"
echo ""
echo "2. Initialize and apply Terraform:"
echo "   cd terraform"
echo "   terraform init"
echo "   terraform plan"
echo "   terraform apply"
echo ""
echo "3. After Terraform completes, get DNS records:"
echo "   terraform output dns_records"
echo ""
echo "4. Configure DNS in GoDaddy with the IP addresses from step 3"
echo ""
echo "5. Update secrets in Secret Manager:"
echo "   echo -n 'your-email@example.com' | gcloud secrets versions add migros-email --data-file=-"
echo "   echo -n 'your-password' | gcloud secrets versions add migros-password --data-file=-"
echo ""
