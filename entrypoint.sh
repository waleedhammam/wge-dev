#!/bin/bash
export KUBECONFIG=/etc/gitops/value
export CLUSTER_NAME="temp"

echo "generating keys"
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
echo "generate success"

echo "creating secret on the cluster"
gpg --export-secret-keys --armor "${KEY_FP}" | \
kubectl create secret generic sops-gpg \
--namespace=flux-system \
--from-file=sops.asc=/dev/stdin \

echo "creating success"

echo "deleting secret key"
gpg --batch --yes --delete-secret-keys  "${KEY_FP}"
echo "deleted"

kubectl get gitrepository flux-system -n flux-system -o jsonpath="{.spec.url}" > /tmp/repo.url
kubectl get kustomization my-secrets -n flux-system -o -o jsonpath="{.spec.path}" > /tmp/path.url

cat /tmp/repo.url | git clone && cd "$_"
cat /tmp/path.url | cd

cat <<EOF > ./.sops.yaml
creation_rules:
  - path_regex: .*.yaml
    encrypted_regex: ^(data|stringData)$
    pgp: ${KEY_FP}
EOF

gpg --export --armor "${KEY_FP}" > ./.sops.pub.asc

rm /tmp/repo.url /tmp/path.url

git checkout -b cluster-${CLUSTER_NAME}
git add .
git commit -m "add public key and sops configuration" --quiet
git push --quiet

echo "Setup complete"