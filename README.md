# HAZL | Orders Playground

## hazl-orders-playground

### Tom Dean | Buoyant

### Last edit: 7/30/2024

## Introduction

This repository has quick-start steps to deploy **Buoyant Enterprise for Linkerd** in a `k3d` cluster, and enable **High Availability Zonal Load Balancing (HAZL)** in that cluster.  The cluster also has `linkerd-viz` and a self-contained instance of Grafana deployed which is accessible on [http://localhost:9999](http://localhost:9999), or outside the system at `http://<<hostname or IP>>:9999`.  The Grafana instance deploys with a set of OSS Linkerd Grafana dashboards, plus there's a `dashboards` directory with JSON dashboard files that can be imported to Grafana.

## High Availability Zonal Load Balancing (HAZL)

**High Availability Zonal Load Balancing (HAZL)** is a dynamic request-level load balancer in **Buoyant Enterprise for Linkerd** that balances **HTTP** and **gRPC** traffic in environments with **multiple availability zones**. For Kubernetes clusters deployed across multiple zones, **HAZL** can **dramatically reduce cloud spend by minimizing cross-zone traffic**.

Unlike other zone-aware options that use **Topology Hints** (including **Istio** and open source **Linkerd**), **HAZL** _never sacrifices reliability to achieve this cost reduction_.

In **multi-zone** environments, **HAZL** can:

- **Cut cloud spend** by eliminating cross-zone traffic both within and across cluster boundaries;
- **Improve system reliability** by distributing traffic to additional zones as the system comes under stress;
- **Prevent failures before they happen** by quickly reacting to increases in latency before the system begins to fail.
- **Preserve zone affinity for cross-cluster calls**, allowing for cost reduction in multi-cluster environments.

Like **Linkerd** itself, **HAZL** is designed to _"just work"_. It works without operator involvement, can be applied to any Kubernetes service that speaks **HTTP** / **gRPC** regardless of the number of endpoints or distribution of workloads and traffic load across zones, and in the majority of cases _requires no tuning or configuration_.

For more information, click [here](more-hazl.md).

## Playground: Prerequisites

**You're going to need the following:**

- [Docker](https://docs.docker.com/get-docker/)
- [Helm](https://helm.sh/docs/intro/install/)
- [k3d](https://k3d.io)
- [step](https://smallstep.com/docs/step-cli/installation/)
- [oha conatiner image in your Docker image repo](https://github.com/hatoo/oha)
- The `kubectl` command must be installed and working
- The `watch` command must be installed and working, if you want to use it
- The `kubectx` command must be installed and working, if you want to use it
- [Buoyant Enterprise for Linkerd License](https://enterprise.buoyant.io)
- [The Playground Assets, from GitHub](https://github.com/BuoyantIO/hazl-orders-playground)

All prerequisites must be _installed_ and _working properly_ before proceeding. The instructions in the provided links will get you there. A trial license for Buoyant Enterprise for Linkerd can be obtained from [here](https://enterprise.buoyant.io).

## Playground: Included Assets

The top-level contents of the repository looks something like this:

```bash
.
├── README.md
├── certs                                    <-- Directory for the TLS root certificates (empty)
├── cluster-k3d                              <-- The k3d cluster configuration files live here
├── cluster-kind                             <-- The kind cluster configuration files live here **UNDER DEVELOPMENT**
├── cluster-the-hard-way.md                  <-- Instructions on how to manually stand up the clusters - _(needs some updates)_
├── dashboards                               <-- Grafana dashboard JSON files
├── images                                   <-- Images for the markdown docs
├── manifests
│   ├── authzpolicy-grafana.yaml
│   ├── buoyant-cloud-metrics.yaml
│   ├── calico.yaml
│   ├── ext-services.yaml
│   ├── grafana-dashboard-configmap.yaml
│   ├── grafana-values.yaml
│   ├── hazl-orders-playground-ingress.yaml
│   ├── slow_cooker.yaml                     <-- Manifest for slow_cooker, to generate some additional traffic, if desired
│   └── sp-orders.yaml                       <-- Manifest for the Orders ServiceProfile
├── more-hazl.md                             <-- More information on HAZL
├── orders -> orders-oha-bb/orders-hpa
├── orders-colorwheel                        <-- The Orders application, uses Colorwheel
│   ├── orders-hpa                           <-- The Orders application, with Horizontal Pod Autoscaling
│   ├── orders-nohpa                         <-- The Orders application, without Horizontal Pod Autoscaling
│   ├── warehouse-config-120ms.yaml          <-- Manifest to configure 120ms of latency in Chicago warehouse
│   ├── warehouse-config-80ms.yaml           <-- Manifest to configure 80ms of latency in Chicago warehouse
│   └── warehouse-config.yaml                <-- Manifest to reset warehouse configuration
├── orders-oha-bb                            <-- The Orders application, uses oha/bb
│   ├── orders-hpa                           <-- The Orders application, with Horizontal Pod Autoscaling
│   └── orders-nohpa                         <-- The Orders application, without Horizontal Pod Autoscaling
├── scripts                                  <-- For more details, see the Automation section in the README
│   ├── cluster-destroy-k3d.sh
│   ├── cluster-setup-k3d-basic-calico.sh
│   ├── cluster-setup-k3d-basic.sh
│   ├── cluster-setup-k3d-calico.sh
│   ├── cluster-setup-k3d-naked-calico.sh
│   ├── cluster-setup-k3d-naked.sh
│   ├── cluster-setup-k3d-bcloud.sh
│   ├── cluster-setup-k3d.sh
│   └── traffic-check.sh
└── testing-oha-bb
    ├── failure-chicago                      <-- Manifests to induce failure in the Chicago warehouse
    │   ├── warehouse-chicago-hazl-bb-100-fail.yaml
    │   ├── warehouse-chicago-hazl-bb-25-fail.yaml
    │   ├── warehouse-chicago-hazl-bb-50-fail.yaml
    │   └── warehouse-chicago-hazl-bb-75-fail.yaml
    └── latency-oakland                      <-- Manifests to induce latency in the Oakland warehouse
        ├── warehouse-oakland-hazl-bb-1000ms-latency.yaml
        ├── warehouse-oakland-hazl-bb-400ms-latency.yaml
        ├── warehouse-oakland-hazl-bb-600ms-latency.yaml
        └── warehouse-oakland-hazl-bb-800ms-latency.yaml
```

## Playground: Automation

The repository contains the following automation in the `scripts` directory:

- `cluster-setup-k3d.sh`
  - Script to stand up the cluster, deploy BEL, Grafana and the Orders app, no BCloud
- `cluster-setup-k3d-bcloud.sh`
  - Script to stand up the cluster, deploy BEL, Grafana and the Orders app, with BCloud and debug metrics
- `cluster-setup-k3d-basic.sh`
  - Script to stand up the cluster, install Linkerd, no BCloud
- `cluster-setup-k3d-calico.sh`
  - Script to stand up the cluster with Calico, install Linkerd and Orders, no BCloud
- `cluster-setup-k3d-naked.sh`
  - Script to stand up the cluster, no Linkerd or Orders app
- `cluster-setup-k3d-basic-calico.sh`
  - Script to stand up the cluster with Calico, install Linkerd, no BCloud
- `cluster-setup-k3d-naked-calico.sh`
  - Script to stand up the cluster with Calico, no Linkerd or Orders app
- `cluster-destroy-k3d.sh`
  - Script to destroy the cluster environment, all variants
- `traffic-check.sh`
  - Script to monitor application traffic.

Run the scripts from the root of the repository directory, like this: `./scripts/cluster-setup-k3d.sh`.

If you choose to use the scripts, make sure you've created the `settings.sh` file in the root of the repository directory and run `source settings.sh` to set your environment variables.  See the next section for more detail on the `settings.sh` file.

## Obtain Buoyant Enterprise for Linkerd (BEL) Trial Credentials and Log In to Buoyant Cloud, if Needed

If you require credentials for accessing **Buoyant Enterprise for Linkerd**, [sign up here](https://enterprise.buoyant.io), and follow the instructions.

You should end up with a set of credentials in environment variables like this:

```bash
export API_CLIENT_ID=[CLIENT_ID]           <--- Only if using Buoyant Cloud
export API_CLIENT_SECRET=[CLIENT_SECRET]   <--- Only if using Buoyant Cloud
export BUOYANT_LICENSE=[LICENSE]           <--- You will definitely need this
```

Add these to a file in the root of the `linkerd-demos/demo-orders` directory, named `settings.sh`, plus add a new line with the cluster name, `export CLUSTER_NAME=hazl-orders-playground`, like this:

```bash
export API_CLIENT_ID=[CLIENT_ID]           <--- Only if using Buoyant Cloud
export API_CLIENT_SECRET=[CLIENT_SECRET]   <--- Only if using Buoyant Cloud
export BUOYANT_LICENSE=[LICENSE]           <--- You will definitely need this
export CLUSTER_NAME=hazl-orders-playground <--- You will definitely need this
```

Check the contents of the `settings.sh` file:

```bash
more settings.sh
```

Once you're satisfied with the contents, `source` the file, to load the variables:

```bash
source settings.sh
```

**OPTIONAL:** If you're using Buoyant Cloud (you will need access to this, not included in the Community account), open an additional browser window or tab, and log in to **[Buoyant Cloud](https://buoyant.cloud)**.  Make sure you use the `cluster-setup-k3d-bcloud.sh` script as it installs and configures the Buoyant Cloud agent.

## Playground: `k3d` Cluster Configurations

This repository contains six `k3d` cluster configuration files (three with Calico and three without) and two soft links:

```bash
cluster-k3d
├── hazl-orders-playground-k3d-calico.yaml -> hazl-orders-playground-k3d-small-calico.yaml
├── hazl-orders-playground-k3d-large-calico.yaml
├── hazl-orders-playground-k3d-large.yaml
├── hazl-orders-playground-k3d-medium-calico.yaml
├── hazl-orders-playground-k3d-medium.yaml
├── hazl-orders-playground-k3d-small-calico.yaml
├── hazl-orders-playground-k3d-small.yaml
└── hazl-orders-playground-k3d.yaml -> hazl-orders-playground-k3d-small.yaml
```

By default, the soft links point to the small-size clusters, but you can delete and re-create the links to point to the larger configurations if you wish.

## Playground: `kind` Cluster Configurations

This repository contains three `kind` cluster configuration files:

```bash
cluster-kind
├── hazl-orders-playground-kind-large.yaml
├── hazl-orders-playground-kind-medium.yaml
└── hazl-orders-playground-kind-small.yaml
```

The `kind` cluster configurations are under development and not used at this point.

## Buoyant Cloud: Grafana Dashboard

![The Grafana Dashboard](images/grafana-dashboard-setup-desired.png)

A key component of the playground is the Grafana dashboard.  This provides a number of key metrics, including same and cross-AZ traffic, latency, success rate and requests for both the orders and warehouse deployments.

**A deeper dive into the Grafana Dashboard can be found [here](./dashboard.md).**

The full [JSON model](dashboards/hazl-dashboard-gui.json) for the dashboard.  You can copy the contents of this file and import the dashboard into Grafana.

### How to Import the Grafana Dashboard

Log into [Grafana](https://localhost:9999).

Go to the Dashboards, as shown below.

![Grafana Dashboards](images/grafana-dashboards-far.png)



That's it!  You have your dashboard.

## The Orders Application

This repository includes the **Orders** application, which generates traffic across multiple availability zones in our Kubernetes cluster, allowing us to observe the effect that **High Availability Zonal Load Balancing (HAZL)** has on traffic.  The repository includes two versions of the application, one based on the [Colorwheel](https://github.com/BuoyantIO/colorwheel) application and [orders-app-oha-bb](https://github.com/BuoyantIO/orders-app-oha-bb), based on `oha`/`bb`.

```bash
.
├── orders -> orders-oha-bb/orders-hpa
├── orders-colorwheel
│   ├── orders-hpa
│   └── orders-nohpa
└── orders-oha-bb
    ├── orders-hpa
    └── orders-nohpa
```

Each directory contains:

```bash
.
├── kustomization.yaml
├── ns.yaml
├── orders-central.yaml
├── orders-east.yaml
├── orders-west.yaml
├── server.yaml
├── warehouse-boston.yaml
├── warehouse-chicago.yaml
└── warehouse-oakland.yaml
```

For each version, two copies of the Orders application exist:

- `orders-hpa`: HAZL version of the orders app with Horizontal Pod Autoscaling
- `orders-nohpa`: HAZL version of the orders app without Horizontal Pod Autoscaling

The `hpa` version of the application, `orders` is soft-linked to `orders-app-oha-bb/orders-hpa`.

More information on [oha](https://github.com/hatoo/oha) and [bb](https://github.com/BuoyantIO/bb).

More information on the [Colorwheel](https://github.com/BuoyantIO/colorwheel) application.

## IMPORTANT! Building the `oha` Load Generator Container Image

_You will need build the container image for the `oha` load generator for the `orders-*` deployments._  The `cluster-setup-*.sh` scripts will import the `hatoo/oha:latest` container image from Docker for you, *but it has to be in the Docker container registry first*.

[oha](https://github.com/hatoo/oha)

### Step 1: Clone the `oha` GitHub Repository

Clone the repository to your machine:

```bash
git clone https://github.com/hatoo/oha.git
```

Change directory:

```bash
cd oha
```

### Step 2: Build the `oha` Container Image

```bash
docker build . -t hatoo/oha:latest
```

Check your work:

```bash
docker images
```

You should see the `hatoo/oha:latest` container image.

If you're going to use the container image in `k3d` and not use the `cluster_setup.sh` script, you will need to run `k3d image import hatoo/oha:latest -c CLUSTER_NAME` after creating your cluster to import the `hatoo/oha:latest` container image.

## Deploy Two Kubernetes Clusters With Buoyant Enterprise for Linkerd

First, we'll deploy our Kubernetes cluster using `k3d` with Buoyant Enterprise for Linkerd (BEL).

### Task 1: Clone the `hazl-orders-playground` Assets

[GitHub: HAZL | Orders Playground](https://github.com/BuoyantIO/hazl-orders-playground)

To get the resources we will be using in this demonstration, you will need to clone a copy of the GitHub `BuoyantIO/hazl-orders-playground` repository.

Clone the `BuoyantIO/hazl-orders-playground` GitHub repository to your preferred working directory:

```bash
git clone https://github.com/BuoyantIO/hazl-orders-playground.git
```

Change directory to the `hazl-orders-playground` directory:

```bash
cd hazl-orders-playground
```

Taking a look at the contents of `hazl-orders-playground`:

```bash
ls -la
```

With the assets in place, we can proceed to creating our cluster using `k3d`.

### Task 2: Deploy Our Kubernetes Cluster Using `k3d`

Before we can deploy **Buoyant Enterprise for Linkerd**, we're going to need a Kubernetes cluster. Fortunately, we can use the included automation for that.  If you'd like to do things the hard way, click [here](cluster-the-hard-way.md).

Deploy the cluster, using the script:

```bash
./cluster_setup.sh
```

You'll hit a few instances of the `watch` command in the script to monitor deployments.  When the deployment completes, use `CTRL-C` to exit that instance of the `watch` command.

That's it!  Everything should be ready for you to start exploring HAZL.

## How to Manipulate the Environments

Describe how different things work.

### Triggering Failures in the Chicago Warehouse

There are two manifests that, when applied, increase latency in the Chicago warehouse from 200ms to 800ms and configure percent failures to 100.

To apply:

```bash
kubectl apply -f warehouse-chicago-hazl-bb-fail.yaml --context hazl ; kubectl apply -f warehouse-chicago-topo-bb-fail.yaml --context topo
```

### Enabling/Disabling Retries



Enable Retries:

```bash
kubectl apply -f sp-orders.yaml --context hazl ; kubectl apply -f sp-orders.yaml --context topo
```

Disable Retries:

```bash
kubectl delete -f sp-orders.yaml --context hazl ; kubectl delete -f sp-orders.yaml --context topo
```



### Enabling/Disabling Circuit Breakers


Enable Circuit Breakers:

```bash
kubectl annotate -n orders svc/fulfillment balancer.linkerd.io/failure-accrual=consecutive --context hazl ; kubectl annotate -n orders svc/fulfillment balancer.linkerd.io/failure-accrual=consecutive --context hazl --overwrite
```

Disable Circuit Breakers:

```bash
kubectl annotate -n orders svc/fulfillment balancer.linkerd.io/failure-accrual=consecutive- --overwrite --context hazl ; kubectl annotate -n orders svc/fulfillment balancer.linkerd.io/failure-accrual=consecutive- --overwrite --context topo
```

### Checking For Endpoint Slices



```bash
kubectl get endpointslices -n orders --context=topo -o yaml | more
```


### Scale the Number of Requests Per `orders` Deployment - _Colorwheel-based Orders_

The request rate is set in the following configmaps:

- orders-central-config: Configures the `orders-central` deployment
- orders-east-config: Configures the `orders-east` deployment
- orders-west-config: Configures the `orders-west` deployment

```yaml
data:
  config.yml: |
    requestsPerSecond: 50
```

Scaling the request rate in the `orders` deployments can increase/decrease traffic. By default, the setting is `requestsPerSecond: 50`. Remember, this is the request rate _per deployment_, so with the default 1 replica, this yields 50 requests per second.  If you scale the `orders` deployments, the total number of requests per second is _replicas x `requestsPerSecond`_.

So, if you want to change the request rate for the `orders-central` deployment, on the `hazl` cluster:

```bash
kubectl edit -n orders cm/orders-central-config --context=hazl
```

Save and exit, then restart the deployment:

```bash
kubectl rollout restart -n orders deploy orders-central --context=hazl
```

### Scale the Number of Replicas Per Deployment

Scaling the `orders` and `warehouse` deployments provides a quick and easy way to change the traffic volume and distribution.

#### Deployment: Orders

```bash
kubectl scale -n orders deploy orders-west --replicas=20 --context=hazl
```

#### Deployment: Warehouse

```bash
kubectl scale -n orders deploy warehouse-oakland --replicas=0 --context=hazl
```

### Increase Latency in the Warehouses - _Colorwheel-based Orders_

Another good way to test is by introducing latency.  You can edit the warehouse configuration by editing the `warehouse-config` configmap. Latency can be adjusted via adjusting the `averageResponseTime`.

```bash
kubectl edit -n orders cm/warehouse-config --context=hazl
```

You'll see:

```yml
data:
  blue.yml: |
    color: "#0000ff"
    averageResponseTime: 0.020
  green.yml: |
    color: "#00ff00"
    averageResponseTime: 0.020
  red.yml: |
    color: "#ff0000"
    averageResponseTime: 0.020
```

The colors map to the warehouses as follows:

- Red: The Oakland warehouse (`warehouse-oakland`)
- Blue: The Boston warehouse (`warehouse-boston`)
- Green: The Chicago warehouse (`warehouse-chicago`)

Change the value of `averageResponseTime` for the one or more warehouses. You will then need to restart those deployments to pick up the configuration change(s) for the warehouse(s).

```bash
kubectl rollout restart -n orders deploy warehouse-chicago --context=hazl
```

Observe the latency graphs in the Grafana dashboard, as well as success rates and traffic.

### Reset the Orders Application to the Initial State

Sometimes it's nice to start fresh.  You can just re-apply the initial configurations:

```bash
kubectl apply -k orders --context=hazl ; kubectl apply -k orders-topo --context=topo
```

This should reset the Orders applications to their initial state.

### Delete the Orders Application

If you'd like to remove the Orders application and deploy something different, use this:

```bash
kubectl delete -k orders --context=hazl ; kubectl delete -k orders-topo --context=topo
```

Now you're ready to deploy your application(s) of choice.

### Playground: Cleanup

When you're done, you can use the included automation to clean up for you:

```bash
./cluster_destroy.sh
```

Checking our work:

```bash
k3d cluster list
```

```bash
kubectx
```

We shouldn't see any evidence of either the `hazl` or `topo` clusters.

## Summary: HAZL | Orders Playground

Summarize the entire thing here. Bullet points?
