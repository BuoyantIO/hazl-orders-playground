#!/bin/bash
# cluster-destroy-k3d.sh
# Demo script for the hazl-orders-playground GitHub repository
# https://github.com/BuoyantIO/hazl-orders-playground
# Automates cluster deletion and cleans up the hazl kubectl context
# Tom Dean | Buoyant
# Last edit: 6/10/2024

# Remove the k3d cluster

k3d cluster delete hazl-orders-playground
k3d cluster list

# Remove the kubectl context

kubectx -d hazl
kubectx

echo "Cluster deleted!"

exit 0