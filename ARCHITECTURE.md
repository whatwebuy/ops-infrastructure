# WhatWeBuy Platform Architecture

## Overview

WhatWeBuy is a consumer purchase analytics platform that enriches Migros shopping receipts with product catalog information and provides insights through a web interface.

## System Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                         User Layer                              │
├────────────────────────────────────────────────────────────────┤
│  Browser → app.whatwebuy.ai (React SPA)                        │
│  API Clients → api.whatwebuy.ai (REST APIs)                    │
└──────────────────────┬─────────────────────────────────────────┘
                       │
                       │ HTTPS (SSL/TLS)
                       │
┌──────────────────────┴─────────────────────────────────────────┐
│              Google Cloud Load Balancer                         │
│  • Global IP addresses                                          │
│  • SSL termination                                              │
│  • HTTP → HTTPS redirect                                        │
│  • CDN for static assets                                        │
└──────────────────────┬─────────────────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │                             │
        ▼                             ▼
┌────────────────┐          ┌──────────────────┐
│   API Gateway  │          │     Webapp       │
│ api.whatwebuy  │          │ app.whatwebuy    │
└────────┬───────┘          └────────┬─────────┘
         │                           │
         │                           │
         ▼                           ▼
┌────────────────────────────────────────────────────────────────┐
│                  Cloud Run Services (Containers)                │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ Catalog API (catalog-api repo)                           │ │
│  ├──────────────────────────────────────────────────────────┤ │
│  │ • catalog-products (Port 3001)                           │ │
│  │   - GET/POST/DELETE /products                            │ │
│  │   - Product catalog management                           │ │
│  │   - Integration with categories API                      │ │
│  │                                                           │ │
│  │ • catalog-categories (Port 3002)                         │ │
│  │   - GET/POST/DELETE /categories                          │ │
│  │   - Category hierarchy management                        │ │
│  │   - Multi-language support (DE/EN)                       │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ Consumer API (consumer-api repo)                         │ │
│  ├──────────────────────────────────────────────────────────┤ │
│  │ • consumer-transactions (Port 3003)                      │ │
│  │   - GET/POST /transactions                               │ │
│  │   - Transaction storage & analytics                      │ │
│  │   - Aggregations (daily, monthly, category)              │ │
│  │   - Integration with catalog APIs                        │ │
│  │                                                           │ │
│  │ • consumer-enrich (Port 3004)                            │ │
│  │   - POST /enrich (trigger enrichment)                    │ │
│  │   - Puppeteer web scraping                               │ │
│  │   - PDF/CSV parsing                                      │ │
│  │   - Migros integration                                   │ │
│  │   - Catalog building                                     │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ Webapp (consumer-webapp repo)                            │ │
│  ├──────────────────────────────────────────────────────────┤ │
│  │ • React 18 + TypeScript                                  │ │
│  │ • TanStack Router                                        │ │
│  │ • Jotai state management                                 │ │
│  │ • Tailwind CSS                                           │ │
│  │ • Dashboard & Transaction views                          │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                 │
└──────────────────┬──────────────┬──────────────┬───────────────┘
                   │              │              │
                   ▼              ▼              ▼
        ┌──────────────┐  ┌─────────────┐  ┌──────────────┐
        │   Firestore  │  │   Cloud     │  │   Secret     │
        │   Database   │  │   Storage   │  │   Manager    │
        └──────────────┘  └─────────────┘  └──────────────┘
```

## Data Flow

### 1. Enrichment Pipeline Flow

```
User triggers enrichment (POST /enrich)
    ↓
consumer-enrich service
    ↓
┌───────────────────────────────────────┐
│ 1. Authenticate to Migros account     │
│ 2. Download CSV receipts              │
│ 3. Download PDF receipts              │
│ 4. Parse CSV for transactions         │
│ 5. Parse PDF for payment details      │
│ 6. Scrape product pages (Puppeteer)   │
│ 7. Extract product metadata           │
│ 8. Match products to categories       │
└─────────────┬─────────────────────────┘
              │
              ├─→ POST /categories → catalog-categories
              │   (Store discovered categories)
              │
              ├─→ POST /products → catalog-products
              │   (Store enriched products)
              │
              ├─→ POST /transactions → consumer-transactions
              │   (Store enriched transactions)
              │
              └─→ Upload files to Cloud Storage
                  (Store CSV/PDF originals)
