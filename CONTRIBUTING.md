# Contributing to Infrastructure

## Development Workflow

### Making Changes

1. **Create a branch**
   ```bash
   git checkout -b feature/my-infrastructure-change
   ```

2. **Make changes to Terraform files**
   ```bash
   cd terraform
   # Edit .tf files
   ```

3. **Format and validate**
   ```bash
   terraform fmt -recursive
   terraform validate
   ```

4. **Test locally**
   ```bash
   terraform plan
   ```

5. **Commit and push**
   ```bash
   git add .
   git commit -m "feat: add new Cloud Run service"
   git push origin feature/my-infrastructure-change
   ```

6. **Create Pull Request**
   - GitHub Actions will automatically run `terraform plan`
   - Review the plan in PR comments
   - Request review from team members

7. **Merge to main**
   - Once approved, merge PR
   - GitHub Actions will automatically run `terraform apply`
   - Monitor deployment in GitHub Actions logs

## Commit Message Format

Follow conventional commits:

- `feat:` - New infrastructure feature
- `fix:` - Bug fix in infrastructure
- `docs:` - Documentation changes
- `chore:` - Maintenance tasks
- `refactor:` - Code restructuring

Examples:
```
feat: add Cloud SQL database for production
fix: correct IAM permissions for enrich service
docs: update setup instructions with new secrets
chore: upgrade Terraform provider to v5.1
refactor: reorganize modules by service
```

## Terraform Best Practices

### File Organization

```
terraform/
├── main.tf              # Provider and backend config
├── variables.tf         # Input variables
├── outputs.tf           # Output values
├── firestore.tf         # Firestore resources
├── storage.tf           # Cloud Storage resources
├── cloud-run.tf         # Cloud Run services
├── secrets.tf           # Secret Manager
├── dns-ssl.tf           # Domain and SSL
├── service-accounts.tf  # IAM service accounts
└── modules/             # Reusable modules (future)
```

### Naming Conventions

- **Resources**: `resource_type_purpose` (e.g., `google_cloud_run_v2_service.catalog_products`)
- **Variables**: `snake_case` (e.g., `gcp_project_id`)
- **Outputs**: `snake_case` (e.g., `firestore_database_name`)
- **Labels**: `kebab-case` (e.g., `managed-by: terraform`)

### Code Style

- Use 2 spaces for indentation
- Run `terraform fmt` before committing
- Add comments for complex logic
- Group related resources together
- Use `depends_on` sparingly (Terraform infers dependencies)

### Variables

- Provide sensible defaults when possible
- Add descriptions to all variables
- Use validation blocks for critical variables
- Mark sensitive variables as `sensitive = true`

### Outputs

- Output important resource IDs and URLs
- Add descriptions to all outputs
- Group related outputs in objects
- Use `sensitive = true` for secrets

## Testing Changes

### Local Testing

```bash
cd terraform

# Initialize (if needed)
terraform init

# Validate syntax
terraform validate

# Check formatting
terraform fmt -check

# See what will change
terraform plan

# Apply to a test environment (if available)
terraform workspace select staging
terraform apply
```

### Pre-commit Checks

Before pushing:
- [ ] `terraform fmt` runs without changes
- [ ] `terraform validate` passes
- [ ] `terraform plan` shows expected changes
- [ ] No sensitive data in code
- [ ] Documentation updated if needed

## Security Guidelines

### Never Commit
- API keys or passwords
- Service account keys
- terraform.tfvars with real values
- .terraform directories
- *.tfstate files

### Always Do
- Use Secret Manager for credentials
- Follow least-privilege for IAM
- Enable audit logging
- Use VPC when possible
- Enable encryption at rest
- Validate all inputs

## Adding New Services

When adding a new Cloud Run service:

1. **Add service account** in `service-accounts.tf`:
   ```hcl
   resource "google_service_account" "new_service" {
     account_id   = "new-service-sa"
     display_name = "New Service Account"
   }
   ```

2. **Add Cloud Run service** in `cloud-run.tf`:
   ```hcl
   resource "google_cloud_run_v2_service" "new_service" {
     name     = "new-service"
     location = var.gcp_region
     # ... configuration
   }
   ```

3. **Add IAM permissions** as needed

4. **Update outputs** in `outputs.tf`:
   ```hcl
   output "cloud_run_services" {
     value = {
       # ... existing services
       new_service = google_cloud_run_v2_service.new_service.uri
     }
   }
   ```

5. **Update documentation** in README.md and ARCHITECTURE.md

## Updating Dependencies

### Terraform Provider Updates

```bash
cd terraform

# Show current version
terraform version

# Update provider version in main.tf
# required_providers {
#   google = {
#     version = "~> 5.1"
#   }
# }

# Re-initialize
terraform init -upgrade

# Test
terraform plan
```

### API Version Updates

When updating GCP API versions:
1. Check breaking changes in provider changelog
2. Update resources gradually
3. Test thoroughly in staging
4. Document migration steps

## Troubleshooting

### Common Issues

**State Locked**
```bash
# If state is locked from failed apply
terraform force-unlock LOCK_ID
```

**Provider Version Mismatch**
```bash
terraform init -upgrade
```

**Plan Shows Unexpected Changes**
```bash
# Import existing resource
terraform import google_cloud_run_v2_service.my_service projects/PROJECT/locations/REGION/services/NAME
```

**Permission Denied**
```bash
# Check service account permissions
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:SA_EMAIL"
```

## Getting Help

- **Documentation**: See README.md and ARCHITECTURE.md
- **Terraform Docs**: https://registry.terraform.io/providers/hashicorp/google
- **GCP Docs**: https://cloud.google.com/docs
- **Issues**: Create GitHub issue with `[infrastructure]` tag

## Review Checklist

Before requesting review:

- [ ] Terraform format and validate pass
- [ ] Plan output reviewed and understood
- [ ] No sensitive data in code
- [ ] Documentation updated
- [ ] Commit messages follow convention
- [ ] Breaking changes documented
- [ ] Tested locally (if possible)
- [ ] PR description explains changes
