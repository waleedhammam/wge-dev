#!/bin/bash
echo """%no-protection
Key-Type: 1
Key-Length: 4096
Subkey-Type: 1
Subkey-Length: 4096
Expire-Date: 0
Name-Comment: ${KEY_COMMENT}
Name-Real: ${KEY_NAME}
""" > /tmp/key-config

cat /tmp/key-config | gpg --batch --full-generate-key

export KEY_FP=$(gpg --list-secret-keys "${KEY_NAME}" | sed -n "2 p" |  sed 's/^ *//g')

kubectl create namespace flux-system --kubeconfig=/etc/gitops/value || true

gpg --export-secret-keys --armor "${KEY_FP}" | \
kubectl create secret generic sops-gpg \
--namespace=flux-system \
--from-file=sops.asc=/dev/stdin \
--kubeconfig=/etc/gitops/value

# delete secret key
gpg --batch --yes --delete-secret-keys  "${KEY_FP}"

cat <<EOF > ./.sops.yaml
creation_rules:
  - path_regex: .*.yaml
    encrypted_regex: ^(data|stringData)$
    pgp: ${KEY_FP}
EOF

gpg --export --armor "${KEY_FP}" > ./.sops.pub.asc

echo "Setup complete"