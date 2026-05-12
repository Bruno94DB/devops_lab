#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_NAME="devops-lab"
ARGOCD_VERSION="7.8.27"
ARGOCD_NAMESPACE="argocd"

# ─── Helpers ──────────────────────────────────────────────────────────────────
log()  { echo "==> $*"; }
info() { echo "    $*"; }

wait_for_namespace() {
  local ns="$1" timeout="${2:-300}"
  local elapsed=0
  echo -n "    Waiting for namespace '$ns'"
  until kubectl get namespace "$ns" >/dev/null 2>&1; do
    sleep 5; elapsed=$((elapsed + 5))
    echo -n "."
    [ "$elapsed" -ge "$timeout" ] && { echo " TIMEOUT"; return 1; }
  done
  echo " ready"
}

wait_for_deployment() {
  local ns="$1" name="$2" timeout="${3:-300}"
  local elapsed=0
  echo -n "    Waiting for deployment '$name'"
  until kubectl get deployment "$name" -n "$ns" >/dev/null 2>&1; do
    sleep 5; elapsed=$((elapsed + 5))
    echo -n "."
    [ "$elapsed" -ge "$timeout" ] && { echo " TIMEOUT"; return 1; }
  done
  echo ""
  kubectl rollout status deployment/"$name" -n "$ns" --timeout="${timeout}s"
}

# ─── 1. Prerequisites ─────────────────────────────────────────────────────────
log "Checking prerequisites..."
command -v k3d     >/dev/null || { echo "ERROR: k3d not found";     exit 1; }
command -v helm    >/dev/null || { echo "ERROR: helm not found";    exit 1; }
command -v kubectl >/dev/null || { echo "ERROR: kubectl not found"; exit 1; }
docker info >/dev/null 2>&1   || { echo "ERROR: Docker not running"; exit 1; }

# ─── 2. k3d cluster ───────────────────────────────────────────────────────────
if k3d cluster list 2>/dev/null | grep -q "^${CLUSTER_NAME}"; then
  log "Cluster '${CLUSTER_NAME}' already exists, skipping creation."
else
  log "Creating k3d cluster..."
  k3d cluster create --config "${SCRIPT_DIR}/k3d-config.yaml"
fi
kubectl cluster-info >/dev/null

# ─── 3. ArgoCD ────────────────────────────────────────────────────────────────
log "Installing ArgoCD ${ARGOCD_VERSION}..."
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update argo 2>/dev/null

helm upgrade --install argocd argo/argo-cd \
  --namespace "${ARGOCD_NAMESPACE}" \
  --create-namespace \
  --version "${ARGOCD_VERSION}" \
  --values "${SCRIPT_DIR}/infrastructure/argocd/values.yaml" \
  --wait --timeout 5m

kubectl rollout status deployment/argocd-server -n "${ARGOCD_NAMESPACE}" --timeout=120s

# ─── 4. Bootstrap App-of-Apps ─────────────────────────────────────────────────
log "Applying root ArgoCD app (App-of-Apps)..."
kubectl apply -f "${SCRIPT_DIR}/bootstrap/root-app.yaml"
info "ArgoCD will now sync all apps from GitHub automatically."

# ─── 5. Wait for nginx-ingress ────────────────────────────────────────────────
log "Waiting for nginx-ingress..."
wait_for_namespace ingress-nginx
wait_for_deployment ingress-nginx nginx-ingress-ingress-nginx-controller 300

# ─── 6. Wait for Crossplane + apply RBAC ─────────────────────────────────────
log "Waiting for Crossplane..."
wait_for_namespace crossplane-system
wait_for_deployment crossplane-system crossplane 300

log "Applying Crossplane provider RBAC..."
bash "${SCRIPT_DIR}/scripts/03-crossplane-rbac.sh"

# ─── 7. Summary ───────────────────────────────────────────────────────────────
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│                      Lab is UP ✓                            │"
echo "├──────────────┬──────────────────────────────────────────────┤"
echo "│ ArgoCD       │ http://argocd.lab.local                      │"
echo "│              │ user: admin  pass: admin                     │"
echo "│ Rancher      │ https://rancher.lab.local                    │"
echo "│              │ user: admin  pass: admin                     │"
echo "│ Grafana      │ http://grafana.lab.local                     │"
echo "│              │ user: admin  pass: prom-operator             │"
echo "│ Tetris       │ http://tetris.lab.local                      │"
echo "├──────────────┴──────────────────────────────────────────────┤"
echo "│ ArgoCD syncs remaining apps (Rancher, Grafana, Crossplane)  │"
echo "│ in the background — allow 3-5 min for full readiness.       │"
echo "└─────────────────────────────────────────────────────────────┘"
