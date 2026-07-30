#!/bin/bash
set -e

echo "=== 1. Creating 'argocd' Namespace ==="
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

echo "=== 2. Applying Argo CD Manifests (Server-Side) ==="
kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "=== 3. Waiting for Argo CD Server Pod to be Ready ==="
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

echo "=== 4. Exposing Argo CD Server via NodePort ==="
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'

echo "=== 5. Installing Argo CD CLI ==="
if ! command -v argocd &> /dev/null; then
    echo "Downloading argocd binary..."
    curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    chmod +x /usr/local/bin/argocd
    echo "Argo CD CLI installed successfully."
else
    echo "Argo CD CLI is already installed."
fi

echo "=================================================="
echo "          ARGO CD INSTALLATION COMPLETE           "
echo "=================================================="

ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
NODE_PORT=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')

if [ -z "$NODE_IP" ]; then
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
fi

echo "URL:      https://${NODE_IP}:${NODE_PORT}"
echo "Username: admin"
echo "Password: ${ADMIN_PASSWORD}"
echo "=================================================="