# Улучшения и рекомендации для RPI5-Autostart

## ✅ Уже реализовано

- ✅ Базовая настройка системы с NVMe
- ✅ **Автоматическое определение размера ZRAM** (адаптируется под RAM)
- ✅ **Автоматическое обновление EEPROM** (последние фичи и исправления)
- ✅ Оптимизированные sysctl параметры для k3s
- ✅ Отключение ненужных сервисов (Bluetooth, etc)
- ✅ Мониторинг температуры и throttling
- ✅ Оптимизированная установка k3s с параметрами для RPI5
- ✅ Boot параметры (cgroup memory, GPU memory split)
- ✅ Интерактивные скрипты установки

## 🎯 Рекомендуемые дополнения

### 1. Сетевые компоненты для кластера

#### MetalLB (LoadBalancer)
```bash
# Для использования LoadBalancer сервисов без облака
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

# Затем настроить IP pool
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.240-192.168.1.250  # Ваш диапазон IP
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default
EOF
```

#### Traefik Ingress (управление)
```bash
# k3s включает traefik по умолчанию, но мы его отключили
# Установка через Helm для лучшего контроля:
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm install traefik traefik/traefik \
  --namespace traefik \
  --create-namespace \
  --set ports.web.nodePort=30080 \
  --set ports.websecure.nodePort=30443
```

#### Cert-Manager (автоматические SSL сертификаты)
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

### 2. Storage решения

#### Longhorn (distributed storage)
```bash
# Distributed block storage для HA
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.5.3/deploy/longhorn.yaml

# Нужно установить open-iscsi на каждой ноде:
# apt-get install -y open-iscsi
```

#### NFS Provisioner (если есть NAS)
```bash
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --set nfs.server=192.168.1.100 \
  --set nfs.path=/mnt/k8s
```

### 3. Мониторинг и логирование

#### Prometheus + Grafana Stack
```bash
# Полный стек мониторинга
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.retention=7d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=10Gi
```

#### Loki + Promtail (логирование)
```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --create-namespace
```

### 4. Безопасность

#### Firewall (UFW)
Добавить шаг 09_firewall.sh:
```bash
apt-get install -y ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp   # SSH
ufw allow 6443/tcp # k3s API
ufw allow 10250/tcp # kubelet
ufw allow from 10.42.0.0/16 # k3s pod network
ufw allow from 10.43.0.0/16 # k3s service network
ufw --force enable
```

#### Fail2Ban (защита SSH)
```bash
apt-get install -y fail2ban
systemctl enable --now fail2ban
```

#### SSH hardening
```bash
# В /etc/ssh/sshd_config:
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
```

### 5. Резервное копирование

#### Velero (backup для k8s)
```bash
# Backup и restore для всего кластера
kubectl apply -f https://github.com/vmware-tanzu/velero/releases/download/v1.12.0/velero-v1.12.0-linux-arm64.tar.gz
```

#### etcd snapshots
```bash
# Автоматический backup etcd (база данных k3s)
cat <<'EOF' > /usr/local/bin/k3s-backup.sh
#!/bin/bash
BACKUP_DIR="/var/backups/k3s"
mkdir -p "$BACKUP_DIR"
k3s etcd-snapshot save --name "backup-$(date +%Y%m%d-%H%M%S)"
find "$BACKUP_DIR" -name "*.zip" -mtime +7 -delete
EOF
chmod +x /usr/local/bin/k3s-backup.sh

# Cron для ежедневного backup
echo "0 2 * * * /usr/local/bin/k3s-backup.sh" | crontab -
```

### 6. DNS и Service Discovery

#### External-DNS (автоматическое управление DNS)
```bash
# Если используешь Cloudflare или другой DNS провайдер
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm install external-dns external-dns/external-dns \
  --set provider=cloudflare
```

### 7. GitOps

#### ArgoCD (declarative GitOps)
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

