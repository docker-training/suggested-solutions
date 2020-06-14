#!/bin/bash

create_env () {
   
# Creating testing namespace
kubectl create namespace testing

# Creating testing-role
kubectl apply -f - << EOF
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: tester
  namespace: testing
rules:
- apiGroups: ["", "batch", "autoscaling", "extensions", "apps",]
  resources:
  - "statefulsets"
  - "horizontalpodautoscalers"
  - "jobs"
  - "replicationcontrollers"
  - "services"
  - "deployments"
  - "replicasets"
  - "pods"
  - "pods/attach"
  - "pods/log"
  - "pods/exec"
  - "pods/proxy"
  - "pods/portforward"
  verbs:  ["*"]
EOF

# Creating role binding
kubectl apply -f - << EOF
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: tester-binding
  namespace: testing
subjects:
- kind: Group
  name: testers
  apiGroup: ""
roleRef:
  kind: Role
  name: tester
  apiGroup: ""
EOF

}

create_user () {

# Retrieving cluster CA cert
mkdir -p ~/users/bob && cd ~/users/bob
awk '/certificate-authority-data:/{print $2}' ~/.kube/config | base64 -d > ca.crt

# Generate x509 CSR for bob
touch ~/.rnd && openssl genrsa -out bob.key 2048
openssl req -new -key bob.key -out bob.csr -subj "/CN=bob/O=mirantis/O=testers"

# Request the CSR to be signed
kubectl apply -f - << EOF
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: bob_csr
spec:
  groups:
  - system:authenticated
  request: $(cat bob.csr | base64 | tr -d '\n')
  usages:
  - digital signature
  - key encipherment
  - client auth
EOF

# Approve CSR
kubectl certificate approve bob_csr
kubectl get csr bob_csr -o jsonpath='{.status.certificate}' | base64 -d > bob.crt

# Create Linux user account and copy keys and certs to account
sudo useradd -b /home -m -s /bin/bash -c "I work here" bob
echo "bob:bob" | sudo chpasswd
sudo mkdir ~bob/keys && sudo cp -a ~/users/bob/*.{key,crt} ~bob/keys
sudo chmod 400 ~bob/keys/* && sudo chown -R bob:bob ~bob/keys

}

create_cluster_env () {

# Get k8s-api
kubectl config view | grep server | cut -d: -f2,3,4 | tr -d "[:space:]" > api.txt

# Pass over k8s-api to bob
sudo cp ./api.txt /home/bob
sudo chown bob:bob /home/bob/api.txt
rm api.txt

# Assume bob and configure cluster credentials
sudo su bob -c "kubectl config set-cluster work --server=$(cat /home/bob/api.txt) --certificate-authority=/home/bob/keys/ca.crt --embed-certs=true"
sudo su bob -c "kubectl config set-credentials bob --client-certificate=/home/bob/keys/bob.crt --client-key=/home/bob/keys/bob.key"
sudo su bob -c "kubectl config set-context work --cluster=work --user=bob --namespace=testing"
sudo su bob -c "kubectl config use-context work"

echo
echo "Environment Setup Complete"
echo "User bob created and configured with kubectl privileges"
echo "---------"
echo "user: bob"
echo "pass: bob"
}

create_env
create_user
create_cluster_env

exit 0
