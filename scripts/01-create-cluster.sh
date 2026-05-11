#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="devops-lab"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${SCRIPT_DIR}")"
CONFIG_FILE="${REPO_ROOT}/k3d-config.yaml"

echo "==> Checking prerequisites..."
command -v k3d   >/dev/null || { echo "k3d not found"; exit 1; }
command -v helm  >/dev/null || { echo "helm not found"; exit 1; }
command -v kubectl >/dev/null || { echo "kubectl not found"; exit 1; }
docker info >/dev/null 2>&1 || { echo "Docker not running"; exit 1; }

if k3d cluster list | grep -q "^${CLUSTER_NAME}"; then
  echo "==> Cluster '${CLUSTER_NAME}' already exists, skipping creation."
  echo "    To recreate: k3d cluster delete ${CLUSTER_NAME}"
else
  echo "==> Creating k3d cluster from ${CONFIG_FILE}..."
  k3d cluster create --config "${CONFIG_FILE}"
fi

echo "==> Verifying cluster..."
kubectl cluster-info
kubectl get nodes -o wide

echo ""
echo "Cluster ready. Next step: run scripts/02-install-argocd.sh"
