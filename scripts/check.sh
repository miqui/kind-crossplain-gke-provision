#!/usr/bin/env bash
# Run every CI check locally. Offline w.r.t. GCP: nothing here talks to Google or needs credentials.
# Needs: yamllint, kubeconform, opa, crossplane (v1.20.x CLI), docker (for `crossplane render`).
# Usage: scripts/check.sh [stage...]   stages: yamllint kubeconform render validate policy (default: all)
set -euo pipefail
cd "$(dirname "$0")/.."

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
STAGES=("$@")
[ ${#STAGES[@]} -gt 0 ] || STAGES=(yamllint kubeconform render validate policy)

# A claim is not renderable; derive the equivalent XR (kind + no namespace) from the single example claim.
# status.nodeServiceAccountEmail is a dummy observed value so the IAM-member resources also render.
make_xr() {
  sed -e 's/^kind: GKECluster/kind: XCluster/' -e '/^  namespace: /d' examples/claim.yaml > "$WORK/xr.yaml"
  printf 'status:\n  nodeServiceAccountEmail: demo-nodes@example-project.iam.gserviceaccount.com\n' >> "$WORK/xr.yaml"
}

render() {
  [ -f "$WORK/rendered.yaml" ] && return 0
  make_xr
  crossplane render --include-full-xr "$WORK/xr.yaml" apis/xcluster/composition.yaml tests/render-functions.yaml > "$WORK/rendered.yaml"
}

stage_yamllint() { yamllint -c .yamllint.yaml --strict . ; }

stage_kubeconform() {
  kubeconform -strict -summary -ignore-missing-schemas \
    -schema-location default \
    -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
    bootstrap/providers.yaml apis/xcluster/definition.yaml apis/xcluster/composition.yaml tests/render-functions.yaml
}

stage_render() {
  render
  for k in Network Subnetwork Router RouterNAT ServiceAccount ProjectIAMMember Cluster NodePool; do
    grep -q "^kind: $k$" "$WORK/rendered.yaml" || { echo "render: missing $k" >&2; return 1; }
  done
  echo "render OK: $(grep -c '^kind: ' "$WORK/rendered.yaml") documents ($(grep '^kind: ' "$WORK/rendered.yaml" | sort | uniq -c | awk '{printf "%s x%s ", $3, $1}'))"
}

stage_validate() {
  render
  mkdir -p "$WORK/ext"
  cp apis/xcluster/definition.yaml bootstrap/providers.yaml "$WORK/ext/"
  crossplane beta validate "$WORK/ext" "$WORK/rendered.yaml" --cache-dir "${XP_CACHE_DIR:-$WORK/cache}"
}

stage_policy() {
  opa test policy -v
  local n
  n=$(opa eval -f raw -d policy -i examples/claim.yaml 'count(data.gke.privatecluster.deny)')
  [ "$n" = "0" ] || { echo "policy: example claim has $n violations" >&2; return 1; }
  echo "policy: examples/claim.yaml -> 0 violations"
  n=$(opa eval -f raw -d policy -i tests/policy/bad-public-claim.yaml 'count(data.gke.privatecluster.deny)')
  [ "$n" -gt 0 ] || { echo "policy: bad claim was NOT rejected" >&2; return 1; }
  echo "policy: tests/policy/bad-public-claim.yaml -> $n violations (rejected as expected)"
}

for s in "${STAGES[@]}"; do
  echo "=== $s ==="
  "stage_$s"
done
echo "ALL CHECKS PASSED"
