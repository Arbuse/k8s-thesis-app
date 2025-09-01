#!/usr/bin/env bash
set -euo pipefail

NAME="cpu-test-2"
APP_URL="${APP_URL:-http://thesis.192.168.49.2.nip.io}"
HPA_NAME="${HPA_NAME:-thesis-app-hpa}"

DURATION="${DURATION:-120s}"
QPS="${QPS:-3}"
CONCURRENCY="${CONCURRENCY:-1}"

SECONDS_PARAM="${SECONDS_PARAM:-0.025}"
WORKERS_PARAM="${WORKERS_PARAM:-1}"

for bin in kubectl curl hey; do command -v "$bin" >/dev/null || { echo "Brak: $bin"; exit 1; }; done

TS="$(date +%Y%m%d-%H%M%S)"
OUTDIR="tests/results/${TS}/${NAME}"
mkdir -p "${OUTDIR}"

curl -fsS "${APP_URL}/" >/dev/null
kubectl get hpa "${HPA_NAME}" -o wide > "${OUTDIR}/hpa-initial.txt" || true

stdbuf -oL kubectl get hpa "${HPA_NAME}" -w | awk '{ print strftime("%H:%M:%S"), $0 }' > "${OUTDIR}/hpa-watch.log" 2>&1 &
HPA_WATCH_PID=$!; trap 'kill ${HPA_WATCH_PID} 2>/dev/null || true' EXIT

TARGET="${APP_URL}/cpu?seconds=${SECONDS_PARAM}&workers=${WORKERS_PARAM}"

(
  while sleep 5; do
    r=$(kubectl get hpa "${HPA_NAME}" -o jsonpath='{.status.currentReplicas}' 2>/dev/null || echo 0)
    if [ "${r}" -gt 3 ]; then
      echo "Próg 3 replik przekroczony — przerwanie testu średniego." | tee "${OUTDIR}/guard.txt"
      pkill -P $$ hey || true
      break
    fi
  done
) & GUARD_PID=$!

hey -z "${DURATION}" -q "${QPS}" -c "${CONCURRENCY}" "${TARGET}" | tee "${OUTDIR}/hey.txt" || true
kill "${GUARD_PID}" 2>/dev/null || true

sleep 5
kubectl get hpa "${HPA_NAME}" -o wide > "${OUTDIR}/hpa-final.txt" || true
echo "OK: ${OUTDIR}"
