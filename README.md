# end-to-end-pipeline

Сквозной CI/CD-конвейер: **commit → CI → тесты → Docker → K8s → S3 → трекер**.

```
push в main
   │
   ▼
┌────────┐   ┌──────────────┐   ┌────────────────┐   ┌──────────────┐   ┌────────────────┐
│  test  │──►│    build     │──►│     deploy     │──►│  artifacts   │──►│     notify     │
│ eslint │   │ docker build │   │ kind-кластер   │   │ MinIO / S3   │   │ GitHub Issues  │
│ jest   │   │ push → ghcr  │   │ apply, rollout │   │ coverage,    │   │ (+ Пачка)      │
│ cover. │   │ :sha-<commit>│   │ smoke /health  │   │ deploy-report│   │                │
└────────┘   └──────────────┘   └────────────────┘   └──────────────┘   └────────────────┘
```

| Этап | Где | Что делает |
|---|---|---|
| test | `.github/workflows/pipeline.yml` → `test` | `npm run lint`, `npm run test:ci` (порог покрытия 80% строк), coverage в артефакты |
| build | `build` | образ `ghcr.io/freeztyle17/end-to-end-pipeline:sha-<commit>` + `:latest`, `:main`; на PR — только сборка |
| deploy | `deploy` | поднимает kind, грузит образ, `kubectl apply -k k8s/`, `rollout status`, smoke-тест: `/` должен вернуть sha коммита |
| artifacts | `artifacts` | кладёт coverage, отчёт деплоя и `build-info.json` в `s3://ci-artifacts/<repo>/<sha>/` |
| notify | `notify` | комментарий во все issue, упомянутые в коммите (`#12`); при провале — issue с меткой `ci-failure`; Пачка — если задан webhook |

## Приложение

Node 20, без фреймворков (`src/server.js`):

- `GET /health` → `{"status":"ok"}`
- `GET /` → `{"app":"end-to-end-pipeline","version":"<sha>","hostname":"<pod>"}`

```bash
npm ci && npm test && npm start
```

## Локальный стенд (macOS / Ubuntu)

Тот же конвейер на своей машине — удобно показывать на паре.

```bash
brew install kind kubectl   # macOS (Docker Desktop должен быть запущен)
```

```bash
./scripts/local-up.sh
```

Скрипт: lint+тесты → `docker build` → kind-кластер `e2e` → деплой и smoke-тест → MinIO + загрузка артефактов → событие в beads.

- приложение: http://127.0.0.1:18080/
- консоль MinIO: http://127.0.0.1:19001/ (`minioadmin` / `minioadmin`), bucket `ci-artifacts`
- порты меняются через `PORT`, `MINIO_PORT`, `MINIO_CONSOLE_PORT`

```bash
./scripts/local-down.sh
```

**Ubuntu-сервер:** поставить Docker, `kind` и `kubectl` (бинарники с GitHub releases / `snap install kubectl --classic`), дальше тот же `./scripts/local-up.sh`. Для постоянного кластера вместо kind можно взять k3s — манифесты в `k8s/` те же.

## Секреты (все опциональны)

| Секрет | Зачем |
|---|---|
| `S3_ENDPOINT`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`, `S3_BUCKET` | постоянное S3 (Yandex Object Storage, AWS, свой MinIO). Без них — эфемерный MinIO внутри job'а |
| `PACHKA_WEBHOOK_URL` | дублировать уведомление в Пачку |

`GITHUB_TOKEN` выдаётся автоматически: им пушится образ в ghcr и пишутся issue.

## Трекер задач

Задачи по проекту ведутся в [beads](https://github.com/steveyegge/beads) (`.beads/`):

```bash
bd list
```

```bash
bd ready
```

## Структура

```
.github/workflows/pipeline.yml   конвейер
src/server.js                    приложение
test/                            jest + supertest
Dockerfile, .dockerignore        образ (node:20-alpine, non-root, HEALTHCHECK)
k8s/                             Namespace, Deployment (2 реплики, probes), Service, kustomization
scripts/local-up.sh|local-down.sh  локальный стенд
```
