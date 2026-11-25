# Tekton integration tests

The test resources and runner are provider-neutral. The `tssc-bump-maven` test
applies the repository Task and a test Pipeline, then runs a PipelineRun against
an explicitly selected Kubernetes context. The cluster must already have
upstream Tekton Pipelines installed and a default StorageClass for the workspace
PVC.

## Run against Kind

Requirements are a working Docker or Podman runtime, `make`, and network access
to download Kind, kubectl, Tekton, and test images.

```sh
make kind-integration-install-tools
make kind-integration-bootstrap
make kind-integration-test
make kind-integration-down
```

The bootstrap creates the `ssc-demo-integration` Kind cluster, installs the pinned
upstream Tekton Pipelines release, and prepares the `cve-remediation-it`
namespace. It uses Kind's default `standard` StorageClass for the PipelineRun
workspace. It restores the previous active kubectl context after bootstrapping.

The cluster name, Kind provider, node image, Tekton version, and namespace can
be changed through Make variables:

```sh
make kind-integration-bootstrap KIND_CLUSTER_NAME=ssc-demo-local KIND_PROVIDER=docker
make kind-integration-test KIND_CLUSTER_NAME=ssc-demo-local
make kind-integration-down KIND_CLUSTER_NAME=ssc-demo-local
```

Kind supports Docker, Podman, and nerdctl. To use Podman, select it when
creating and deleting the cluster:

```sh
make kind-integration-bootstrap KIND_PROVIDER=podman
make kind-integration-test
make kind-integration-down KIND_PROVIDER=podman
```

Podman installations may need additional host setup for Kind. The bootstrap
does not switch the active context. To make the default cluster active
manually, run:

```sh
kubectl config use-context kind-ssc-demo-integration
```

## Run against another Kubernetes cluster

The test runner takes an explicit context and does not depend on Kind or another
cluster provider. The target cluster must have Tekton Pipelines installed and a
default StorageClass that can provision the PipelineRun workspace PVC.

```sh
make integration-test KUBECTL_CONTEXT=my-kubernetes-context
```

GitHub Actions uses the same Kind bootstrap and provider-neutral test runner on
every pull request. The runner applies `tssc-bump-maven`, creates a small Maven
project in a temporary PipelineRun workspace, and checks that the dependency
version changes from `3.14.0` to `3.15.0`.
