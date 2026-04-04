#!/bin/bash
echo "=== Cleaning up UC2 (Sticky Sessions) ==="

kubectl delete gateway sticky-gateway -n default --ignore-not-found
kubectl delete clienttrafficpolicy client-sticky-policy -n default --ignore-not-found
kubectl delete backendtrafficpolicy backend-sticky-policy -n uc2-custom --ignore-not-found
kubectl delete httproute sticky-session-route -n uc2-custom --ignore-not-found
kubectl delete namespace uc2-custom --ignore-not-found

echo "UC2 cleanup completed."