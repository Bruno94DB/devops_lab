#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="backstage"

echo "=== Backstage Secrets Setup ==="
echo ""
echo "Trebaš GitHub Personal Access Token (PAT) s dozvolama:"
echo "  - Contents: Read and Write  (za kreiranje PR-ova)"
echo "  - Metadata: Read"
echo ""
echo "Kreiraj ga na: https://github.com/settings/tokens?type=beta"
echo ""
read -rsp "Upiši GitHub PAT token: " GITHUB_TOKEN
echo ""

echo "==> Kreiram Kubernetes ServiceAccount za Backstage K8s plugin..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backstage-k8s-viewer
  namespace: ${NAMESPACE}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: backstage-k8s-viewer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view
subjects:
  - kind: ServiceAccount
    name: backstage-k8s-viewer
    namespace: ${NAMESPACE}
---
apiVersion: v1
kind: Secret
metadata:
  name: backstage-k8s-sa-token
  namespace: ${NAMESPACE}
  annotations:
    kubernetes.io/service-account.name: backstage-k8s-viewer
type: kubernetes.io/service-account-token
EOF

echo "==> Čekam da token bude populiran..."
sleep 5

K8S_SA_TOKEN=$(kubectl get secret backstage-k8s-sa-token -n "${NAMESPACE}" \
  -o jsonpath='{.data.token}' | base64 -d)

echo "==> Kreiram Secret 'backstage-secrets' u namespace-u '${NAMESPACE}'..."
kubectl create secret generic backstage-secrets \
  --namespace="${NAMESPACE}" \
  --from-literal=GITHUB_TOKEN="${GITHUB_TOKEN}" \
  --from-literal=K8S_SA_TOKEN="${K8S_SA_TOKEN}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "Secret kreiran. ArgoCD može sada deployati Backstage."
echo "Pokreni: kubectl annotate application backstage -n argocd argocd.argoproj.io/refresh=normal --overwrite"
