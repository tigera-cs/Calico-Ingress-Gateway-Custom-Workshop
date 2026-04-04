#!/bin/bash
echo "=== Cleaning up UC3 (mTLS) ==="

kubectl delete gateway mtls-gateway -n default --ignore-not-found
kubectl delete clienttrafficpolicy mtls-optional-policy -n default --ignore-not-found
kubectl delete httproute mtls-route -n uc3-custom --ignore-not-found
kubectl delete namespace uc3-custom --ignore-not-found

# Optional: Clean certificates
kubectl delete secret terminate-example-tls-cert -n default --ignore-not-found
kubectl delete configmap client-ca-cert -n default --ignore-not-found

echo "UC3 cleanup completed."