```

### 2. Query Flow

```
User views dashboard (app.whatwebuy.ai)
    ↓
React SPA loads
    ↓
GET api.whatwebuy.ai/transactions
    ↓
consumer-transactions service
    ↓
┌───────────────────────────────────────┐
│ 1. Query Firestore for transactions   │
│ 2. Enrich with product details        │
│    (GET /products/:id)                │
│ 3. Enrich with category details       │
│    (GET /categories/:id)              │
│ 4. Calculate aggregations             │
│ 5. Return enriched data               │
└───────────────────────────────────────┘
    ↓
Render in React components
```

## Component Details

### Catalog Services

#### catalog-products
- **Purpose**: Manage product catalog
- **Storage**: Firestore collection `products`
- **Key Features**:
  - Product CRUD operations
  - Search and filtering by category, brand, name
  - Pagination support
  - Category name enrichment via categories API

#### catalog-categories
- **Purpose**: Manage category hierarchy
- **Storage**: Firestore collection `categories`
- **Key Features**:
  - Category CRUD operations
  - Multi-language support (German/English)
  - Hierarchical structure support
  - Search by name

### Consumer Services

#### consumer-transactions
- **Purpose**: Transaction storage and analytics
- **Storage**: Firestore collection `transactions`
- **Key Features**:
  - Transaction CRUD operations
  - Advanced filtering (date range, store, product)
  - Aggregations (daily, monthly, by category)
  - Skip logic for deduplication
  - Product matching and enrichment

#### consumer-enrich
- **Purpose**: Receipt enrichment pipeline
- **Storage**: Cloud Storage bucket for files, Firestore for data
- **Key Features**:
  - Migros authentication (credentials in Secret Manager)
  - CSV/PDF download and parsing
  - Web scraping with Puppeteer
  - Product discovery and catalog building
  - Category fuzzy matching
  - Incremental processing
  - Error handling and retry logic

### Frontend

#### consumer-webapp
- **Purpose**: User interface for viewing transactions
- **Technology**: React 18, TypeScript, Vite
- **Key Features**:
  - Dashboard with spending statistics
  - Transaction list with filters
  - Transaction detail view with product images
  - Grouping by categories
  - Responsive design with Tailwind CSS

## Infrastructure Components

### Firestore Database
- **Type**: Native mode (not Datastore mode)
- **Location**: europe-west6
- **Collections**:
  - `transactions`: Enriched transaction data
  - `products`: Product catalog
  - `categories`: Category hierarchy
- **Indexes**: Optimized for common query patterns

### Cloud Storage
- **Bucket**: `{project-id}-whatwebuy-files`
- **Structure**:
  - `/receipts/csv/`: CSV receipt files
  - `/receipts/pdf/`: PDF receipt files
  - `/exports/`: Generated exports
- **Lifecycle**:
  - 30 days: Move to Nearline storage
  - 90 days: Delete
- **Versioning**: Enabled

### Secret Manager
- **Secrets**:
  - `migros-email`: Migros account email
  - `migros-password`: Migros account password
  - `database-url`: Database connection string
  - `api-keys`: External API keys (JSON)
- **Access**: Service accounts have least-privilege access

### Cloud Run
- **Configuration**:
  - Auto-scaling: 0 to 10 instances (enrich: 0-5)
  - CPU: 1 core (enrich: 2 cores)
  - Memory: 512Mi (enrich: 2Gi)
  - Timeout: 30s (enrich: 3600s)
  - Scale to zero when idle

### Load Balancer & SSL
- **Global Load Balancer**: HTTPS termination
- **SSL Certificates**: Google-managed certificates
- **Domains**:
  - `api.whatwebuy.ai` → consumer-transactions
  - `app.whatwebuy.ai` → consumer-webapp
  - `whatwebuy.ai` → consumer-webapp
- **CDN**: Enabled for webapp (static assets)

## Security

### Authentication & Authorization
- **Service-to-Service**: Service accounts with IAM roles
- **Public Access**: Webapp and API endpoints (behind load balancer)
- **Secret Access**: Only authorized services can access secrets

### Network Security
- **HTTPS Only**: HTTP redirects to HTTPS
- **SSL/TLS**: Google-managed certificates
- **VPC**: Services communicate within GCP network
- **IAM**: Least-privilege principle

### Data Security
- **Encryption at Rest**: Firestore and Cloud Storage encrypted
- **Encryption in Transit**: TLS 1.2+
- **Secret Management**: Credentials never in code/config
- **Backup**: Firestore continuous backup

## Scalability

### Auto-Scaling
- **Cloud Run**: Scales based on request load
- **Firestore**: Automatic scaling
- **Load Balancer**: Global distribution

### Performance
- **CDN**: Static assets cached globally
- **Firestore Indexes**: Optimized queries
- **Cloud Run**: Cold start < 3s
- **Regional Deployment**: europe-west6 (Zurich)

## Cost Optimization

### Pay-per-Use
- **Cloud Run**: Billed per request (scales to zero)
- **Firestore**: Billed per operation
- **Cloud Storage**: Lifecycle policies reduce costs
- **Load Balancer**: Minimal cost for low traffic

### Estimated Monthly Cost (Low Traffic)
- Cloud Run: $5-10
- Firestore: $5-15
- Cloud Storage: $1-5
- Load Balancer: $5-10
- **Total**: $16-40/month

## Monitoring & Observability

### Logging
- **Cloud Logging**: All services send logs
- **Structured Logs**: JSON format with correlation IDs
- **Log Retention**: 30 days default

### Metrics
- **Cloud Monitoring**: Request count, latency, errors
- **Custom Metrics**: Business metrics (transactions/day)
- **Dashboards**: Pre-built for Cloud Run services

### Alerting
- **Error Rate**: Alert if > 5%
- **Latency**: Alert if p99 > 1s
- **Budget**: Alert if cost > threshold

## Deployment

### CI/CD Pipeline
- **GitHub Actions**: Automated builds and deploys
- **Terraform**: Infrastructure as Code
- **Docker**: Containerized services
- **Artifact Registry**: Store container images

### Workflow
1. **PR Created**: Terraform plan generated
2. **PR Merged**: Terraform apply automatically
3. **Image Built**: GitHub Actions builds Docker image
4. **Deploy**: Push to Artifact Registry, Cloud Run pulls

### Environments
- **Production**: Main branch, live traffic
- **Staging**: (Future) Separate GCP project
- **Local**: Docker Compose for development

## Disaster Recovery

### Backup Strategy
- **Firestore**: Continuous backup, 7-day point-in-time recovery
- **Cloud Storage**: Versioning enabled
- **Terraform State**: Versioned in GCS bucket

### Recovery Plan
1. **Data Loss**: Restore from Firestore backup
2. **Service Failure**: Cloud Run auto-restarts, multi-zone
3. **Infrastructure Loss**: Terraform recreates everything
4. **Secret Loss**: Rotate and update in Secret Manager

## Future Enhancements

### Planned Features
- [ ] Multi-user support with authentication
- [ ] Real-time notifications (Cloud Pub/Sub)
- [ ] Advanced analytics (BigQuery)
- [ ] Mobile app (React Native)
- [ ] Additional retailers (Coop, Aldi, etc.)
- [ ] Budget tracking and alerts
- [ ] Export to CSV/PDF
- [ ] Scheduled enrichment jobs (Cloud Scheduler)

### Infrastructure Improvements
- [ ] Multi-region deployment
- [ ] Staging environment
- [ ] Advanced monitoring (Datadog/New Relic)
- [ ] API rate limiting
- [ ] Cloud Armor (DDoS protection)
- [ ] Cloud CDN optimization
