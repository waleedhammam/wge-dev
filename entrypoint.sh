#!/bin/bash
export KUBECONFIG=/etc/gitops/value

echo "=> generate sops gpg keys"
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
echo "✅ sops keys generated successfuly"

echo "=> ensure sops secrets namespace: ${SOPS_SECRET_REF_NAMESPACE} is created"
kubectl create namespace ${SOPS_SECRET_REF_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
echo "✅ namespace available"

echo "=> create/configure sops private key secret on the cluster"
gpg --export-secret-keys --armor "${KEY_FP}" | \
kubectl create secret generic ${SOPS_SECRET_REF} \
--namespace=${SOPS_SECRET_REF_NAMESPACE} \
--from-file=sops.asc=/dev/stdin \
--dry-run=client -o yaml | kubectl apply -f -
echo "✅ creation success"

echo "=> delete sops secret key"
gpg --batch --yes --delete-secret-keys  "${KEY_FP}"
echo "✅ sops secret key is deleted"

echo "=> create/configure sops public key on the cluster"
gpg --export --armor "${KEY_FP}" | \
kubectl create secret generic ${SOPS_SECRET_REF}-pub \
--namespace=${SOPS_SECRET_REF_NAMESPACE} \
--from-file=sops.asc=/dev/stdin \
--dry-run=client -o yaml | kubectl apply -f -
echo "✅ creation success"


echo "=> create and push rbac for public key secret"
export CLUSTER_PATH="clusters/${CLUSTER_NAMESPACE}/${CLUSTER_NAME}"
git clone https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${GITHUB_REPO}.git 

cat <<EOF > ${GITHUB_REPO}/${CLUSTER_PATH}/sops-${SOPS_SECRET_REF}-rbac.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: ${SOPS_SECRET_REF_NAMESPACE}
  name: rbac-${SOPS_SECRET_REF}-pub
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["${SOPS_SECRET_REF}-pub"]
  verbs: ["list", "get"]
EOF

git add -A
git commit -m "add public key rbac and sops configuration" --quiet
git pull --rebase && git push --quiet
echo "✅ rbac created and pushed to git"

if [[ $PUSH_TO_GIT == true ]]; then
  echo "=> push sops creation rules and public key to git"
  cd ${GITHUB_REPO}/${CLUSTER_PATH} && mkdir sops && cd sops
  cat <<EOF > ./.sops.yaml
creation_rules:
  - path_regex: .*.yaml
    encrypted_regex: ^(data|stringData)$
    pgp: ${KEY_FP}
EOF

  gpg --export --armor "${KEY_FP}" > ./.sops.pub.asc
  git checkout -b sops-${CLUSTER_NAME}
  git add .
  git commit -m "add public key" --quiet
  git push --set-upstream origin sops-${CLUSTER_NAME}
  git push --quiet
  gh pr create --title "sops public key for cluster ${CLUSTER_NAME}" --body "added sops public key for cluster ${CLUSTER_NAME}"
  echo "✅ pushed"
else
  echo "✖️ not pushing to public key to git"
fi

echo "✅ Setup complete"