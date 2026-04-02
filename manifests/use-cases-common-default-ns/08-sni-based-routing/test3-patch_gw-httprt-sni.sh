#!/bin/bash


kubectl patch gateway sni-gateway --type=json --patch '
  - op: add
    path: /spec/listeners/1/tls/certificateRefs/-
    value:
      name: sample-cert
  '

kubectl patch httproute backend-sni --type=json --patch '
  - op: add
    path: /spec/hostnames/-
    value: www.sample.com
  '

