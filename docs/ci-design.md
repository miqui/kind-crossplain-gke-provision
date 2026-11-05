# CI design

Written before implementation. Goal: every pull request proves, **offline and keyless**, that the
Crossplane configuration is syntactically valid, renders, schema-validates, and satisfies the
private-cluster policy. Nothing in CI talks to GCP; no secrets, no OIDC, no cloud credentials.

## Principles
- Trigger: `pull_request` (all branches, all activity types default) plus `push` to `main` and `workflow_dispatch`.
- Permissions: workflow-level `contents: read` only. No `secrets.*` references.
- Third-party actions pinned to full commit SHAs; `persist-credentials: false` on checkout.
- Tools pinned to explicit versions and, for downloaded binaries, verified by SHA-256.
- One local entrypoint (`scripts/check.sh`) runs the same checks CI runs, so "green locally" means "green in CI".

## Jobs (names are the required status checks on `main`)
| Job name | Tooling | What it proves |
|---|---|---|
| `yamllint` | yamllint | All YAML is well-formed and consistently styled |
| `kubeconform` | kubeconform | Plain K8s/CRD-shaped manifests (XRD, Composition, claim, Provider, Function) parse against schemas; unknown CRDs are skipped explicitly |
| `crossplane-render` | crossplane CLI `render` | The example claim -> XR -> Composition pipeline renders to the expected managed resources (VPC, subnet, router, NAT, SA, IAM, GKE, node pool) using `function-patch-and-transform` run via Docker |
| `crossplane-validate` | crossplane CLI `beta validate` | Rendered managed resources validate against the real provider CRD schemas (provider packages pulled from the public registry, no credentials) |
| `policy` | OPA (`opa test`, `opa eval`) | Rego policy rejects public-endpoint / non-private claims; good claim passes, bad fixtures fail |

## Local runner
`scripts/check.sh` executes the same five stages. Needs: `yamllint`, `kubeconform`, `opa`, `crossplane`, Docker (for `render` functions).

## Out of scope (by design)
- Any apply to GCP, any real credentials.
- A kind+Crossplane install smoke test in CI (heavy, flaky for a PR gate); documented as a manual step.
