#!/bin/bash
# cluster-setup-k3d-naked.sh
# Demo script for the hazl-orders-playground GitHub repository
# https://github.com/BuoyantIO/hazl-orders-playground
# Automates cluster creation, certificate creation but no Linkerd installation
# Tom Dean | Buoyant
# Last edit: 7/29/2024

# Let's set some variables!

# BEL: Stable
BEL_VERSION=enterprise-2.15.5
CLI_VERSION=install

# BEL: Preview
#BEL_VERSION=preview-24.7.4
#CLI_VERSION=install-preview

# Create the k3d clusters

k3d cluster delete hazl-orders-playground
k3d cluster create -c cluster-k3d/hazl-orders-playground-k3d.yaml
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
