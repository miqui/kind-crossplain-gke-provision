# Teardown

## 1. If you ever applied a claim to real GCP (NOT done in this repo's verification)
Delete the claim FIRST and wait until Crossplane has removed every GCP resource, before destroying the kind cluster:

```bash
kubectl delete gkecluster demo -n default
kubectl get managed            # repeat until the list is empty (node pool -> cluster -> NAT -> router -> subnet -> VPC)
```

Deletion is ordered by dependency; the GKE cluster can take 10+ minutes. If something sticks in `Deleting`, inspect with
`kubectl describe <kind> <name>` (usually an IAM or quota error). Confirm in the GCP console / `gcloud` that no
cluster, router, NAT, subnet, VPC, or service account named `<claim>-*` remains.

## 2. Remove provider config and credentials
```bash
kubectl delete providerconfig.gcp.upbound.io default
kubectl delete secret gcp-credentials -n crossplane-system
```
Then revoke/delete the GCP credential itself (service account key, or the Workload Identity Federation binding).

## 3. Destroy the kind control plane
```bash
kind delete cluster --name crossplane-mgmt
```
**Warning:** deleting the kind cluster while managed resources still exist orphans them in GCP (and keeps billing).
The Crossplane state lives only in that kind cluster's etcd.
