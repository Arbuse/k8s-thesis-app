#!/usr/bin/env bash
set -euo pipefail

NAME="cpu-test-1"
APP_URL="${APP_URL:-http://thesis.192.168.49.2.nip.io}"
HPA_NAME="${HPA_NAME:-thesis-app-hpa}"

# Parametry hey
DURATION="${DURATION:-30s}"
QPS="${QPS:-2}"
CONCURRENCY="${CONCURRENCY:-5}"

SECONDS_PARAM="${SECONDS_PARAM:-1}"
WORKERS_PARAM="${WORKERS_PARAM:-1}"

for bin in kubectl curl hey; do
  command -v "$bin" >/dev/null 2>&1 || { echo "Brak narzędzia: $bin"; exit 1; }
done

TS="$(date +%Y%m%d-%H%M%S)"
OUTDIR="tests/results/${TS}/${NAME}"
mkdir -p "${OUTDIR}"

echo "Weryfikacja aplikacji: ${APP_URL}"
curl -fsS "${APP_URL}/" >/dev/null
curl -fsS "${APP_URL}/metrics" | head -n 5 || true

echo "Zapis stanu HPA (przed): ${OUTDIR}/hpa-initial.txt"
kubectl get hpa "${HPA_NAME}" -o wide > "${OUTDIR}/hpa-initial.txt" || true

echo "Rozpoczynam obserwację HPA (watch) -> ${OUTDIR}/hpa-watch.log"
kubectl get hpa "${HPA_NAME}" -w > "${OUTDIR}/hpa-watch.log" 2>&1 &
HPA_WATCH_PID=$!

cleanup() {
  if ps -p "${HPA_WATCH_PID}" >/dev/null 2>&1; then
    kill "${HPA_WATCH_PID}" || true
  fi
}
trap cleanup EXIT

TARGET="${APP_URL}/cpu?seconds=${SECONDS_PARAM}&workers=${WORKERS_PARAM}"
echo "Start hey: duration=${DURATION}, qps=${QPS}, c=${CONCURRENCY}, target=${TARGET}"
hey -z "${DURATION}" -q "${QPS}" -c "${CONCURRENCY}" "${TARGET}" | tee "${OUTDIR}/hey.txt"

sleep 5

echo "Zapis stanu HPA (po): ${OUTDIR}/hpa-final.txt"
kubectl get hpa "${HPA_NAME}" -o wide > "${OUTDIR}/hpa-final.txt" || true

echo "output: ${OUTDIR}"
