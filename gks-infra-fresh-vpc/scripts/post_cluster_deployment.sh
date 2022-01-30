#!/bin/bash

if [ "$TF_ACTION" = "apply -auto-approve" ] ; 
then
# aws sts get-caller-identity

aws eks update-kubeconfig --profile tenant --name $TF_VAR_cluster_name --region $TF_VAR_region
cat /root/.kube/config || true
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl

./kubectl get node,ns || true
./kubectl get ing,po,svc,rolebindings -A || true
./kubectl describe cm aws-auth -n kube-system || true
#POD=$(./kubectl -n kube-system get pod -l job-name=kube-bench -o jsonpath="{.items[0].metadata.name}")
#./kubectl -n kube-system logs $POD

fi

# pwd
# ls -ltr
# chmod +x scripts/argocd_installation.sh
# ./scripts/argocd_installation.sh admin_password developer_password ingress_hostname
