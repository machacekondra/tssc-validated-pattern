#!/usr/bin/env bash
set -euo pipefail

KIND_VERSION="${KIND_VERSION:-v0.33.0}"
KUBECTL_VERSION="${KUBECTL_VERSION:-v1.37.0}"
INTEGRATION_BIN_DIR="${INTEGRATION_BIN_DIR:-/tmp/ssc-demo-integration/bin}"

for command in curl uname; do
  if ! command -v "$command" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$command" >&2
    exit 1
  fi
done

case "$(uname -s)" in
  Darwin) os=darwin ;;
  Linux) os=linux ;;
  *)
    printf 'Unsupported operating system: %s\n' "$(uname -s)" >&2
    exit 1
    ;;
esac

case "$(uname -m)" in
  x86_64 | amd64) arch=amd64 ;;
  arm64 | aarch64) arch=arm64 ;;
  *)
    printf 'Unsupported architecture: %s\n' "$(uname -m)" >&2
    exit 1
    ;;
esac

mkdir -p "$INTEGRATION_BIN_DIR"

kind_url="https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-${os}-${arch}"
kubectl_url="https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${os}/${arch}/kubectl"

printf 'Installing Kind %s for %s/%s\n' "$KIND_VERSION" "$os" "$arch"
curl --fail --location --silent --show-error "$kind_url" -o "$INTEGRATION_BIN_DIR/kind.tmp"
chmod +x "$INTEGRATION_BIN_DIR/kind.tmp"
mv "$INTEGRATION_BIN_DIR/kind.tmp" "$INTEGRATION_BIN_DIR/kind"

printf 'Installing kubectl %s for %s/%s\n' "$KUBECTL_VERSION" "$os" "$arch"
curl --fail --location --silent --show-error "$kubectl_url" -o "$INTEGRATION_BIN_DIR/kubectl.tmp"
chmod +x "$INTEGRATION_BIN_DIR/kubectl.tmp"
mv "$INTEGRATION_BIN_DIR/kubectl.tmp" "$INTEGRATION_BIN_DIR/kubectl"

if [[ -n "${GITHUB_PATH:-}" ]]; then
  printf '%s\n' "$INTEGRATION_BIN_DIR" >> "$GITHUB_PATH"
fi

printf 'Tools installed under %s\n' "$INTEGRATION_BIN_DIR"
printf 'Make targets automatically add this directory to PATH.\n'
