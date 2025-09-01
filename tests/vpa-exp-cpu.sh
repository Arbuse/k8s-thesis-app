#!/usr/bin/env bash
set -euo pipefail

APP_URL="${APP_URL:-http://thesis.192.168.49.2.nip.io}"

DURATION="${DURATION:-10m}"
QPS="${QPS:-2}"
CONCURRENCY="${CONCURRENCY:-1}"
SECONDS_PARAM="${SECONDS_PARAM:-0.25}"   
WORKERS_PARAM="${WORKERS_PARAM:-1}"

for bin in curl hey; do command -v "$bin" >/dev/null || { echo "Brak narzędzia: $bin"; exit 1; }; done

TARGET="${APP_URL}/cpu?seconds=${SECONDS_PARAM}&workers=${WORKERS_PARAM}"
echo "CPU load: hey -z ${DURATION} -q ${QPS} -c ${CONCURRENCY} ${TARGET}"
hey -z "${DURATION}" -q "${QPS}" -c "${CONCURRENCY}" "${TARGET}"
