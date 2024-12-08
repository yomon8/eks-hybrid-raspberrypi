FROM mcr.microsoft.com/vscode/devcontainers/base:0-bullseye

# amd64 or arm64
ARG ARCH=amd64

# Options
ARG UPGRADE_PACKAGES="false"
ARG USE_MOBY="true"
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN apt update && apt install -y \
    bash-completion \
    dnsutils \
    fzf \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* /tmp/library-scripts/

# AWS CLI v2のインストール
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf ./awscliv2.zip ./aws

# Terraformのインストール
ARG TF_VERSION=1.10.1
RUN curl https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_${ARCH}.zip -o "terraform.zip" \
    && unzip ./terraform.zip terraform -d /usr/local/bin/ && rm -rf ./terraform.zip

# Packerのインストール
ARG PACKER_VERSION=1.11.2
RUN curl https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_${ARCH}.zip -o "packer.zip" \
    && unzip ./packer.zip packer -d /usr/local/bin/ && rm -rf ./packer.zip

# kubectlのインストール
ENV K8S_VERSION=v1.31.3
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl" && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl.sha256" && \
    echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm -f kubectl

# HELMのインストール
RUN wget https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    && chmod 700 get-helm-3 \
    && ./get-helm-3 \
    && rm -rf ./get-helm-3

