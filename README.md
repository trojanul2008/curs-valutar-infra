# Curs-Valutar Infra

> Kubernetes infrastructure and GitOps pipeline for the Curs-Valutar application

---

## Table of Contents

1. [Overview](#overview)  
2. [Repository Structure](#repository-structure)  
3. [Prerequisites](#prerequisites)  
4. [Quickstart](#quickstart)  
5. [Kubernetes Manifests](#kubernetes-manifests)  
6. [Flux GitOps Configuration](#flux-gitops-configuration)  
7. [CI / CD Pipelines](#ci--cd-pipelines)  
8. [Promotion Script](#promotion-script)  
9. [Branching & Release Strategy](#branching--release-strategy)  
10. [Security & Compliance](#security--compliance)  
11. [Contributing](#contributing)  
12. [License](#license)

---

## Overview

This repository holds all the infrastructure-as-code (IaC) resources for deploying and managing the **Curs-Valutar** service on Kubernetes, following GitOps principles with Flux CD.  

- **Manifests** live under `infrastructure/k8s/` (with a common base and per-environment overlays).  
- **GitOps** is configured via Flux under `infrastructure/flux/`.  
- A GitHub Actions workflow (`.github/workflows/infra-ci.yaml`) validates Kubernetes manifests on every push.  
- The `promote.sh` helper lets you promote changes from `dev` → `prod` branches with history checks.

---

## Repository Structure

```text
.
├── .github/                   # GitHub Actions workflows
│   └── infra-ci.yaml
├── infrastructure/
│   ├── flux/                  # Flux CD controllers & repos
│   └── k8s/                   # Kubernetes YAML (base + overlays)
├── promote.sh                 # bash helper to merge/promote branches
├── renovate.json              # Renovate bot config
└── README.md                  # (this file)


    infrastructure/k8s/base/
    Shared Deployment, Service, Ingress, NetworkPolicy, PDB, healthcheck script.

    infrastructure/k8s/overlays/{dev,prod}/
    Environment-specific patches, image tags, namespaces.

    infrastructure/flux/flux-system/manifests/
    Flux GitRepository, Kustomization, ImageRepository, ImagePolicy, ImageUpdateAutomation resources.

    .github/workflows/infra-ci.yaml
    Runs kustomize build + kubeconform on base/dev/prod overlays.

Prerequisites

    kubectl ≥ v1.24

    kustomize CLI

    kubeconform (or alternative schema validator)

    A Kubernetes cluster (min. v1.22)

    Docker registry credentials stored in the docker-credentials Secret

    Flux CD installed in the flux-system namespace

Quickstart

    Clone the repo and switch to dev branch:

git clone https://github.com/your-org/curs-valutar-infra.git
cd curs-valutar-infra
git checkout dev

Validate manifests locally:

kustomize build infrastructure/k8s/base | kubeconform -verbose
kustomize build infrastructure/k8s/overlays/dev | kubeconform -verbose

Deploy Flux to bootstrap GitOps:

kubectl apply -k infrastructure/flux/flux-system/manifests

Push your changes and watch Flux reconcile:

    git add .
    git commit -m "feat: add new env var"
    git push origin dev
    # Flux will automatically apply to your dev namespace

Kubernetes Manifests

    Base: Shared objects, best practices (read-only root FS, probes, resource requests/limits, PodDisruptionBudget, network policy).

    Dev/Prod Overlays: Patch only what changes—replicas, image tags, secrets, affinity rules.

    Traefik: A dedicated Deployment under infrastructure/k8s/traefik-deployment.yaml for cluster ingress.

Flux GitOps Configuration

Flux ensures your cluster always matches Git:

    GitRepository (gotk-sync.yaml): Points at this repo’s dev branch for reconciliation.

    ImageRepository + ImagePolicy: Tracks your container registry (tags filtered by SemVer for prod, by prefix for dev).

    ImageUpdateAutomation: Automatically updates overlay setters when new tags appear.

    Kustomizations:

        flux-system: Installs Flux controllers (gotk-components.yaml).

        curs-valutar-dev/prod: Applies your overlays into respective namespaces.

CI / CD Pipelines

Infra Validation (.github/workflows/infra-ci.yaml):

    Runs on push to dev and prod.

    Steps:

        Checkout

        Install kustomize

        Install kubeconform

        kustomize build + kubeconform on base/dev/prod

Promotion Script

promote.sh automates merging or force-creating your prod branch from dev:

./promote.sh [--REMOTE origin] [--DEV dev] [--PROD prod]

It ensures:

    Clean working tree

    Shared history merge if possible

    Force-create for first-time or unrelated histories

Branching & Release Strategy

    dev: Rapid integration, auto-updates via Flux dev pipeline

    prod: Stable, only updated via promote.sh or Flux ImageUpdateAutomation on SemVer tags

    Tags: Use vX.Y.Z in prod, dev-<timestamp> for dev builds

Security & Compliance

    Pod hardening: runAsNonRoot, read-only root FS, dropped capabilities, seccomp RuntimeDefault

    NetworkPolicy: Restrictive by default but allows cross-namespace

    Image scanning: Not yet enabled—consider integrating Trivy or Clair in CI

    Secrets: Stored in Kubernetes docker-credentials; consider enabling SealedSecrets or External Secrets for greater safety

Pipeline Improvements & Best Practices

    YAML Linting

        Add a yamllint step to catch style errors.

    Policy as Code

        Integrate OPA/Gatekeeper or Kyverno to enforce security policies.

    Image Vulnerability Scanning

        Run a container scanner (e.g. Trivy) in CI.

    Infrastructure Tests

        Deploy into a test cluster and run smoke tests (e.g. via Terratest or k8s conformance tests).

    Drift Detection

        Use Flux’s HealthChecks or external drift detectors.

    Commit Message Conventions

        Enforce Conventional Commits via a commit-lint Action.

Contributing

    Fork the repo & create a feature branch

    Write clear, atomic commits

    Open a Pull Request against dev

    Ensure CI passes and Flux reconciliation succeeds

    Once approved, merge into dev; use promote.sh to push to prod

License

This project is licensed under the MIT License.


