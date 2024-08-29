#!/bin/bash
# cluster-setup-k3d-naked-calico.sh
# Demo script for the hazl-orders-playground GitHub repository
# https://github.com/BuoyantIO/hazl-orders-playground
# Automates cluster creation, certificate cretion but no Linkerd installation
# Tom Dean | Buoyant
# Last edit: 8/22/2024

# Let's set some variables!

# BEL: Stable
BEL_VERSION=enterprise-2.16.0
CLI_VERSION=install

# BEL: Preview
#BEL_VERSION=preview-24.8.2
#CLI_VERSION=install-preview

# Create the k3d clusters

k3d cluster delete hazl-orders-playground
k3d cluster create -c cluster-k3d/hazl-orders-playground-k3d-calico.yaml --volume "$(pwd)/manifests/calico.yaml:/var/lib/rancher/k3s/server/manifests/calico.yaml" --verbose --wait
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

exit 0
