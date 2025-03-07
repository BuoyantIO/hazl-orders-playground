#!/bin/bash
# cluster-setup-k3d-basic.sh
# Demo script for the hazl-orders-playground GitHub repository
# https://github.com/BuoyantIO/hazl-orders-playground
# Automates cluster creation and Linkerd installation
# Tom Dean | Buoyant
# Last edit: 3/6/2025

# Let's set some variables!

# BEL: Stable
BEL_VERSION=enterprise-2.17.1
#BEL_VERSION=enterprise-2.16.3
#BEL_VERSION=enterprise-2.15.7
CLI_VERSION=install

# BEL: Preview
#BEL_VERSION=preview-25.1.2
#CLI_VERSION=install-preview

# Viz Version
VIZ_VERSION=edge-25.1.2

# Create the k3d clusters

k3d cluster delete hazl-orders-playground
k3d cluster create -c cluster-k3d/hazl-orders-playground-k3d-calico.yaml --wait
k3d image import hatoo/oha:latest -c hazl-orders-playground
k3d cluster list

# Configure the kubectl context

kubectx -d hazl
kubectx hazl=k3d-hazl-orders-playground
kubectx hazl
kubectx

# Create fresh root certificates for mTLS

cd certs
rm -f *.{crt,key}
step certificate create root.linkerd.cluster.local ca.crt ca.key \
--profile root-ca --no-password --insecure
step certificate create identity.linkerd.cluster.local issuer.crt issuer.key \
--profile intermediate-ca --not-after 8760h --no-password --insecure \
--ca ca.crt --ca-key ca.key
ls -la
cd ..

# Read in license, Buoyant Cloud and cluster name information from the settings.sh file

source settings.sh

# Install the CLI

curl https://enterprise.buoyant.io/$CLI_VERSION | $LINKERD2_VERSION sh
export PATH=~/.linkerd2/bin:$PATH
linkerd version

# Perform pre-installation checks

linkerd check --pre --context=hazl

# Install Buoyant Enterprise Linkerd Operator and Buoyant Cloud Agents using Helm
# Debug metrics are enabled to use the Buoyant Cloud Grafana instance

helm repo add linkerd-buoyant https://helm.buoyant.cloud
helm repo update

helm install linkerd-buoyant \
  --create-namespace \
  --namespace linkerd-buoyant \
  --kube-context hazl \
  --set metadata.agentName=$CLUSTER_NAME \
  --set api.clientID=$API_CLIENT_ID \
  --set api.clientSecret=$API_CLIENT_SECRET \
  --set metrics.debugMetrics=true \
  --set agent.logLevel=debug \
  --set metrics.logLevel=debug \
linkerd-buoyant/linkerd-buoyant

# Monitor the Buoyant Cloud metrics rollout

kubectl rollout status daemonset/buoyant-cloud-metrics -n linkerd-buoyant --context=hazl
linkerd buoyant check --context hazl

# Create linkerd-identity-issuer secret using root certificates

cat <<EOF > linkerd-identity-secret.yaml
apiVersion: v1
data:
  ca.crt: $(base64 < certs/ca.crt | tr -d '\n')
  tls.crt: $(base64 < certs/issuer.crt| tr -d '\n')
  tls.key: $(base64 < certs/issuer.key | tr -d '\n')
kind: Secret
metadata:
  name: linkerd-identity-issuer
  namespace: linkerd
type: kubernetes.io/tls
EOF

kubectl apply -f linkerd-identity-secret.yaml --context=hazl

kubectl get secrets  -n linkerd --context=hazl

# Create and apply Control Plane CRDs to trigger BEL Operator
# This will create the Control Plane on both clusters
# Press CTRL-C to exit each watch command

cat <<EOF > linkerd-control-plane-config-hazl.yaml
apiVersion: linkerd.buoyant.io/v1alpha1
kind: ControlPlane
metadata:
  name: linkerd-control-plane
spec:
  components:
    linkerd:
      version: $BEL_VERSION
      license: $BUOYANT_LICENSE
      controlPlaneConfig:
        proxy:
          image:
            version: $BEL_VERSION
          additionalEnv:
            - name: BUOYANT_BALANCER_LOAD_LOW
              value: "0.6"
            - name: BUOYANT_BALANCER_LOAD_HIGH
              value: "1.3"
        identityTrustAnchorsPEM: |
$(sed 's/^/          /' < certs/ca.crt )
        identity:
          issuer:
            scheme: kubernetes.io/tls
        destinationController:
          additionalArgs:
            #- -ext-endpoint-zone-weights
EOF

kubectl apply -f linkerd-control-plane-config-hazl.yaml --context=hazl

watch -n 1 kubectl get pods -A -o wide --sort-by .metadata.namespace --context=hazl

# Run a Linkerd check after creating Control Planes

linkerd check --context hazl

# Create the Data Plane for the linkerd-buoyant namespace

cat <<EOF > linkerd-data-plane-config.yaml
---
apiVersion: linkerd.buoyant.io/v1alpha1
kind: DataPlane
metadata:
  name: linkerd-buoyant
  namespace: linkerd-buoyant
spec:
  workloadSelector:
    matchLabels: {}
EOF

kubectl apply -f linkerd-data-plane-config.yaml --context=hazl

# Monitor the status of the rollout of the Buoyant Cloud Metrics Daemonset

kubectl rollout status daemonset/buoyant-cloud-metrics -n linkerd-buoyant --context=hazl

# Run a proxy check

sleep 20
linkerd check --proxy -n linkerd-buoyant --context hazl

# Enable Inbound Latency Metrics
# These are disabled by default in the Buoyant Cloud Agent
# Patch with the buoyant-cloud-metrics.yaml manifest
# Restart the buoyant-cloud-metrics daemonset

kubectl apply -f manifests/buoyant-cloud-metrics.yaml --context hazl

kubectl -n linkerd-buoyant rollout restart ds buoyant-cloud-metrics --context hazl

exit 0
