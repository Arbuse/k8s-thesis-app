#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Usuwam obiekt VPA dla thesis-app..."
kubectl delete -f k8s/vpa.yaml --ignore-not-found

echo "[INFO] (Opcjonalnie) Jeśli chcesz usunąć CAŁY mechanizm VPA z klastra:"
echo "  cd ~/Desktop/autoscaler/vertical-pod-autoscaler && ./hack/vpa-down.sh"
