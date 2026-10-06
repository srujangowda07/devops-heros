# CI/CD Demo Project with GitHub Actions

## 1. Objective

The primary objective of this project is to build and demonstrate an end-to-end Continuous Integration and Continuous Delivery (CI/CD) pipeline using **GitHub Actions**. The pipeline automatically validates, tests, secures, builds, packages, and containerizes a software application on every code commit and pull request.

---

## 2. Application Overview

The project features a lightweight Python application (`app/calculator.py`) that implements fundamental mathematical operations (`add`, `subtract`, `multiply`, `divide`). A dedicated unit test suite (`tests/test_calculator.py`) validates correctness and edge-case handling (e.g., zero-division exceptions). The simplicity of the application ensures that the primary focus remains entirely on CI/CD engineering, workflow orchestration, and deployment automation.

---

## 3. CI vs CD

Modern software delivery relies on two complementary practices:

```text
[ Developer Push ]
       │
       ▼
 ┌───────────┐     Continuous Integration (CI)
 │   Build   │  ── Automatically compiles code, installs dependencies,
 ├───────────┤     and executes test suites on every push to detect defects early.
 │   Test    │
 └─────┬─────┘
       │
       ▼
 ┌───────────┐     Continuous Delivery (CD)
 │  Package  │  ── Automatically packages software into deployable units
 ├───────────┤     (e.g., Docker images, artifacts) ready for immediate deployment.
 │  Deploy   │
 └───────────┘
```

- **Continuous Integration (CI)**: The automated process where code changes from multiple developers are regularly integrated into a shared repository, followed by automated builds and automated tests to catch integration errors as early as possible.
- **Continuous Delivery (CD)**: An extension of CI where code changes that pass all tests are automatically packaged, containerized, and staged, ensuring that the application can be released to any environment at any time with a single trigger.
- **Continuous Deployment (CD)**: An advanced state of Continuous Delivery where every change that passes all pipeline stages is automatically pushed to live production without manual intervention.

---

## 4. GitHub Actions

**GitHub Actions** is a cloud-native automation and CI/CD platform built directly into GitHub. It enables developers to define automation workflows that trigger on any GitHub repository event (e.g., `push`, `pull_request`, release creation, or manual triggers). Workflows are defined entirely as version-controlled YAML files residing within `.github/workflows/`.

---

## 5. Workflow

A **Workflow** is an automated, configurable process comprising one or more jobs. Workflows are defined in YAML and stored in `.github/workflows/ci.yml`.

### Workflow Triggers
This pipeline triggers on three events:
- `push: branches: [main]`: Executes automatically whenever code is merged or pushed directly to the `main` branch.
- `pull_request: branches: [main]`: Executes on incoming pull requests targeting `main`, preventing faulty code from being merged.
- `workflow_dispatch`: Enables manual triggering directly from the GitHub Actions web interface for on-demand execution.

---

## 6. Jobs

A **Job** is a collection of sequential steps that execute on the same runner environment. By default, jobs run in parallel unless explicit dependencies are established using the `needs` keyword.

Our pipeline defines 4 distinct jobs:
1. `test`: Runs unit tests using `pytest` to validate application correctness.
2. `security-check`: Audits repository files for leaked secrets and verifies secure credentials.
3. `build`: Executes `build.sh` to produce deployable artifacts (`needs: test`).
4. `docker-build`: Builds a production-ready container image (`needs: [test, security-check]`).

### Dependency Flow (`needs`)
```text
      ┌─────────┐
      │  test   │
      └──┬───┬──┘
         │   │
   ┌─────┘   └─────┐
   ▼               ▼
┌────────┐   ┌────────────────┐
│ build  │   │ security-check │
└────────┘   └───────┬────────┘
                     │
                     ▼
             ┌──────────────┐
             │ docker-build │
             └──────────────┘
```

---

## 7. Steps

A **Step** is an individual task within a job. Steps execute sequentially on the runner. Steps can either:
- **Execute shell commands** via the `run` directive (e.g., `pytest -v`, `./build.sh`).
- **Execute reusable Actions** via the `uses` directive (e.g., `actions/checkout@v4`, `actions/setup-python@v5`).

