#!/usr/bin/env bash
set -euo pipefail

NS="monitoring"
RELEASE="k8s-monitoring"
VALUES_FILE="monitoring/values.yaml"
SM_FILE="k8s/servicemonitor.yaml"

echo "Tworzę/utrwalam namespace: $NS"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

echo "Dodaję/aktualizuję repo Helm: prometheus-community"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update

echo "Instaluję/aktualizuję kube-prometheus-stack: $RELEASE (ns=$NS)"
if [[ -f "$VALUES_FILE" ]]; then
  helm upgrade --install "$RELEASE" prometheus-community/kube-prometheus-stack -n "$NS" -f "$VALUES_FILE"
else
  helm upgrade --install "$RELEASE" prometheus-community/kube-prometheus-stack -n "$NS"
fi

echo "Czekam na Grafanę (deployment po etykiecie)…"
kubectl -n "$NS" wait --for=condition=available --timeout=5m deploy -l app.kubernetes.io/name=grafana

echo "Czekam na Pody Prometheusa (po etykiecie)…"
kubectl -n "$NS" wait --for=condition=ready --timeout=5m pod -l app.kubernetes.io/name=prometheus || true

if [[ -f "$SM_FILE" ]]; then
  echo "Stosuję ServiceMonitor aplikacji: $SM_FILE"
  kubectl apply -f "$SM_FILE"
else
  echo "ℹBrak pliku $SM_FILE – pomijam tworzenie ServiceMonitora."
fi

echo "Hasło do Grafany:"
kubectl -n "$NS" get secret "$RELEASE-grafana" -o jsonpath='{.data.admin-password}' | base64 -d; echo

echo "Czyszczę ewentualne stare port-forwardy (3000/9090)…"
pkill -f 'kubectl.*port-forward.*:3000' 2>/dev/null || true
pkill -f 'kubectl.*port-forward.*:9090' 2>/dev/null || true
lsof -ti :3000 -sTCP:LISTEN | xargs -r kill
lsof -ti :9090 -sTCP:LISTEN | xargs -r kill

echo "Uruchamiam port-forward (Prometheus:9090, Grafana:3000)…"

GRAF_SVC_COUNT=$(kubectl -n "$NS" get svc -l app.kubernetes.io/name=grafana,app.kubernetes.io/instance="$RELEASE" -o jsonpath='{.items|length}')
if [[ "${GRAF_SVC_COUNT:-0}" -gt 0 ]]; then
  GRAF_SVC=$(kubectl -n "$NS" get svc -l app.kubernetes.io/name=grafana,app.kubernetes.io/instance="$RELEASE" -o jsonpath='{.items[0].metadata.name}')
  kubectl -n "$NS" port-forward svc/"$GRAF_SVC" 3000:80 >/dev/null 2>&1 &
  GRAF_PID=$!
else
  GRAF_POD=$(kubectl -n "$NS" get pod -l app.kubernetes.io/name=grafana,app.kubernetes.io/instance="$RELEASE" -o jsonpath='{.items[0].metadata.name}')
  kubectl -n "$NS" port-forward pod/"$GRAF_POD" 3000:3000 >/dev/null 2>&1 &
  GRAF_PID=$!
fi

PROM_SVC_COUNT=$(kubectl -n "$NS" get svc -l app.kubernetes.io/name=prometheus -o jsonpath='{.items|length}')
if [[ "${PROM_SVC_COUNT:-0}" -gt 0 ]]; then
  PROM_SVC=$(kubectl -n "$NS" get svc -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}')
  kubectl -n "$NS" port-forward svc/"$PROM_SVC" 9090:9090 >/dev/null 2>&1 &
  PROM_PID=$!
else
  PROM_POD=$(kubectl -n "$NS" get pod -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}')
  kubectl -n "$NS" port-forward pod/"$PROM_POD" 9090:9090 >/dev/null 2>&1 &
  PROM_PID=$!
fi

echo "Prometheus: http://localhost:9090"
echo "Grafana:    http://localhost:3000"
echo "Prometheus Targets: http://localhost:9090/targets"
echo "Aby zatrzymać port-forward: kill $PROM_PID $GRAF_PID"
BASH

