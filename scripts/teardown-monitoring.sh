#!/usr/bin/env bash
set -euo pipefail
NS=monitoring
REL=k8s-monitoring
echo "Usuwam ServiceMonitor(y) w default (jeśli są)…"
kubectl -n default delete servicemonitor thesis-app --ignore-not-found
echo "Helm uninstall $REL…"
helm uninstall "$REL" -n "$NS" || true
echo "Usuwam CRD operatora (opcjonalnie, gdy chcesz totalny reset)…"
kubectl delete crd alertmanagers.monitoring.coreos.com podmonitors.monitoring.coreos.com \
  probes.monitoring.coreos.com prometheuses.monitoring.coreos.com \
  prometheusrules.monitoring.coreos.com servicemonitors.monitoring.coreos.com \
  thanosrulers.monitoring.coreos.com --ignore-not-found
echo "Usuwam namespace $NS…"
kubectl delete ns "$NS" || true
echo "Done."
