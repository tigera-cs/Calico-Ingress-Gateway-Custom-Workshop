#!/bin/bash

kubectl delete service terminate-echoserver
kubectl delete deployment terminate-echoserver
kubectl delete gateway tls-terminate-gateway
kubectl delete TLSRoute tls-terminate
kubectl delete secret server-certs

