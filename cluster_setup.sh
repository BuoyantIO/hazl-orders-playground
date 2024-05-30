#!/bin/bash
# cluster_setup.sh
# Demo script for the hazl-orders-playground GitHub repository
# https://github.com/BuoyantIO/hazl-orders-playground
# Automates cluster creation, Linkerd installation and installs the Orders application
# Tom Dean | Buoyant
# Last edit: 5/29/2024

# Let's set some variables!

# BEL: Stable
BEL_VERSION=enterprise-2.15.3
CLI_VERSION=install

# BEL: Preview
# BEL_VERSION=preview-24.5.4
# CLI_VERSION=install-preview

# Create the k3d clusters

k3d cluster delete demo-cluster-orders-hazl
k3d cluster create -c cluster/demo-cluster-orders-hazl.yaml --wait
k3d image import hatoo/oha:latest -c demo-cluster-orders-hazl
k3d cluster list

# Configure the kubectl context

kubectx -d hazl
kubectx hazl=k3d-demo-cluster-orders-hazl
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

curl https://enterprise.buoyant.io/$CLI_VERSION | sh
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
  --set metadata.agentName=$CLUSTER1_NAME \
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

# Install Grafana

helm repo add grafana https://grafana.github.io/helm-charts
helm install grafana -n grafana --create-namespace grafana/grafana \
  -f grafana_values.yaml

# Install Linkerd Viz to Enable Success Rate Metrics

linkerd viz install --set grafana.url=grafana.grafana:3000 --set linkerdVersion=stable-2.14.10 --context hazl | kubectl apply -f - --context hazl

# Create the Data Plane for the linkerd-viz namespace

cat <<EOF > linkerd-data-plane-viz-config.yaml
---
apiVersion: linkerd.buoyant.io/v1alpha1
kind: DataPlane
metadata:
  name: linkerd-viz
  namespace: linkerd-viz
spec:
  workloadSelector:
    matchLabels: {}
EOF

kubectl apply -f linkerd-data-plane-viz-config.yaml --context=hazl

# Grant viz Prometheus access to Grafana, need to add an AuthorizationPolicy pointing to its ServiceAccount

kubectl apply -f authzpolicy-grafana.yaml

# Port forward the Grafana dashboard to localhost:3000
#
#export POD_NAME=$(kubectl get pods --namespace grafana -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=grafana" -o jsonpath="{.items[0].metadata.name}") ; kubectl --namespace grafana port-forward $POD_NAME 3000 > /dev/null 2>&1 &

# Create the grafana-ingress Ingress

kubectl apply -f grafana-ingress.yaml --context hazl

# Enable Inbound Latency Metrics
# These are disabled by default in the Buoyant Cloud Agent
# Patch with the buoyant-cloud-metrics.yaml manifest
# Restart the buoyant-cloud-metrics daemonset

kubectl apply -f buoyant-cloud-metrics.yaml --context hazl

kubectl -n linkerd-buoyant rollout restart ds buoyant-cloud-metrics --context hazl

# Deploy the Orders application to both clusters
# Press CTRL-C to exit each watch command

kubectl apply -k orders --context=hazl

watch -n 1 kubectl get pods -n orders -o wide --sort-by .spec.nodeName --context=hazl

# Deploy the Data Plane for the orders namespace

cat <<EOF > linkerd-data-plane-orders-config.yaml
---
apiVersion: linkerd.buoyant.io/v1alpha1
kind: DataPlane
metadata:
  name: linkerd-orders
  namespace: orders
spec:
  workloadSelector:
    matchLabels: {}
EOF

kubectl apply -f linkerd-data-plane-orders-config.yaml --context=hazl

exit 0
