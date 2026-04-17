# NodeJS App

A deliberately vulnerable Node.js application used to demo [OWASP Dependency-Track](https://dependencytrack.org/)  an open-source platform for tracking and managing vulnerabilities in third-party dependencies.

## Prerequisites

- Node.js 18+
- Docker and Docker Compose
- Access to a running Dependency-Track instance

## Running Dependency-Track with Docker Compose

A `docker-compose.yml` is included to spin up the full Dependency-Track stack (API server, frontend, PostgreSQL).

```bash
docker compose up -d
```

This starts three containers:

![Running containers](images/image-01.png)

| Service | URL |
|---|---|
| Frontend | http://localhost:8080 |
| API Server | http://localhost:8081 |

Default credentials: `admin` / `admin` (you will be prompted to change on first login).

> On first startup the API server downloads the full NVD vulnerability database which can take 2 - 3 hours. Vulnerability results will appear once the sync completes.

### Enable fuzzy matching for vulnerability detection

By default, Dependency-Track's internal analyzer matches components using CPE identifiers. Since npm packages typically don't include CPE data in their SBOMs, we need to enable fuzzy matching so the analyzer can match components by name against the NVD database.

Run this once after the stack is up:

```bash
docker exec dependencytrack-postgres-1 psql -U dtrack -d dtrack -c "
UPDATE \"CONFIGPROPERTY\" SET \"PROPERTYVALUE\" = 'true'
WHERE \"GROUPNAME\" = 'scanner' AND \"PROPERTYNAME\" = 'internal.fuzzy.enabled';

UPDATE \"CONFIGPROPERTY\" SET \"PROPERTYVALUE\" = 'false'
WHERE \"GROUPNAME\" = 'scanner' AND \"PROPERTYNAME\" = 'internal.fuzzy.exclude.purl';
"
```

Then restart the API server to apply the change:

```bash
docker restart dependencytrack-apiserver-1
```

After restarting, re-upload the SBOM and vulnerabilities will appear in the dashboard.

## What this app does

A simple Express REST API with three endpoints:

| Endpoint | Method | Description |
|---|---|---|
| `/` | GET | Returns app name and version |
| `/users` | GET | Returns a sorted list of users |
| `/login` | POST | Accepts a username and returns a signed JWT token |

## Running the app

```bash
npm install
npm start
# Server runs on http://localhost:3000
```

## Running with Docker

```bash
docker build -t my-app .
docker run -p 3000:3000 my-app
```

The app will be available at http://localhost:3000.

## Vulnerable dependencies

The app intentionally uses outdated package versions with known CVEs to demonstrate Dependency-Track's detection capabilities.

| Package | Version | CVE | Severity | Description |
|---|---|---|---|---|
| `ejs` | 2.7.4 | CVE-2022-29078 | Critical | Server-side template injection leading to RCE |
| `minimist` | 1.2.5 | CVE-2021-44906 | Critical | Prototype pollution |
| `jsonwebtoken` | 8.5.1 | CVE-2022-23539 | High | Weak key type validation — auth bypass |
| `moment` | 2.29.1 | CVE-2022-24785 | High | Path traversal via locale input |
| `node-fetch` | 2.6.0 | CVE-2022-0235 | High | Exposure of sensitive headers on redirect |
| `serialize-javascript` | 2.1.1 | CVE-2020-7660 | High | XSS via regex serialization |
| `express` | 4.18.2 | Multiple | Medium | Transitive dependency vulnerabilities |

## Deployment

Dependency-Track is deployed on **AWS ECS Fargate** using the included `ecs-task-definition.json`. The task runs three containers (API server, frontend, Trivy) in a single task, with the API server connected to an RDS PostgreSQL database and an EFS volume for persistent data. Credentials are pulled from AWS Secrets Manager.

## Infrastructure with Terraform

The `terraform/` directory contains all infrastructure-as-code to deploy Dependency-Track on AWS. It provisions the following resources:

- **VPC**: public/private subnets, NAT Gateway, route tables
- **ECS Fargate**: cluster, task definition (API server, frontend, Trivy), service
- **RDS PostgreSQL 17**: in private subnets, encrypted, deletion-protected
- **EFS**: encrypted persistent storage for Dependency-Track data
- **ALB**: public-facing load balancer routing traffic to API server and frontend
- **ECR**: container image repositories with scan-on-push enabled
- **IAM** least-privilege execution and task roles
- **Secrets Manager** — stores DB credentials securely
- **CloudWatch** — log group for all ECS containers

```bash
cd terraform
terraform init
terraform plan \
  -var="db_username=dtrack" \
  -var="db_password=yourpass" \
  -var="apiserver_image=<ecr-url>" \
  -var="frontend_image=<ecr-url>" \
  -var="api_domain=http://your-alb-dns"
terraform apply
```

## CI/CD Pipelines

Two pipeline files are included to automate SBOM generation and upload on every push to `main`: `.github/workflows/sbom.yml` for GitHub Actions and `azure-pipelines.yml` for Azure DevOps. Both require `DT_URL` and `API_KEY` to be set as secrets/variables in your pipeline settings.

### Secret Scanning - Gitleaks

The Azure DevOps pipeline includes a `SecretScan` stage powered by [Gitleaks](https://github.com/gitleaks/gitleaks), an open-source tool that detects hardcoded secrets, API keys, tokens, and credentials committed to source code.

The stage runs in parallel with the Docker build (it only needs the source tree) and blocks the image from being pushed to ECR if any secrets are found.

```yaml
docker run --rm \
  -v $(Build.SourcesDirectory):/path \
  ghcr.io/gitleaks/gitleaks:latest \
  detect --source /path --no-git \
  --report-format junit --report-path gitleaks-results.xml \
  --exit-code 1
```

| Flag | Purpose |
|---|---|
| `--no-git` | Scans file contents directly - works with any clone depth |
| `--exit-code 1` | Fails the pipeline immediately on any finding |
| `--report-format junit` | Publishes results to the Azure DevOps Tests tab |

Findings appear in the pipeline's **Tests** tab with the full file path, line number, matched rule, and the type of secret detected (e.g. AWS key, generic API token, private key).

## Example SBOM

A pre-generated `bom.json` is included in the repo so you can upload it directly to Dependency-Track without running cdxgen yourself.

## Generating and uploading the SBOM


### Step 1: Install cdxgen

[cdxgen](https://github.com/CycloneDX/cdxgen) is an open-source tool that scans your project and generates a CycloneDX SBOM.

```bash
npm install -g @cyclonedx/cdxgen
```

Or use it without installing via npx:

```bash
npx @cyclonedx/cdxgen --help
```

### Step 2: Generate the SBOM

Run this from the root of the project after `npm install`:

```bash
npx @cyclonedx/cdxgen -o bom.json --spec-version 1.4 .
```

This produces a `bom.json` file listing all dependencies and their metadata (name, version, PURL, hashes, licenses).

### Step 3: Upload to Dependency-Track

Get an   API key from: **Dependency-Track UI → Administration → Access Management → Teams → Automation → API Key**

Then upload:

```bash
curl -X POST "http://localhost:8081/api/v1/bom" \
  -H "X-Api-Key: API_KEY" \
  -F "autoCreate=false" \
  -F "projectName=my-app" \
  -F "projectVersion=1.0.0" \
  -F "bom=@bom.json"
```

A successful response returns a token:
```json
{"token":"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"}
```

Dependency-Track will then analyze all components against its vulnerability databases (NVD, OSV, Trivy) and populate the project dashboard with findings.

---