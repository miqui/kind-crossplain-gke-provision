#!/usr/bin/env bash
# Create a small kind cluster and install Crossplane + pinned providers/functions.
# Does NOT touch GCP. Requires: docker, kind, kubectl, helm.
set -euo pipefail
cd "$(dirname "$0")"

CROSSPLANE_VERSION="${CROSSPLANE_VERSION:-1.20.14}"
CLUSTER_NAME="crossplane-mgmt"

kind get clusters | grep -qx "$CLUSTER_NAME" || kind create cluster --config kind-config.yaml --wait 120s

helm repo add crossplane-stable https://charts.crossplane.io/stable >/dev/null
helm repo update crossplane-stable >/dev/null
helm upgrade --install crossplane crossplane-stable/crossplane \
  --namespace crossplane-system --create-namespace \
  --version "$CROSSPLANE_VERSION" --wait --timeout 5m

kubectl apply -f providers.yaml
kubectl wait --for=condition=Healthy provider.pkg.crossplane.io --all --timeout=10m
kubectl wait --for=condition=Healthy function.pkg.crossplane.io --all --timeout=5m

kubectl apply -f ../apis/xcluster/definition.yaml
kubectl wait --for=condition=Established xrd/xclusters.platform.example.org --timeout=2m
kubectl apply -f ../apis/xcluster/composition.yaml

echo "Control plane ready. ProviderConfig NOT applied: set project ID + create the credentials Secret first."
