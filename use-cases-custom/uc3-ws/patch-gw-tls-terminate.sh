#!/bin/bash

kubectl patch gateway tls-passthrough-gateway --type=json --patch '
  - op: add
    path: /spec/listeners/-
    value:
      name: tls
      protocol: TLS
      hostname: terminate.example.com
      port: 443
      tls:
        mode: Terminate
  '

