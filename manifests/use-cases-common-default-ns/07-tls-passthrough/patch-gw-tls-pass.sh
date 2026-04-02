#!/bin/bash

kubectl patch gateway tls-passthrough-gateway --type=json --patch '
  - op: add
    path: /spec/listeners/-
    value:
      name: tls
      protocol: TLS
      hostname: passthrough.example.com
      port: 6443
      tls:
        mode: Passthrough
  '

