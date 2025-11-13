#!/usr/bin/env bash
set -euo pipefail

echo "[12] Установка Kubernetes Dashboard..."

# выбираем kubectl
if command -v kubectl >/dev/null 2>&1; then
  KUBECTL=kubectl
elif command -v k3s >/dev/null 2>&1; then
  KUBECTL="k3s kubectl"
else
  echo "[12] Не найден kubectl или k3s. Убедись, что k3s master установлен."
  exit 1
fi

echo "[12] Проверка доступа к кластеру..."
$KUBECTL get nodes

echo "[12] Применяю манифест Dashboard..."
$KUBECTL apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

echo "[12] Создаю admin-пользователя для Dashboard..."

cat <<EOF | $KUBECTL apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF

echo "[12] Kubernetes Dashboard установлен."

cat <<'EOF'

Как получить токен для входа в веб-интерфейс:

На master-нODE выполнить:

  # вариант 1 (если поддерживается create token):
  kubectl -n kubernetes-dashboard create token admin-user

или, если create token нет:

  kubectl -n kubernetes-dashboard get secret \
    $(kubectl -n kubernetes-dashboard get sa/admin-user -o jsonpath="{.secrets[0].name}") \
    -o go-template="{{.data.token | base64decode}}"

Как открыть Dashboard в браузере (пока самый безопасный вариант — через port-forward):

  kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard 8443:443

Затем в браузере перейти на:

  https://127.0.0.1:8443

и вставить токен, который получили выше.

Позже мы сможем повесить Dashboard за Ingress (через traefik) и сделать нормальный домен + Cloudflare.
EOF
