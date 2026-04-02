#!/bin/bash

kubectl delete service backend-sni
kubectl delete deployment backend-sni
kubectl delete gateway sni-gateway
kubectl delete HTTPRoute backend-sni
kubectl delete secret example-cert sample-cert

