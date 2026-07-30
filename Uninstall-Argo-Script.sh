#!/bin/bash
set -e

echo "=== 1. Removing Finalizers from Argo CD Resources ==="
# Prevents Argo CD from deleting your actual apps (like bankapp) when the operator is removed
kubectl get applications -n argocd -o name 2>/dev/null | xargs -I {} kubectl patch {} -n argocd --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null || true
kubectl delete applications --all -n argocd --wait=false 2>/dev/null || true

echo "=== 2. Uninstalling Helm Release ==="
helm uninstall argocd -n argocd 2>/dev/null || true

echo "=== 3. Cleaning Up Cluster-Wide Resources & CRDs ==="
# Delete CRDs (Note: This will remove all Application definitions)
kubectl delete crd applications.argoproj.io applicationsets.argoproj.io appprojects.argoproj.io appprojects.argoproj.io 2>/dev/null || true

# Clean up remaining ClusterRoles/Bindings
kubectl delete clusterrole -l app.kubernetes.io/name=argocd 2>/dev/null || true
kubectl delete clusterrolebinding -l app.kubernetes.io/name=argocd 2>/dev/null || true

echo "=== 4. Deleting Namespace ==="
kubectl delete namespace argocd --wait=true 2>/dev/null || true

echo "=== 5. Clearing Local Artifacts ==="
rm -f get_helm.sh
# Remove the ArgoCD binary if it exists in path
if command -v argocd &> /dev/null; then
    rm -f $(which argocd)
fi

echo "=================================================="
echo "        ARGO CD UNINSTALLATION COMPLETE           "
echo "=================================================="