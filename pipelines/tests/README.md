# Kind integration-test environment

This directory contains the reusable Kind bootstrap for Tekton integration
tests. It creates an isolated Kind cluster, installs upstream Tekton Pipelines,
and prepares the `cve-remediation-it` namespace. It does not install the
OpenShift Pipelines Operator or the wider demo platform.

## Requirements

- A working Docker or Podman runtime, `make`, and network access to download
  Kind, kubectl, and Tekton images.
- At least 2 CPUs and enough memory for the Kind node and Tekton controllers.

## Start and remove the cluster

```sh
make kind-integration-install-tools
make kind-integration-bootstrap
make kind-integration-down
```

The bootstrap uses the pinned Kind release and Kubernetes node image configured
in the Makefile. It installs the pinned upstream Tekton Pipelines release, uses
Kind's default `standard` StorageClass, and restores the previous active
kubectl context after bootstrapping.

The cluster name, Kind provider, node image, Tekton version, and namespace can
be changed through Make variables. For example:

```sh
make kind-integration-bootstrap KIND_CLUSTER_NAME=ssc-demo-local KIND_PROVIDER=docker
make kind-integration-down KIND_CLUSTER_NAME=ssc-demo-local
```

Kind supports Docker, Podman, and nerdctl. To use Podman, pass it when creating
and deleting the cluster:

```sh
make kind-integration-bootstrap KIND_PROVIDER=podman
make kind-integration-down KIND_PROVIDER=podman
```

Podman installations may need additional host setup for Kind. The bootstrap
does not switch the active context. To activate the default Kind cluster
manually, run:

```sh
kubectl config use-context kind-ssc-demo-integration
```

The GitHub Actions workflow runs this bootstrap on every pull request and
deletes the Kind cluster afterward.
