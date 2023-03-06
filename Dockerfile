FROM ubuntu:22.04

RUN apt-get update && apt-get -y install --no-install-recommends git curl gnupg openssl ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download sops & move to binarys & make it executable 
RUN curl -LOC - https://github.com/mozilla/sops/releases/download/v3.7.3/sops-v3.7.3.linux.amd64 && \
    mv sops-v3.7.3.linux.amd64 /usr/bin/sops && \
    chmod +x /usr/bin/sops &&\
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" &&\
    mv kubectl /usr/bin/kubectl && \
    chmod +x /usr/bin/kubectl

# # Configure git to push public key in repo 
# RUN git config --global user.name 'Weaveworks bootstrap' && \
#     git config --global user.email 'bootstrap@weaveworks.com'

COPY ./entrypoint.sh /root/entrypoint.sh

ENTRYPOINT bash "/root/entrypoint.sh"
