#!/usr/bin/env bash
set -euo pipefail
NAME="slow-test-3"
APP_URL="${APP_URL:-http://thesis.$(minikube ip).nip.io}"
HPA_NAME="${HPA_NAME:-thesis-app-hpa}"

DURATION="${DURATION:-120s}"
QPS="${QPS:-3}"
CONCURRENCY="${CONCURRENCY:-10}"
SECONDS_PARAM="${SECONDS_PARAM:-3}"   
WORKERS_PARAM="${WORKERS_PARAM:-1}"

for b in kubectl curl hey; do command -v "$b" >/dev/null || { echo "Brak: $b"; exit 1; }; done
TS="$(date +%Y%m%d-%H%M%S)"; OUTDIR="tests/results/${TS}/${NAME}"; mkdir -p "$OUTDIR"

curl -fsS "${APP_URL}/" >/dev/null
kubectl get hpa "$HPA_NAME" -o wide > "${OUTDIR}/hpa-initial.txt" || true
stdbuf -oL kubectl get hpa "$HPA_NAME" -w | awk '{print strftime("%H:%M:%S"),$0}' > "${OUTDIR}/hpa-watch.log" 2>&1 & W=$!
trap 'kill $W 2>/dev/null || true' EXIT

TARGET="${APP_URL}/slow?seconds=${SECONDS_PARAM}"
hey -z "${DURATION}" -q "${QPS}" -c "${CONCURRENCY}" "${TARGET}" | tee "${OUTDIR}/hey.txt" || true
sleep 5
kubectl get hpa "$HPA_NAME" -o wide > "${OUTDIR}/hpa-final.txt" || true
echo "OK: ${OUTDIR}"
