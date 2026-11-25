# Kind, kubectl, Kubernetes node image, and Tekton versions used by the local
# and GitHub Actions integration-test bootstrap.
KIND_VERSION ?= v0.33.0
KUBECTL_VERSION ?= v1.37.0
KIND_NODE_IMAGE ?= kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5
TEKTON_PIPELINES_VERSION ?= v1.18.0

KIND_CLUSTER_NAME ?= ssc-demo-integration
KIND_PROVIDER ?= docker
INTEGRATION_NAMESPACE ?= cve-remediation-it
INTEGRATION_BIN_DIR ?= /tmp/ssc-demo-integration/bin
KUBECTL_CONTEXT ?=

.PHONY: kind-integration-install-tools kind-integration-bootstrap kind-integration-test kind-integration-down integration-test

## Install pinned Kind and kubectl binaries under INTEGRATION_BIN_DIR.
kind-integration-install-tools:
	@KIND_VERSION="$(KIND_VERSION)" \
	 KUBECTL_VERSION="$(KUBECTL_VERSION)" \
	 INTEGRATION_BIN_DIR="$(INTEGRATION_BIN_DIR)" \
	 GITHUB_PATH="$(GITHUB_PATH)" \
	 bash pipelines/tests/kind/install-tools.sh

## Create the isolated Kind cluster and install upstream Tekton Pipelines.
kind-integration-bootstrap:
	@PATH="$(INTEGRATION_BIN_DIR):$$PATH" \
	 KIND_CLUSTER_NAME="$(KIND_CLUSTER_NAME)" \
	 KIND_PROVIDER="$(KIND_PROVIDER)" \
	 KIND_NODE_IMAGE="$(KIND_NODE_IMAGE)" \
	 TEKTON_PIPELINES_VERSION="$(TEKTON_PIPELINES_VERSION)" \
	 INTEGRATION_NAMESPACE="$(INTEGRATION_NAMESPACE)" \
	 bash pipelines/tests/kind/bootstrap.sh up

## Run the provider-neutral tssc-bump-maven integration test on the Kind cluster.
kind-integration-test: KUBECTL_CONTEXT = kind-$(KIND_CLUSTER_NAME)
kind-integration-test: integration-test

## Run the provider-neutral tssc-bump-maven integration test on KUBECTL_CONTEXT.
integration-test:
	@if [[ -z "$(KUBECTL_CONTEXT)" ]]; then \
	  printf 'Set KUBECTL_CONTEXT to the Kubernetes context to test.\n' >&2; \
	  exit 2; \
	fi
	@PATH="$(INTEGRATION_BIN_DIR):$$PATH" \
	 KUBECTL_CONTEXT="$(KUBECTL_CONTEXT)" \
	 INTEGRATION_NAMESPACE="$(INTEGRATION_NAMESPACE)" \
	 bash pipelines/tests/tasks/tssc-bump-maven/run.sh

## Delete only the Kind cluster used by these integration checks.
kind-integration-down:
	@PATH="$(INTEGRATION_BIN_DIR):$$PATH" \
	 KIND_CLUSTER_NAME="$(KIND_CLUSTER_NAME)" \
	 KIND_PROVIDER="$(KIND_PROVIDER)" \
	 bash pipelines/tests/kind/bootstrap.sh down