#### Flux CD (альтернатива)
```bash
curl -s https://fluxcd.io/install.sh | bash
flux bootstrap github \
  --owner=YOUR_USERNAME \
  --repository=fleet-infra \
  --path=clusters/rpi-cluster
```

### 8. Дополнительные оптимизации

#### CPU Governor
```bash
# Для максимальной производительности
echo "performance" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

#### Transparent Huge Pages (для баз данных)
```bash
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
```

#### IO Scheduler
```bash
# Для NVMe лучше использовать none или mq-deadline
echo "none" > /sys/block/nvme0n1/queue/scheduler
```

### 9. Автоматизация обновлений

#### Unattended Upgrades
```bash
apt-get install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades
```

#### System upgrade operator для k3s
```bash
kubectl apply -f https://github.com/rancher/system-upgrade-controller/releases/download/v0.13.1/system-upgrade-controller.yaml
```

### 10. Высокая доступность (HA)

Если планируешь HA кластер:

#### Несколько master нод
```bash
# На первой мастер ноде:
curl -sfL https://get.k3s.io | sh -s - server \
  --cluster-init \
  --disable traefik

# На последующих мастер нодах:
curl -sfL https://get.k3s.io | sh -s - server \
  --server https://FIRST_MASTER_IP:6443 \
  --token TOKEN_FROM_FIRST_MASTER
```

#### External database (для production)
```bash
# Использовать PostgreSQL вместо встроенного etcd
curl -sfL https://get.k3s.io | sh -s - server \
  --datastore-endpoint="postgres://username:password@hostname:5432/database"
```

## 📊 Полезные инструменты

### K9s - Terminal UI для Kubernetes
```bash
wget https://github.com/derailed/k9s/releases/download/v0.27.4/k9s_Linux_arm64.tar.gz
tar xzf k9s_Linux_arm64.tar.gz
mv k9s /usr/local/bin/
```

### Helm - Package Manager для Kubernetes
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Kubectx + Kubens - Быстрое переключение контекстов
```bash
wget https://github.com/ahmetb/kubectx/releases/download/v0.9.5/kubectx
wget https://github.com/ahmetb/kubectx/releases/download/v0.9.5/kubens
chmod +x kubectx kubens
mv kubectx kubens /usr/local/bin/
```

## 🎬 Скрипты для быстрого старта

### Установка MetalLB
Создать: `cluster/steps/13_metallb.sh`

### Установка monitoring stack
Создать: `cluster/steps/14_monitoring.sh`

### Установка Longhorn
Создать: `cluster/steps/15_longhorn.sh`

## 🔒 Production Checklist

- [ ] Настроен firewall (UFW)
- [ ] Настроен fail2ban
- [ ] Отключена парольная аутентификация SSH
- [ ] Настроены автоматические обновления
- [ ] Настроен мониторинг (Prometheus/Grafana)
- [ ] Настроено логирование (Loki)
- [ ] Настроен backup (Velero/etcd snapshots)
- [ ] Настроен LoadBalancer (MetalLB)
- [ ] Настроен Ingress Controller (Traefik)
- [ ] Настроен SSL (Cert-Manager)
- [ ] Настроен distributed storage (Longhorn/NFS)
- [ ] Настроены resource limits для подов
- [ ] Настроены network policies
- [ ] Проведены нагрузочные тесты

## 🌡️ Охлаждение для RPI5

При высокой нагрузке рекомендуется:

1. **Passive cooling**: Радиатор + термопрокладки
2. **Active cooling**: Вентилятор PWM (управляемый)
3. **Case с вентиляцией**: Argon NEO 5 или аналог

### Скрипт автоматического управления вентилятором
```bash
# Создать systemd service для управления PWM вентилятором
# по температуре CPU
```

## 📝 Примечания

- Все скрипты тестировались на RPI5 8GB с Pi OS Lite
- Рекомендуется минимум 32GB NVMe SSD
- Для production кластера нужно минимум 3 master ноды
- Регулярно обновляйте систему и k3s
- Мониторьте температуру при нагрузке
