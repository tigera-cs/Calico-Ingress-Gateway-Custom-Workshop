#!/bin/bash

kubectl delete service passthrough-echoserver
kubectl delete deployment passthrough-echoserver
kubectl delete gateway tls-passthrough-gateway
kubectl delete TLSRoute tls-passthrough
kubectl delete secret server-certs

