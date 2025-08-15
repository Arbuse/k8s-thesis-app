# k8s-thesis-app

Prosta aplikacja Flask do testów monitoringu, autoskalowania i optymalizacji w Kubernetes. Udostępnia endpointy:

- `/` – szybka odpowiedź (health/info)
- `/slow?seconds=1.5` – usypia proces na podaną liczbę sekund (0..30)
- `/cpu?seconds=2&workers=4` – obciążenie CPU przez podany czas i liczbę wątków
- `/metrics` – metryki Prometheus (auto z `prometheus_flask_exporter`)

## Szybki start (Docker Compose)
```bash
# Budowa i uruchomienie
docker compose up --build -d

# Testy
curl -s localhost:8000/ | jq
curl -s "localhost:8000/slow?seconds=1.2" | jq
curl -s "localhost:8000/cpu?seconds=2&workers=2" | jq

# Metryki Prometheus
curl -s localhost:8000/metrics | head -n 30

### Monitoring (kube-prometheus-stack)

```bash
# 1) Instalacja stacku monitoringu
./scripts/setup-monitoring.sh

# 2) Podpięcie metryk aplikacji
kubectl apply -f k8s/servicemonitor.yaml

# 3) Port-forward do Prometheusa i Grafany
./scripts/port-forward-monitoring.sh
# Prometheus -> http://localhost:9090
# Grafana    -> http://localhost:3000  (admin / hasło z sekretu)


#Uwaga: uruchomienie w kontenerze korzysta z gunicorn z 1 workerem dla spójności metryk /metrics. W Kubernetes skalą jest liczba replik (pods), nie liczba workerów wewnątrz procesu.