#!/bin/bash

set -e

CERT_MANAGER_NAMESPACE="cert-manager"
ARGOCD_NAMESPACE="argocd"
CLUSTER_ISSUER_NAME="root-ca-cluster-issuer"
CERT_NAME="kind-local-cert"
CUSTOM_DOMAIN="kind.local.kubesoar.com"
DNSMASQ_CONFIG_FILE="/etc/dnsmasq.d/${CUSTOM_DOMAIN}.conf"
ROOT_CA_PATH="$HOME/.ssl/root-ca"

# Ensure Cert-Manager is installed
if ! kubectl get ns ${CERT_MANAGER_NAMESPACE} &>/dev/null; then
    echo "Cert-Manager is not installed. Exiting..."
    exit 1
fi

# Calculate MetalLB IP range
KIND_NET_CIDR=$(docker network inspect kind -f '{{(index .IPAM.Config 0).Subnet}}')
KIND_NET_BASE=$(echo "${KIND_NET_CIDR}" | awk -F'.' '{print $1"."$2"."$3}')
METALLB_IP_START="${KIND_NET_BASE}.200"
METALLB_IP_END="${KIND_NET_BASE}.254"
METALLB_IP_RANGE="${METALLB_IP_START}-${METALLB_IP_END}"

echo "Configuring MetalLB with IP range ${METALLB_IP_RANGE}..."
kubectl apply -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  namespace: metallb-system
  name: default-address-pool
spec:
  addresses:
  - ${METALLB_IP_RANGE}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  namespace: metallb-system
  name: default
EOF

echo "Creating ClusterIssuer for Root CA..."
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ${CLUSTER_ISSUER_NAME}
spec:
  ca:
    secretName: root-ca-secret
EOF

echo "Creating Kubernetes Secret for Root CA..."
kubectl create secret tls root-ca-secret \
  --namespace ${CERT_MANAGER_NAMESPACE} \
  --cert=${ROOT_CA_PATH}/root-ca.pem \
  --key=${ROOT_CA_PATH}/root-ca-key.pem \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Creating Certificate for ${CUSTOM_DOMAIN} in ${CERT_MANAGER_NAMESPACE}, reflecting to ${ARGOCD_NAMESPACE}..."
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ${CERT_NAME}
  namespace: ${CERT_MANAGER_NAMESPACE}
spec:
  secretName: ${CERT_NAME}-tls
  duration: 8760h # 1 year
  renewBefore: 720h # 30 days
  issuerRef:
    name: ${CLUSTER_ISSUER_NAME}
    kind: ClusterIssuer
  commonName: ${CUSTOM_DOMAIN}
  dnsNames:
    - ${CUSTOM_DOMAIN}
  secretTemplate:
    annotations:
      reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
      reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces: "${ARGOCD_NAMESPACE}"
      reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
      reflector.v1.k8s.emberstack.com/reflection-auto-namespaces: "${ARGOCD_NAMESPACE}"
EOF

# Retrieve the Contour Ingress LoadBalancer IP
echo "Retrieving Contour LoadBalancer IP..."
LB_IP=$(kubectl get svc -n projectcontour my-contour-envoy -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [[ -z "${LB_IP}" ]]; then
    echo "Failed to retrieve Contour LoadBalancer IP. Falling back to MetalLB pool."
    LB_IP="${METALLB_IP_START}"
fi


# Update dnsmasq configuration
echo "Configuring dnsmasq for ${CUSTOM_DOMAIN}..."
echo "address=/${CUSTOM_DOMAIN}/${LB_IP}" | sudo tee "${DNSMASQ_CONFIG_FILE}" > /dev/null

# Restart dnsmasq
echo "Restarting dnsmasq..."
sudo systemctl restart dnsmasq

echo "Setup complete. ${CUSTOM_DOMAIN} is now mapped to ${LB_IP}."
