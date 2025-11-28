# GoDaddy DNS Automation with Terraform

This Terraform configuration automatically manages DNS records for `whatwebuy.ai` using the GoDaddy API.

## Overview

The following DNS records are automatically configured:
- `api.whatwebuy.ai` → Points to API Load Balancer (`34.107.183.172`)
- `app.whatwebuy.ai` → Points to Webapp Load Balancer (`34.149.176.49`)
- `whatwebuy.ai` (root) → Points to Webapp Load Balancer (`34.149.176.49`)

## Prerequisites

1. Domain `whatwebuy.ai` registered with GoDaddy
2. GoDaddy API credentials (Production keys)
3. GitHub repository secrets configured

## Setup Instructions

### 1. Obtain GoDaddy API Credentials

1. Go to [GoDaddy Developer Portal](https://developer.godaddy.com/keys)
2. Sign in with your GoDaddy account
3. Click **"Create New API Key"**
4. Select **"Production"** environment (not OTE/Test)
5. Name it something like `whatwebuy-terraform`
6. Copy the **Key** and **Secret** immediately (you won't be able to see the secret again)

### 2. Add GitHub Secrets

Add the following secrets to your GitHub repository:

**Repository Settings → Secrets and variables → Actions → New repository secret**

| Secret Name | Value |
|-------------|-------|
| `GODADDY_API_KEY` | Your GoDaddy API Key |
| `GODADDY_API_SECRET` | Your GoDaddy API Secret |

### 3. How It Works

When you push changes to the `terraform/` directory:

1. **Pull Request**: GitHub Actions runs `terraform plan` and posts the plan as a comment
2. **Merge to main**: GitHub Actions runs `terraform apply` automatically
3. DNS records are created/updated via GoDaddy API
4. Google Cloud SSL certificates will provision automatically once DNS propagates

### 4. DNS Propagation & SSL Certificate Status

After Terraform applies the DNS changes:

- **DNS Propagation**: 5-10 minutes (TTL is 600 seconds)
- **SSL Certificate Provisioning**: 15-60 minutes after DNS propagates
- **Certificate Status**: Check with `gcloud compute ssl-certificates describe whatwebuy-api-ssl`

Expected certificate status progression:
1. `PROVISIONING` with `FAILED_NOT_VISIBLE` → DNS not propagated yet
2. `PROVISIONING` with `PROVISIONING_DOMAIN` → Google is verifying domain ownership
3. `ACTIVE` → Certificate ready, HTTPS working

### 5. Verify DNS Records

```bash
# Check if DNS records are propagating
dig api.whatwebuy.ai +short
dig app.whatwebuy.ai +short
dig whatwebuy.ai +short

# Check SSL certificate status
gcloud compute ssl-certificates list
gcloud compute ssl-certificates describe whatwebuy-api-ssl --format="yaml"
gcloud compute ssl-certificates describe whatwebuy-webapp-ssl --format="yaml"
```

### 6. Test HTTPS Endpoints

Once SSL certificates are `ACTIVE`:

```bash
# Test API endpoint
curl https://api.whatwebuy.ai/health

# Test Webapp endpoint
curl https://app.whatwebuy.ai
curl https://whatwebuy.ai
```

## Terraform Resources

This configuration creates:

- **GoDaddy DNS Records**: 3 A records (api, app, root)
- **Google Global IPs**: 2 static IPs (api, webapp)
- **SSL Certificates**: 2 managed certificates (api, webapp)
- **Load Balancers**: 2 HTTPS load balancers with HTTP→HTTPS redirect
- **Backend Services**: NEGs pointing to Cloud Run services

## Troubleshooting

### DNS Not Updating

1. Check if GoDaddy credentials are correct in GitHub secrets
2. View GitHub Actions logs for errors
3. Manually verify in GoDaddy DNS console

### SSL Certificate Stuck in PROVISIONING

1. Wait 15-60 minutes for DNS to fully propagate globally
2. Check DNS with `dig @8.8.8.8 api.whatwebuy.ai` (Google DNS)
3. Verify A records point to correct IPs (see outputs above)

### Certificate Status: FAILED_NOT_VISIBLE

This means DNS records aren't visible yet:
- DNS hasn't propagated globally (wait 10-30 minutes)
- DNS records are incorrect (verify with `dig`)
- Firewall/proxy blocking Google's validation (unlikely)

## Manual DNS Configuration (Fallback)

If automatic configuration fails, manually add these records in GoDaddy:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | api | 34.107.183.172 | 600 |
| A | app | 34.149.176.49 | 600 |
| A | @ | 34.149.176.49 | 600 |

## Security Notes

- API credentials are stored as GitHub secrets (encrypted)
- Secrets are passed as environment variables (`TF_VAR_*`) to Terraform
- Never commit `terraform.tfvars` with real credentials
- GoDaddy API keys should be Production keys with minimal permissions

## References

- [GoDaddy Terraform Provider](https://registry.terraform.io/providers/n3integration/godaddy/latest/docs)
- [Google Managed SSL Certificates](https://cloud.google.com/load-balancing/docs/ssl-certificates/google-managed-certs)
- [Terraform GitHub Actions](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions)
