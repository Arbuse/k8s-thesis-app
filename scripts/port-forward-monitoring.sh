#!/usr/bin/env bash
set -euo pipefail
NS=monitoring
echo "🔌 Port-forward Prometheus (9090) i Grafana (3000)…"
kubectl -n "$NS" port-forward svc/k8s-monitoring-kube-promet-prometheus 9090:9090 >/dev/null 2>&1 &
PROM_PID=$!
kubectl -n "$NS" port-forward svc/k8s-monitoring-grafana 3000:80 >/dev/null 2>&1 &
GRAF_PID=$!
echo "✅ Prometheus: http://localhost:9090"
echo "✅ Grafana:    http://localhost:3000"
echo "🔑 Grafana admin password:"
kubectl -n "$NS" get secret k8s-monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo
echo "🛑 Stop: kill $PROM_PID $GRAF_PID"
