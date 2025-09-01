#!/usr/bin/env bash
set -euo pipefail

LABEL="${1:-snapshot}"                    
NS="${NS:-default}"
APP_LABEL="${APP_LABEL:-app=thesis-app}"
DEPLOY_NAME="${DEPLOY_NAME:-thesis-app}"
HPA_NAME="${HPA_NAME:-thesis-app-hpa}"
VPA_NAME="${VPA_NAME:-thesis-app-vpa}"

for bin in kubectl; do command -v "$bin" >/dev/null || { echo "Brak narzędzia: $bin"; exit 1; }; done

TS="$(date +%Y%m%d-%H%M%S)"
OUTDIR="tests/results/${TS}/vpa-${LABEL}"
mkdir -p "${OUTDIR}"

{
  echo "timestamp: $(date -Is)"
  echo "context: $(kubectl config current-context)"
  echo "namespace: ${NS}"
  echo "label: ${LABEL}"
} > "${OUTDIR}/meta.txt"

echo "# Snapshot VPA: ${LABEL}"

kubectl -n "${NS}" get vpa "${VPA_NAME}" -o wide > "${OUTDIR}/vpa-get-wide.txt" || true
kubectl -n "${NS}" describe vpa "${VPA_NAME}" > "${OUTDIR}/vpa-describe.txt" || true
kubectl -n "${NS}" get vpa "${VPA_NAME}" -o yaml > "${OUTDIR}/vpa.yaml" || true

kubectl -n "${NS}" get vpa "${VPA_NAME}" \
  -o jsonpath='{range .status.recommendation.containerRecommendations[*]}{.containerName}{"\n"}CPU: lower={.lowerBound.cpu} target={.target.cpu} upper={.upperBound.cpu}{"\n"}MEM: lower={.lowerBound.memory} target={.target.memory} upper={.upperBound.memory}{"\n"}{end}' \
  > "${OUTDIR}/vpa-reco-summary.txt" || true

kubectl -n "${NS}" get pods -l "${APP_LABEL}" -o wide > "${OUTDIR}/pods.txt" || true
kubectl -n "${NS}" get pods -l "${APP_LABEL}" \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].resources.requests.cpu}{"\t"}{.spec.containers[0].resources.requests.memory}{"\t"}{.spec.containers[0].resources.limits.cpu}{"\t"}{.spec.containers[0].resources.limits.memory}{"\n"}{end}' \
  > "${OUTDIR}/pods-requests-limits.txt" || true

{
  echo "spec.replicas:"
  kubectl -n "${NS}" get deploy "${DEPLOY_NAME}" -o jsonpath='{.spec.replicas}'; echo
  echo "status.replicas / available:"
  kubectl -n "${NS}" get deploy "${DEPLOY_NAME}" -o jsonpath='{.status.replicas}{" / "}{.status.availableReplicas}'; echo
} > "${OUTDIR}/deploy.txt" || true

kubectl -n "${NS}" get deploy "${DEPLOY_NAME}" \
  -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{"\t"}{.resources.requests.cpu}{"\t"}{.resources.requests.memory}{"\t"}{.resources.limits.cpu}{"\t"}{.resources.limits.memory}{"\n"}{end}' \
  > "${OUTDIR}/deploy-container-resources.txt" || true

kubectl -n "${NS}" get hpa "${HPA_NAME}" -o wide > "${OUTDIR}/hpa.txt" || true
kubectl -n "${NS}" get hpa "${HPA_NAME}" -o json > "${OUTDIR}/hpa.json" || true

echo "OK: ${OUTDIR}"
