#!/usr/bin/env bash
set -euo pipefail

if kubectl get crd verticalpodautoscalers.autoscaling.k8s.io >/dev/null 2>&1; then
  echo "[INFO] CRD VPA już istnieje – pomijam instalację kontrolerów."
else
  echo "[INFO] Instaluję VPA (CRD + kontrolery) z oficjalnego repo..."
  TMPDIR="$(mktemp -d)"
  trap 'rm -rf "$TMPDIR"' EXIT
  git clone --depth 1 --branch vpa-release-1.4 https://github.com/kubernetes/autoscaler.git "$TMPDIR/autoscaler"
  pushd "$TMPDIR/autoscaler/vertical-pod-autoscaler" >/dev/null
    ./hack/vpa-up.sh
  popd >/dev/null
fi

echo "[INFO] Stosuję k8s/vpa.yaml (UpdateMode: Off/Auto w zależności od pliku)..."
kubectl apply -f k8s/vpa.yaml

echo "[INFO] Sprawdzam komponenty VPA i obiekt VPA:"
kubectl get pods -n kube-system | grep -E 'vpa|vertical-pod-autoscaler' || true
kubectl get vpa -n default || true
