#!/usr/bin/env bash
set -eux
# Applies control plane only for now

LB_IP=$1
CP_IP_1=$2

talosctl gen secrets
talosctl gen config talos-k8s-aws-tutorial https://$LB_IP.sslip.io:6443 \
    --with-examples=false \
    --with-docs=false \
    --with-secrets=./secrets.yaml \
    --install-disk /dev/vda \
    --config-patch-control-plane "
        machine:
            certSANs: [$CP_IP_1, $LB_IP]
    "
talosctl --talosconfig talosconfig config endpoint $CP_IP_1
talosctl --talosconfig talosconfig config node $CP_IP_1
talosctl --talosconfig talosconfig apply-config --insecure --nodes $CP_IP_1 --file controlplane.yaml
sleep 30
talosctl --talosconfig talosconfig bootstrap
sleep 30
#talosctl --talosconfig talosconfig apply-config --nodes $CP_IP_1 --file controlplane.yaml
talosctl --talosconfig talosconfig kubeconfig ./kubeconfig --nodes $CP_IP_1
export KUBECONFIG="$PWD/kubeconfig"
