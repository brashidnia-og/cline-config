---
paths:
  - "**/Dockerfile*"
  - "**/docker-compose*.yml"
  - "**/docker-compose*.yaml"
  - "**/compose*.yml"
  - "**/compose*.yaml"
  - "**/k8s/**"
  - "**/kubernetes/**"
  - "**/helm/**"
  - "**/charts/**"
---

# Docker and infrastructure command policy

Infrastructure tools can affect persistent or remote environments. Default to read-only inspection. This profile does not use Terraform; do not invent terraform workflows.

## Docker inspection
Generally acceptable for known local environments:
```bash
docker ps
docker ps -a
docker images
docker inspect <known-object>
docker logs --tail 200 <known-container>
docker stats --no-stream
docker port <known-container>
docker top <known-container>
docker compose ps
docker compose logs --tail 200
docker compose config
```

Do not automatically run `docker run`, `rm`, `rmi`, `stop`, `kill`, `compose up/down`, `push`, `system prune`, or volume deletion. Repository test frameworks such as Testcontainers may create disposable containers as part of approved tests.

## Kubernetes / Helm
Before any Kubernetes command establish the active context.

Potentially read-only after context verification:
```bash
kubectl config current-context
kubectl get ...
kubectl describe ...
kubectl logs ...
helm list
helm status <release>
helm get values <release>
```

Do not auto-run `kubectl apply/delete/patch/edit/rollout restart`, Helm install/upgrade/uninstall, or mutating AWS/GCP/Azure commands (see AWS CDK cmd policy for AWS read/synth rules).

Never deploy or alter infrastructure merely to validate a code change.
