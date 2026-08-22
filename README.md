# Curs-Valutar Infra

Kubernetes infrastructure and GitOps configuration for the Curs-Valutar application.

## Overview

This repository uses a single-trunk GitOps model:

- `main` is the canonical infrastructure branch.
- `infrastructure/k8s/base/` contains shared Kubernetes resources.
- `infrastructure/k8s/overlays/dev/` contains DEV-specific desired state.
- `infrastructure/k8s/overlays/prod/` contains PROD-specific desired state.
- Argo CD owns the `curs-valutar` application in both DEV and PROD.
- Flux remains responsible for platform components such as Flux itself and External Secrets, plus unrelated Flux-managed workloads such as `istartit`.
- DEV and PROD are separated by Kustomize overlays and namespaces, not by long-lived Git branches.

## Repository Structure

```text
.
├── .github/
│   └── workflows/
│       ├── dev-deploy-verify.yaml
│       ├── infra-ci.yaml
│       ├── platform-recovery.yaml
│       └── prod-deploy-verify.yaml
├── infrastructure/
│   ├── argocd/
│   │   └── applications/
│   │       ├── curs-valutar-dev.yaml
│   │       └── curs-valutar-prod.yaml
│   ├── flux/
│   │   └── flux-system/
│   └── k8s/
│       ├── base/
│       └── overlays/
│           ├── dev/
│           └── prod/
├── scripts/
├── renovate.json
└── README.md
```

## GitOps Ownership

### Argo CD

Argo CD is the sole GitOps owner of the Curs-Valutar application workloads.

- `curs-valutar-dev` tracks `refs/heads/main` and renders `infrastructure/k8s/overlays/dev` into the `dev` namespace.
- `curs-valutar-prod` tracks `refs/heads/main` and renders `infrastructure/k8s/overlays/prod` into the `prod` namespace.
- Both applications use automated synchronization with pruning and self-healing.

Flux must not manage the Curs-Valutar application workloads or the legacy Curs-Valutar image automation resources.

### Flux

Flux is retained for platform-level reconciliation.

The root Flux source tracks `main` and reconciles:

```text
./infrastructure/flux/flux-system
```

Its canonical composition contains the Flux controllers and External Secrets integration. Curs-Valutar application ownership is intentionally excluded.

## Branching and Change Flow

`main` is the canonical branch. The old branch-per-environment promotion model is retired.

Normal infrastructure changes follow this flow:

1. Create a short-lived feature branch from the latest `main`.
2. Make the infrastructure change in the appropriate base or environment overlay.
3. Open a pull request against `main`.
4. Require Infrastructure CI to pass.
5. Merge the pull request.
6. Argo CD or Flux reconciles the relevant desired state from `main`.
7. Environment-specific post-deploy verification runs when application manifests for that environment changed.

Environment promotion is represented by an explicit Git change to the relevant overlay on `main`; it is not performed by copying or force-pushing long-lived environment branches.

Rollback should likewise be performed through Git, normally by reverting or correcting the relevant commit and allowing GitOps reconciliation to restore the desired state.

## Continuous Integration

`.github/workflows/infra-ci.yaml` runs for pull requests targeting `main`, pushes to `main`, and manual dispatches.

It validates both DEV and PROD desired state and currently includes:

- YAML linting
- Kustomize rendering
- Kubernetes schema validation with Kubeconform
- Kyverno policy validation
- Checkov Kubernetes policy validation
- Trivy configuration scanning
- Trivy image vulnerability reporting
- Validation artifact upload

Known migration-era policy exceptions are intentionally explicit rather than hidden:

- `CKV_K8S_43` is temporarily skipped while image deployment is migrated to immutable digest references.
- PROD temporarily baselines `CKV_K8S_8`, `CKV_K8S_9`, and `CKV_K8S_38` because those findings pre-date the single-trunk migration. They should be removed by a dedicated workload-hardening change.

## Post-Deploy Verification

DEV and PROD have separate post-deploy verification workflows.

### DEV

`.github/workflows/dev-deploy-verify.yaml` runs on pushes to `main` that change:

```text
infrastructure/k8s/base/**
infrastructure/k8s/overlays/dev/**
```

It waits for `curs-valutar-dev` to become `Synced` and `Healthy` at the exact triggering Git SHA and then runs an HTTP smoke test against:

```text
https://di-exchange.istartit.com
```

### PROD

`.github/workflows/prod-deploy-verify.yaml` runs on pushes to `main` that change:

```text
infrastructure/k8s/base/**
infrastructure/k8s/overlays/prod/**
```

It waits for `curs-valutar-prod` to become `Synced` and `Healthy` at the exact triggering Git SHA and then runs an HTTP smoke test against:

```text
https://exchange.istartit.com
```

## Platform Recovery

`.github/workflows/platform-recovery.yaml` is manual-only.

It supports a precheck mode and an explicitly confirmed recovery mode. Recovery is intended to reconstruct the platform control plane from the canonical `main` source of truth rather than perform a destructive cluster reset.

The recovery flow restores the required platform controllers and integrations while preserving the ownership boundary that keeps Curs-Valutar under Argo CD.

## Local Validation

Clone the repository and use `main`:

```bash
git clone https://github.com/trojanul2008/curs-valutar-infra.git
cd curs-valutar-infra
git switch main
```

Render the application environments locally:

```bash
kustomize build infrastructure/k8s/overlays/dev
kustomize build infrastructure/k8s/overlays/prod
```

Render the canonical Flux platform composition:

```bash
kustomize build infrastructure/flux/flux-system
```

Before opening a pull request, at minimum ensure changed YAML parses, Kustomize renders successfully, and `git diff --check` reports no whitespace errors.

## Kubernetes Layout

The application uses a shared Kustomize base plus per-environment overlays.

The base contains resources shared between environments. DEV and PROD overlays carry environment-specific desired-state differences such as namespace, replicas, image reference, and environment-specific patches.

Current application resources include:

- Deployment
- Service
- Ingress
- NetworkPolicy
- PodDisruptionBudget

## Security

Infrastructure changes are checked through Kubernetes schema validation, policy-as-code validation, and Trivy configuration/image scanning.

Secrets required by workloads and platform components must not be committed to Git. Runtime secret delivery uses the cluster's configured secret-management mechanisms.

The remaining known PROD Checkov findings are tracked explicitly and should be fixed in a dedicated workload-hardening change rather than hidden during repository-topology work.

## Contributing

1. Update local `main`.
2. Create a short-lived feature branch.
3. Make an atomic change.
4. Validate it locally.
5. Open a pull request against `main`.
6. Require CI to pass before merge.
7. Verify the relevant GitOps controller and post-deploy checks after merge.

Do not reintroduce long-lived environment branches or make Flux and Argo CD simultaneously own the same Curs-Valutar resources.

## License

This project is licensed under the MIT License.
