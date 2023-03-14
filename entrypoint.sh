#!/bin/bash
export KUBECONFIG=/etc/gitops/value

echo "=> generating keys"
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
echo "=> generate success"

echo "=> creating secret on the cluster"
gpg --export-secret-keys --armor "${KEY_FP}" | \
kubectl create secret generic ${SOPS_SECRET_REF} \
--namespace=flux-system \
--from-file=sops.asc=/dev/stdin
echo "=> creating success"

echo "=> deleting secret key"
gpg --batch --yes --delete-secret-keys  "${KEY_FP}"
echo "=> deleted"

echo "=> pushing config and pub key to the repo"

export CLUSTER_PATH="clusters/${CLUSTER_NAMESPACE}/${CLUSTER_NAME}"
git clone https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${GITHUB_REPO}.git && cd ${GITHUB_REPO}/${CLUSTER_PATH}
mkdir sops && cd sops

cat <<EOF > ./.sops.yaml
creation_rules:
  - path_regex: .*.yaml
    encrypted_regex: ^(data|stringData)$
    pgp: ${KEY_FP}
EOF
gpg --export --armor "${KEY_FP}" > ./.sops.pub.asc

git checkout -b sops-${CLUSTER_NAME}
git add .
git commit -m "add public key and sops configuration" --quiet
git push --set-upstream origin sops-${CLUSTER_NAME}
git push --quiet
echo "=> pushed"

echo "=> Setup complete"