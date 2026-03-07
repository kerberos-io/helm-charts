FROM mcr.microsoft.com/devcontainers/go:1.25-bookworm

# Remove expired Yarn GPG key from base image
RUN sudo rm -f /etc/apt/sources.list.d/yarn.list

# Remove expired Yarn repository key (inherited from base image)
RUN sudo rm -f /etc/apt/sources.list.d/yarn.list

# Install AZURE CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install helm and kubectl
RUN curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x ./kubectl \
    && sudo mv ./kubectl /usr/local/bin/kubectl

# Install Argocd CLI
RUN VERSION=$(curl -L -s https://raw.githubusercontent.com/argoproj/argo-cd/stable/VERSION)
RUN curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/v$VERSION/argocd-linux-amd64
RUN sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
RUN rm argocd-linux-amd64

# Install google-cloud-sdk
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
RUN sudo apt-get update && sudo apt-get install -y google-cloud-cli
RUN sudo apt-get install google-cloud-cli-gke-gcloud-auth-plugin