---

## 8. Runners

A **Runner** is the compute server that executes the jobs defined in the workflow:
- **GitHub-Hosted Runners**: Managed virtual machines provided on-demand by GitHub. Our workflow utilizes `runs-on: ubuntu-latest`, providing a fresh, isolated Ubuntu Linux environment for each job run.
- **Self-Hosted Runners**: Dedicated servers managed by your organization when custom hardware, operating systems, or internal network access is required.

---

## 9. Secrets

In automated pipelines, credentials, tokens, and sensitive keys must never be committed to source code.

- **GitHub Repository Secrets**: Stored encrypted in GitHub under **Settings** $\rightarrow$ **Secrets and variables** $\rightarrow$ **Actions**.
- **Secure Secret Access**: Secrets are injected securely into runner environment variables using expression syntax:
  ```yaml
  env:
    DEMO_SECRET: ${{ secrets.DEMO_SECRET }}
  ```
- **Masking & Safety**: GitHub Actions automatically masks secret values from execution logs, preventing credential exposure during job execution.

---

## 10. Build Stage

The **Build stage** compiles or packages the application into a distribution-ready state:
- Executed by `build.sh`.
- Creates a clean `build/` directory containing the application code and an automated build metadata stamp (`build-info.txt`) with application name, status, and build timestamp.
- Ensures reproducible, deterministic packaging across environments.

---

## 11. Test Stage

The **Test stage** verifies that the application code satisfies functional specifications:
- Uses `pytest` to execute all unit test cases in `tests/test_calculator.py`.
- Tests basic operations (`add`, `subtract`, `multiply`, `divide`) and validates exception handling (`ZeroDivisionError`).
- **Gatekeeping Role**: If any test fails, the job exits with a non-zero exit code (`exit 1`), halting downstream packaging and deployment immediately.

---

## 12. Artifacts

**Artifacts** are files or directories produced during a workflow run that persist after the runner VM is destroyed:
- Uploaded using the official `actions/upload-artifact@v4` action.
- The build directory (`build/`) is archived and uploaded as `application-build`.
- Artifacts can be inspected, downloaded from the GitHub Actions UI, or consumed by subsequent workflow jobs or release pipelines.

---

## 13. Docker / CD Stage (Deployment Readiness)

In modern cloud-native DevOps architectures, **containerization represents the standard deployment artifact**:
- The `docker-build` job reads the `Dockerfile` and builds a lightweight container image:
  ```bash
  docker build -t application:latest .
  ```
- Uses `python:3.12-slim` base image to maintain a minimal container footprint.
- Acts as the Continuous Delivery (CD) readiness gateway, validating that the tested application successfully compiles into an executable, distributable container image ready for deployment to Kubernetes, Docker Hub, AWS ECS, or Azure Container Apps.

---

## 14. Pipeline Execution & Verification

To execute and verify this pipeline:

### Local Validation
```bash
# 1. Run unit tests locally
pytest -v

# 2. Run build script locally
chmod +x build.sh
./build.sh

# 3. Build container locally
docker build -t calculator-app:local .
```

### GitHub Cloud Execution
1. Push changes to the `main` branch of your GitHub repository.
2. Navigate to the **Actions** tab in GitHub.
3. Observe the workflow run executing:
   - `✓ Test Application`
   - `✓ Security & Secret Check`
   - `✓ Build & Artifact`
   - `✓ Docker Build (CD Preparation)`
4. Download the `application-build` artifact from the run summary.

---

## 15. Project Structure

```text
10-final-cicd-pipeline/
├── .github/
│   └── workflows/
│       └── ci.yml               # Complete CI/CD GitHub Actions workflow
├── app/
│   ├── __init__.py
│   └── calculator.py            # Application source code
├── tests/
│   ├── __init__.py
│   └── test_calculator.py       # Automated unit test suite
├── .gitignore                   # Excludes caches, venv, and build artifacts
├── build.sh                     # Packaging and build automation script
├── Dockerfile                   # Container packaging manifest
├── README.md                    # In-depth CI/CD technical documentation
└── requirements.txt             # Project runtime & test dependencies
```
