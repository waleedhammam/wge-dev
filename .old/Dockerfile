FROM ubuntu:22.04

ARG SOPS_VERSION="v3.7.3"

RUN apt-get update && apt-get -y install --no-install-recommends git curl gnupg openssl ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download sops & move to binarys & make it executable 
RUN curl -LOC - https://github.com/mozilla/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.amd64 && \
    mv sops-${SOPS_VERSION}.linux.amd64 /usr/bin/sops && \
    chmod +x /usr/bin/sops &&\
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" &&\
    mv kubectl /usr/bin/kubectl && \
    chmod +x /usr/bin/kubectl

# install github cli to create a pull request
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install gh -y

# Configure git to push public key in repo 
RUN git config --global user.name 'Weaveworks bootstrap' && \
    git config --global user.email 'bootstrap@weaveworks.com'

COPY ./entrypoint.sh /root/entrypoint.sh

ENTRYPOINT bash "/root/entrypoint.sh"
