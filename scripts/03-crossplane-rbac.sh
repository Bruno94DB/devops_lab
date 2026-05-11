#!/usr/bin/env bash
set -euo pipefail

echo "==> Waiting for provider-kubernetes to be Healthy..."
kubectl wait --for=condition=Healthy provider.pkg.crossplane.io/provider-kubernetes \
  --timeout=180s

echo "==> Finding provider ServiceAccount..."
SA=$(kubectl get sa -n crossplane-system --no-headers | grep -i "provider-kubernetes" | awk '{print $1}' | head -1)

if [ -z "${SA}" ]; then
  echo "ERROR: Could not find provider-kubernetes ServiceAccount in crossplane-system"
  exit 1
fi

echo "==> Granting cluster-admin to ServiceAccount: ${SA}"
kubectl create clusterrolebinding provider-kubernetes-admin \
  --clusterrole=cluster-admin \
  --serviceaccount="crossplane-system:${SA}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "RBAC applied. Provider can now manage cluster resources."
