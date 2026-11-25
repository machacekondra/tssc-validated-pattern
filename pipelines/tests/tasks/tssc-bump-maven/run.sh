#!/usr/bin/env bash
set -euo pipefail

KUBECTL_CONTEXT="${KUBECTL_CONTEXT:-}"
INTEGRATION_NAMESPACE="${INTEGRATION_NAMESPACE:-cve-remediation-it}"

if [[ -z "$KUBECTL_CONTEXT" ]]; then
  printf 'Set KUBECTL_CONTEXT to the Kubernetes context to test.\n' >&2
  exit 2
fi

if ! command -v kubectl >/dev/null 2>&1; then
  printf 'Required command not found: kubectl\n' >&2
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$repo_root"

kubectl --context "$KUBECTL_CONTEXT" create namespace "$INTEGRATION_NAMESPACE" \
  --dry-run=client \
  --output=yaml \
  | kubectl --context "$KUBECTL_CONTEXT" apply --filename -

kubectl --context "$KUBECTL_CONTEXT" --namespace "$INTEGRATION_NAMESPACE" apply \
  --filename pipelines/tasks/tssc-bump-maven.yaml
kubectl --context "$KUBECTL_CONTEXT" --namespace "$INTEGRATION_NAMESPACE" apply \
  --filename pipelines/tests/tasks/tssc-bump-maven/pipeline.yaml

run_name="$(kubectl --context "$KUBECTL_CONTEXT" --namespace "$INTEGRATION_NAMESPACE" create \
  --filename pipelines/tests/tasks/tssc-bump-maven/pipelinerun.yaml \
  --output=jsonpath='{.metadata.name}')"

cleanup() {
  if [[ -n "$run_name" ]]; then
    kubectl --context "$KUBECTL_CONTEXT" --namespace "$INTEGRATION_NAMESPACE" delete \
      pipelinerun "$run_name" --ignore-not-found --wait=true >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

printf 'Running PipelineRun %s in namespace %s on context %s\n' \
  "$run_name" "$INTEGRATION_NAMESPACE" "$KUBECTL_CONTEXT"
show_failure_details() {
  kubectl --context "$KUBECTL_CONTEXT" --namespace "$INTEGRATION_NAMESPACE" describe \
    "pipelinerun/$run_name" || true
  kubectl --context "$KUBECTL_CONTEXT" --namespace "$INTEGRATION_NAMESPACE" get \
    taskruns,pods -o wide || true
  while IFS= read -r pod; do
    kubectl --context "$KUBECTL_CONTEXT" --namespace "$INTEGRATION_NAMESPACE" logs \
      "$pod" --all-containers=true || true
  done < <(kubectl --context "$KUBECTL_CONTEXT" --namespace "$INTEGRATION_NAMESPACE" \
    get pods --output=name)
}

deadline=$((SECONDS + 600))
while (( SECONDS < deadline )); do
  status="$(kubectl --context "$KUBECTL_CONTEXT" --namespace "$INTEGRATION_NAMESPACE" get \
    "pipelinerun/$run_name" --output=jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}')"
  case "$status" in
    True)
      printf 'tssc-bump-maven integration test passed.\n'
      exit 0
      ;;
    False)
      printf 'tssc-bump-maven integration test failed.\n' >&2
      show_failure_details
      exit 1
      ;;
  esac
  sleep 5
done

printf 'Timed out waiting for PipelineRun %s.\n' "$run_name" >&2
show_failure_details
exit 1
