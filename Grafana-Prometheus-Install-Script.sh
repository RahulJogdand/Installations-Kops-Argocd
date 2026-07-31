#!/usr/bin/env bash
set -euo pipefail

# ==========================================
# CONFIGURATION VARIABLES
# ==========================================
GRAFANA_PASSWORD="Root123456"

echo "--> Step 1: Checking cluster connectivity..."
kubectl cluster-info

# ==========================================
# 2. INSTALL KUBERNETES METRICS SERVER
# ==========================================
echo "--> Step 2: Installing Kubernetes Metrics Server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/high-availability-1.21+.yaml

# ==========================================
# 3. ADD HELM REPOSITORIES
# ==========================================
echo "--> Step 3: Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# ==========================================
# 4. INSTALL PROMETHEUS
# ==========================================
echo "--> Step 4: Installing Prometheus..."
kubectl create namespace prometheus --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install prometheus prometheus-community/prometheus \
  --namespace prometheus \
  --set alertmanager.persistentVolume.storageClass="gp2" \
  --set server.persistentVolume.storageClass="gp2"

# ==========================================
# 5. INSTALL GRAFANA
# ==========================================
echo "--> Step 5: Installing Grafana..."
kubectl create namespace grafana --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install grafana grafana/grafana \
  --namespace grafana \
  --set persistence.storageClassName="gp2" \
  --set persistence.enabled=true \
  --set adminPassword="${GRAFANA_PASSWORD}" \
  --set service.type=LoadBalancer

# ==========================================
# 6. SUMMARY OUTPUT
# ==========================================
echo "=========================================================="
echo "MONITORING SETUP COMPLETE!"
echo "=========================================================="
echo "Checking Grafana Service Status..."
kubectl get service -n grafana grafana

echo ""
echo "NOTE: It may take 2-3 minutes for AWS to assign a public LoadBalancer DNS."
echo "Run the command below to retrieve your Grafana URL:"
echo "  kubectl get svc -n grafana grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
echo ""
echo "Grafana Credentials:"
echo "  Username: admin"
echo "  Password: ${GRAFANA_PASSWORD}"
echo "=========================================================="