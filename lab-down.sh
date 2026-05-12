#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="devops-lab"

if k3d cluster list 2>/dev/null | grep -q "^${CLUSTER_NAME}"; then
  echo "==> Deleting k3d cluster '${CLUSTER_NAME}'..."
  k3d cluster delete "${CLUSTER_NAME}"
  echo "Lab torn down."
else
  echo "Cluster '${CLUSTER_NAME}' not found — nothing to do."
fi
