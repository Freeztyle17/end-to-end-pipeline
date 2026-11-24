#!/usr/bin/env bash
set -euo pipefail
CLUSTER=${CLUSTER:-e2e}
pkill -f "port-forward.*svc/app" 2>/dev/null || true
kind delete cluster --name "$CLUSTER" || true
docker rm -f e2e-minio >/dev/null 2>&1 || true
echo "Стенд удалён"
