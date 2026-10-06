# Session 16 - CI/CD & GitHub Actions

## Student Details

- **Name:** Srujan Gowda KS
- **Roll Number:** 24BCS10339
- **Session:** Session 16 - CI/CD & GitHub Actions

---

## Assignment Deliverables Summary

| Deliverable | Description | File Location | Status |
|---|---|---|---|
| **Application Source Code** | Python Calculator app implementing arithmetic operations | `10-final-cicd-pipeline/app/calculator.py` | **Completed** |
| **Unit Test Suite** | Automated Pytest test suite covering edge cases and exceptions | `10-final-cicd-pipeline/tests/test_calculator.py` | **Completed** |
| **Packaging & Build Script** | Shell automation script generating build artifacts and build metadata | `10-final-cicd-pipeline/build.sh` | **Completed** |
| **Dockerfile** | Lightweight production container definition based on Python 3.12-slim | `10-final-cicd-pipeline/Dockerfile` | **Completed** |
| **GitHub Actions Workflow** | 4-stage pipeline (Test, Security, Build, Docker/CD) with triggers and dependencies | `10-final-cicd-pipeline/.github/workflows/ci.yml` | **Completed** |
| **CI Pipeline** | Automated checkout, Python setup, dependency install, testing, and secret audit | Workflow Jobs: `test`, `security-check`, `build` | **Completed** |
| **CD Pipeline Stage** | Container build & deployment readiness validation | Workflow Job: `docker-build` | **Completed** |
| **Project Documentation** | Technical documentation detailing CI/CD concepts and execution | `10-final-cicd-pipeline/README.md` | **Completed** |
| **Execution Screenshots** | Visual proof of GitHub Actions execution, jobs graph, logs, and artifacts | `screenshot/` | **Captured** |

---

<br>

# 1. Project Overview & Architecture

The goal of this assignment is to build and demonstrate a complete, production-grade Continuous Integration and Continuous Delivery (CI/CD) pipeline using **GitHub Actions**.

### Pipeline Architecture & Dependency Graph

```text
               ┌───────────────────────┐
               │  git push / PR /      │
               │  workflow_dispatch    │
               └───────────┬───────────┘
                           │
                           ▼
                ┌─────────────────────┐
                │   Test Application  │
                │  (pytest unit tests)│
                └──────────┬──────────┘
                           │
             ┌─────────────┴─────────────┐
             │                           │
             ▼                           ▼
  ┌───────────────────────┐   ┌───────────────────────┐
  │  Security & Secret    │   │    Build & Artifact   │
  │  (Credentials Scan)   │   │  (build.sh & archive) │
  └──────────┬────────────┘   └───────────────────────┘
             │
             ▼
  ┌───────────────────────┐
  │     Docker Build      │
  │ (CD Deployment Ready) │
  └───────────────────────┘
```

---

<br>

# 2. Key CI/CD & GitHub Actions Concepts

### CI vs CD
- **Continuous Integration (CI)**: Automates the building and testing of code every time a team member commits changes to version control. This ensures bugs, regressions, and syntax errors are caught within minutes.
- **Continuous Delivery (CD)**: Automates the packaging and preparation of deployable release candidates (e.g., container images, build binaries). A human or trigger can approve deployment at any time.
- **Continuous Deployment (CD)**: Automatically deploys passing changes directly to production environments with zero manual gates.

### GitHub Actions Components
- **Workflow**: A configurable automated process defined in YAML under `.github/workflows/`.
- **Jobs**: Sets of steps executing on a runner. Jobs run in parallel by default, but sequential pipelines are enforced using `needs: [job_name]`.
- **Steps**: Individual tasks executing either inline commands (`run:`) or reusable modules (`uses:`).
- **Runners**: Compute environments managed by GitHub (`runs-on: ubuntu-latest`).
- **Secrets**: Encrypted credentials configured in GitHub repository settings and injected safely via `${{ secrets.SECRET_NAME }}`.
- **Artifacts**: Persisted outputs produced by a workflow run, uploaded via `actions/upload-artifact@v4`.

---

<br>

# 3. Pipeline Implementation

### Workflow Definition (`.github/workflows/ci.yml`)

```yaml
name: Final CI/CD Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

jobs:
  test:
    name: Test Application
    runs-on: ubuntu-latest
    steps:
      - name: Checkout source code
        uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements.txt

      - name: Run unit tests
        run: pytest -v

  security-check:
    name: Security & Secret Check
    runs-on: ubuntu-latest
    steps:
      - name: Checkout source code
        uses: actions/checkout@v4

      - name: Check for sensitive files
        run: |
          echo "Checking for sensitive files..."
          if find . -type f \( -name ".env" -o -name "*.pem" -o -name "*.key" \) | grep -q .; then
            echo "Sensitive files detected"
            exit 1
          else
            echo "No sensitive files detected"
          fi

      - name: Verify repository secret
        env:
          DEMO_SECRET: ${{ secrets.DEMO_SECRET }}
        run: |
          if [ -n "$DEMO_SECRET" ]; then
            echo "Repository secret DEMO_SECRET is configured."
          else
            echo "Repository secret DEMO_SECRET is not configured (optional demo check)."
          fi

  build:
    name: Build & Artifact
    needs: test
    runs-on: ubuntu-latest
    steps:
      - name: Checkout source code
        uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Build application
        run: |
          chmod +x build.sh
          ./build.sh

      - name: Upload build artifact
        uses: actions/upload-artifact@v4
        with:
          name: application-build
          path: build/

  docker-build:
    name: Docker Build (CD Preparation)
    needs: [test, security-check]
    runs-on: ubuntu-latest
    steps:
      - name: Checkout source code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build Docker image
        run: |
          docker build -t application:latest .
          echo "Docker image built successfully."
```

---

<br>

# 4. Pipeline Execution & Verification

### Output & Verification Screenshots

#### 1. Workflow Execution Overview
![Workflow Run](screenshot/01-github-actions-workflow-run.png)
*Displays the successful pipeline execution triggered on push to main.*

#### 2. Pipeline Dependency & Jobs Graph
![Pipeline Jobs Graph](screenshot/02-pipeline-jobs-graph.png)
*Displays all 4 jobs (`test`, `security-check`, `build`, and `docker-build`) completing successfully.*

#### 3. Automated Unit Testing Logs (`pytest`)
![Pytest Logs](screenshot/03-test-job-logs.png)
*Shows all 5 test cases passing under Python 3.12.*

#### 4. Uploaded Build Artifacts
![Uploaded Artifacts](screenshot/04-uploaded-artifacts.png)
*Shows the `application-build` zip artifact generated and available for download.*

---

<br>

# 5. Project Directory Structure

```text
10-final-cicd-pipeline/
├── .github/
│   └── workflows/
│       └── ci.yml               # Complete GitHub Actions workflow
├── app/
│   ├── __init__.py
│   └── calculator.py            # Application source code
├── tests/
│   ├── __init__.py
│   └── test_calculator.py       # Automated test suite
├── .gitignore                   # Excludes caches, venv, and build artifacts
├── build.sh                     # Build packaging script
├── Dockerfile                   # Container definition
├── README.md                    # Technical documentation
└── requirements.txt             # Project dependencies
```
