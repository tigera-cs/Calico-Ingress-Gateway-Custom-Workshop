#!/bin/bash
NS=uc3-custom
kubectl delete gateway mtls-gateway -n default
kubectl delete httproute mtls-route -n $NS --ignore-not-found
kubectl delete envoypatchpolicy forward-client-cert -n default --ignore-not-found
kubectl delete secret terminate-example-tls-cert client-ca-cert -n default
rm server.crt server.key ca.crt ca.key client.crt client.key client.csr
kubectl delete ns $NS


