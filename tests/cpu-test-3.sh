#!/usr/bin/env bash
set -euo pipefail

NAME="cpu-test-3"
APP_URL="${APP_URL:-http://thesis.192.168.49.2.nip.io}"
HPA_NAME="${HPA_NAME:-thesis-app-hpa}"

DURATION="${DURATION:-2m}"
QPS="${QPS:-20}"
CONCURRENCY="${CONCURRENCY:-20}"

SECONDS_PARAM="${SECONDS_PARAM:-3}"
WORKERS_PARAM="${WORKERS_PARAM:-4}"

TS="$(date +%Y%m%d-%H%M%S)"
OUTDIR="tests/results/${TS}/${NAME}"
mkdir -p "${OUTDIR}"


curl -fsS "${APP_URL}/" >/dev/null
curl -fsS "${APP_URL}/metrics" | head -n 5 || true

echo "${OUTDIR}/hpa-initial.txt"
kubectl get hpa "${HPA_NAME}" -o wide > "${OUTDIR}/hpa-initial.txt" || true

echo "(background): ${OUTDIR}/hpa-watch.log"
kubectl get hpa "${HPA_NAME}" -w > "${OUTDIR}/hpa-watch.log" 2>&1 &
HPA_WATCH_PID=$!

cleanup() {
  if ps -p "${HPA_WATCH_PID}" >/dev/null 2>&1; then
    kill "${HPA_WATCH_PID}" || true
  fi
}
trap cleanup EXIT

TARGET="${APP_URL}/cpu?seconds=${SECONDS_PARAM}&workers=${WORKERS_PARAM}"
echo "hey: ${DURATION}, qps=${QPS}, c=${CONCURRENCY}"
echo "${TARGET}"
hey -z "${DURATION}" -q "${QPS}" -c "${CONCURRENCY}" "${TARGET}" | tee "${OUTDIR}/hey.txt"

sleep 10
