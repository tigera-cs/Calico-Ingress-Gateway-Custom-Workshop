#!/bin/bash
echo "=== Cleaning up UC1 (Keep-Alive + Long Timeout) ==="

kubectl delete gateway keepalive-timeout-gateway -n default --ignore-not-found
kubectl delete clienttrafficpolicy client-keepalive-policy -n default --ignore-not-found
kubectl delete backendtrafficpolicy backend-timeout-policy -n uc1-custom --ignore-not-found
kubectl delete httproute keepalive-timeout-route -n uc1-custom --ignore-not-found
kubectl delete namespace uc1-custom --ignore-not-found

echo "UC1 cleanup completed."