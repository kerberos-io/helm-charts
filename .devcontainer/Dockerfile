FROM mcr.microsoft.com/devcontainers/base:bookworm

# Install common CLI tooling for Helm chart development and validation.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    jq \
    python3 \
    python3-pip \
    shellcheck \
    yq \
    && rm -rf /var/lib/apt/lists/*

# Install the latest Helm 3 release.
RUN curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install the latest stable kubectl release.
RUN KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)" \
    && curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

# Install YAML linter via pip (available as yamllint command).
RUN pip3 install --no-cache-dir yamllint

USER vscode
