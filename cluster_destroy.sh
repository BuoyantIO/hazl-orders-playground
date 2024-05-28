#!/bin/bash
# cluster_destroy.sh
# Demo script for the hazl-orders-playground GitHub repository
# https://github.com/BuoyantIO/hazl-orders-playground
# Automates cluster deletion and cleans up the hazl kubectl context
# Tom Dean | Buoyant
# Last edit: 5/28/2024

# Remove the k3d cluster

k3d cluster delete demo-cluster-orders-hazl
k3d cluster list

# Remove the kubectl context

kubectx -d hazl
kubectx

exit 0