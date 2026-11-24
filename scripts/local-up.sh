#!/usr/bin/env bash
# Локальный стенд: тот же конвейер, что в CI, но на вашей машине (macOS / Ubuntu).
#   lint+tests → docker build → kind (K8s) → MinIO (S3) → отчёт в beads (трекер)
# Требуется: docker, kind, kubectl, node 20+. Опционально: bd (beads).
set -euo pipefail
cd "$(dirname "$0")/.."

CLUSTER=${CLUSTER:-e2e}
NS=e2e-pipeline
SHA=$(git rev-parse HEAD 2>/dev/null || echo local)
IMAGE="e2e-pipeline:sha-${SHA}"
PORT=${PORT:-18080}
MINIO_PORT=${MINIO_PORT:-19000}
MINIO_CONSOLE_PORT=${MINIO_CONSOLE_PORT:-19001}

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
need() { command -v "$1" >/dev/null || { echo "Нужен '$1'. macOS: brew install $2 | Ubuntu: см. README"; exit 1; }; }
need docker docker; need kind kind; need kubectl kubectl; need node node

step "1/6 Lint и тесты"
npm ci --silent
npm run lint
npm run test:ci

step "2/6 Docker build: $IMAGE"
docker build -q --build-arg APP_VERSION="$SHA" -t "$IMAGE" .

step "3/6 Kubernetes (kind cluster '$CLUSTER')"
kind get clusters 2>/dev/null | grep -qx "$CLUSTER" || kind create cluster --name "$CLUSTER" --wait 60s
kubectl config use-context "kind-$CLUSTER" >/dev/null
kind load docker-image "$IMAGE" --name "$CLUSTER"
kubectl apply -k k8s/
kubectl -n "$NS" set image deployment/app app="$IMAGE"
kubectl -n "$NS" rollout status deployment/app --timeout=120s

step "4/6 Smoke test"
pkill -f "port-forward.*svc/app ${PORT}:80" 2>/dev/null || true
kubectl -n "$NS" port-forward svc/app "${PORT}:80" >/tmp/e2e-pf.log 2>&1 &
for _ in $(seq 1 20); do curl -fs "127.0.0.1:${PORT}/health" >/dev/null && break; sleep 1; done
curl -fs "127.0.0.1:${PORT}/"; echo

step "5/6 Артефакты в S3 (MinIO)"
if ! docker ps --format '{{.Names}}' | grep -qx e2e-minio; then
  docker rm -f e2e-minio >/dev/null 2>&1 || true
  docker run -d --name e2e-minio -p "${MINIO_PORT}:9000" -p "${MINIO_CONSOLE_PORT}:9001" \
    -e MINIO_ROOT_USER=minioadmin -e MINIO_ROOT_PASSWORD=minioadmin \
    minio/minio server /data --console-address :9001 >/dev/null
  for _ in $(seq 1 30); do curl -fs "127.0.0.1:${MINIO_PORT}/minio/health/live" && break; sleep 1; done
fi
rm -rf .local-artifacts && mkdir -p .local-artifacts/deploy-report
kubectl -n "$NS" get all -o wide > .local-artifacts/deploy-report/resources.txt
printf '{"sha":"%s","image":"%s","created_at":"%s"}\n' "$SHA" "$IMAGE" "$(date -u +%FT%TZ)" > .local-artifacts/build-info.json
cp -R coverage .local-artifacts/coverage
# В образе minio/minio уже есть клиент mc — грузим изнутри контейнера
docker exec e2e-minio rm -rf /tmp/upload
docker cp .local-artifacts e2e-minio:/tmp/upload
docker exec e2e-minio sh -c "
  mc alias set local http://127.0.0.1:9000 minioadmin minioadmin >/dev/null &&
  mc mb -p local/ci-artifacts >/dev/null &&
  mc cp -r /tmp/upload/ local/ci-artifacts/local/${SHA}/ >/dev/null &&
  mc ls -r local/ci-artifacts/local/${SHA}/"
rm -rf .local-artifacts

step "6/6 Трекер"
if command -v bd >/dev/null && [ -d .beads ]; then
  bd create "Local deploy ${SHA:0:7} OK" -t event -d "Image ${IMAGE}, artifacts s3://ci-artifacts/local/${SHA}/" \
    --event-category deploy.local --event-target "$IMAGE" >/dev/null \
    && echo "Событие деплоя записано в beads" || echo "beads: событие не записано (не критично)"
else
  echo "bd не найден — пропуск"
fi

cat <<MSG

Готово:
  App:           http://127.0.0.1:${PORT}/      (port-forward в фоне)
  MinIO console: http://127.0.0.1:${MINIO_CONSOLE_PORT}/   (minioadmin / minioadmin)
  kubectl -n ${NS} get pods
  Снести стенд:  scripts/local-down.sh
MSG
