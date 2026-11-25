#!/usr/bin/env bash
set -euo pipefail

action="${1:-up}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-ssc-demo-integration}"
KIND_PROVIDER="${KIND_PROVIDER:-docker}"

if [[ "$action" == "down" ]]; then
  if ! command -v kind >/dev/null 2>&1; then
    printf 'Kind is not installed; nothing to delete.\n'
    exit 0
  fi

  if KIND_EXPERIMENTAL_PROVIDER="$KIND_PROVIDER" kind get clusters 2>/dev/null \
    | grep -Fxq "$KIND_CLUSTER_NAME"; then
    KIND_EXPERIMENTAL_PROVIDER="$KIND_PROVIDER" kind delete cluster \
      --name "$KIND_CLUSTER_NAME"
  else
    printf 'Kind cluster %s does not exist; nothing to delete.\n' "$KIND_CLUSTER_NAME"
  fi
  exit 0
fi

if [[ "$action" != "up" ]]; then
  printf 'Usage: %s [up|down]\n' "$0" >&2
  exit 2
fi

for command in kind kubectl; do
  if ! command -v "$command" >/dev/null 2>&1; then
    printf 'Required command not found: %s (run make kind-integration-install-tools)\n' "$command" >&2
    exit 1
  fi
done

: "${KIND_NODE_IMAGE:?KIND_NODE_IMAGE must be set by the Makefile or environment}"
: "${TEKTON_PIPELINES_VERSION:?TEKTON_PIPELINES_VERSION must be set by the Makefile or environment}"
: "${INTEGRATION_NAMESPACE:?INTEGRATION_NAMESPACE must be set by the Makefile or environment}"
context="kind-${KIND_CLUSTER_NAME}"

original_context="$(kubectl config current-context 2>/dev/null || true)"
restore_context() {
  if [[ -n "$original_context" && "$original_context" != "$context" ]]; then
    kubectl config use-context "$original_context" >/dev/null 2>&1 || true
  elif [[ -z "$original_context" ]]; then
    kubectl config unset current-context >/dev/null 2>&1 || true
  fi
}
trap restore_context EXIT

if KIND_EXPERIMENTAL_PROVIDER="$KIND_PROVIDER" kind get clusters 2>/dev/null \
  | grep -Fxq "$KIND_CLUSTER_NAME"; then
  printf 'Using existing Kind cluster %s\n' "$KIND_CLUSTER_NAME"
else
  printf 'Creating Kind cluster %s with provider %s\n' "$KIND_CLUSTER_NAME" "$KIND_PROVIDER"
  KIND_EXPERIMENTAL_PROVIDER="$KIND_PROVIDER" kind create cluster \
    --name "$KIND_CLUSTER_NAME" \
    --image "$KIND_NODE_IMAGE" \
    --wait 5m
fi

kubectl --context "$context" wait --for=condition=Ready nodes --all --timeout=180s

# Kind installs a local-path provisioner and default StorageClass for the
# PipelineRun's workspace volumeClaimTemplate.
kubectl --context "$context" get storageclass standard >/dev/null

release_url="https://infra.tekton.dev/tekton-releases/pipeline/previous/${TEKTON_PIPELINES_VERSION}/release.yaml"
printf 'Installing Tekton Pipelines %s\n' "$TEKTON_PIPELINES_VERSION"
kubectl --context "$context" apply --filename "$release_url"

kubectl --context "$context" wait \
  --for='jsonpath={.status.phase}=Active' \
  --timeout=180s \
  namespace/tekton-pipelines

for crd in \
  tasks.tekton.dev \
  taskruns.tekton.dev \
  pipelines.tekton.dev \
  pipelineruns.tekton.dev; do
  kubectl --context "$context" wait \
    --for=condition=Established \
    --timeout=180s \
    "customresourcedefinition/$crd"
done

for deployment in tekton-pipelines-controller tekton-pipelines-webhook; do
  kubectl --context "$context" rollout status \
    --namespace tekton-pipelines \
    --timeout=240s \
    "deployment/$deployment"
done

kubectl --context "$context" create namespace "$INTEGRATION_NAMESPACE" \
  --dry-run=client \
  --output=yaml \
  | kubectl --context "$context" apply --filename -

printf '\nKind integration-test bootstrap is ready.\n'
printf '  cluster:   %s\n' "$KIND_CLUSTER_NAME"
printf '  context:   %s\n' "$context"
printf '  namespace: %s\n' "$INTEGRATION_NAMESPACE"
printf '  node image: %s\n' "$KIND_NODE_IMAGE"
printf '  Tekton:    %s\n' "$TEKTON_PIPELINES_VERSION"
printf 'The bootstrap does not change the active kubectl context.\n'
