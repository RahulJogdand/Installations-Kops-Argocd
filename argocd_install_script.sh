#!/bin/bash
set -e

echo "=== 1. Installing Helm ==="
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
helm version

echo "=== 2. Installing Argo CD via Helm ==="
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
helm install argocd argo/argo-cd --namespace argocd

echo "=== 3. Waiting for Argo CD Server Pod to be Ready ==="
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

echo "=== 4. Exposing Argo CD Server via LoadBalancer ==="
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Ensure jq is installed
if ! command -v jq &> /dev/null; then
    yum install -y jq
fi

echo "=== 5. Extracting Connection Credentials ==="
# FIX 1: Use command substitution $(...) instead of literal quotes
export ARGO_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# FIX 2: Wait for AWS LoadBalancer hostname allocation & capture IP/Hostname properly
echo "Waiting for LoadBalancer hostname to provision..."
ARGOCD_SERVER=""
while [ -z "$ARGOCD_SERVER" ]; do
    sleep 5
    ARGOCD_SERVER=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    # Fallback for clusters using IP instead of hostname
    if [ -z "$ARGOCD_SERVER" ]; then
        ARGOCD_SERVER=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    fi
done

export ARGOCD_SERVER

echo "=================================================="
echo "          ARGO CD INSTALLATION COMPLETE           "
echo "=================================================="
echo "URL:      https://${ARGOCD_SERVER}"
echo "Username: admin"
echo "Password: ${ARGO_PWD}"
echo "=================================================="
