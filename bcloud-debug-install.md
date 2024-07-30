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