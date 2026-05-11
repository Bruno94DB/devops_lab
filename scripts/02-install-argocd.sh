#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${SCRIPT_DIR}")"
ARGOCD_VERSION="7.8.27"   # Helm chart version (ArgoCD 2.14.x)
ARGOCD_NAMESPACE="argocd"

echo "==> Adding Argo Helm repo..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

echo "==> Installing ArgoCD v${ARGOCD_VERSION} in namespace '${ARGOCD_NAMESPACE}'..."
helm upgrade --install argocd argo/argo-cd \
  --namespace "${ARGOCD_NAMESPACE}" \
  --create-namespace \
  --version "${ARGOCD_VERSION}" \
  --values "${REPO_ROOT}/infrastructure/argocd/values.yaml" \
  --wait \
  --timeout 5m

echo "==> Waiting for ArgoCD server to be ready..."
kubectl rollout status deployment/argocd-server -n "${ARGOCD_NAMESPACE}" --timeout=120s

echo ""
echo "==> ArgoCD installed. Fetching initial admin password..."
ARGOCD_PASSWORD=$(kubectl -n "${ARGOCD_NAMESPACE}" get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
echo ""
echo "  Admin password: ${ARGOCD_PASSWORD}"
echo ""
echo "==> Starting port-forward to ArgoCD UI..."
echo "    Open: http://localhost:8888  (user: admin)"
echo "    Press Ctrl+C to stop."
echo ""
kubectl port-forward svc/argocd-server -n "${ARGOCD_NAMESPACE}" 8888:80
