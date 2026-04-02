#!/bin/bash

openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -subj '/O=example Inc./CN=example.com' -keyout example.com.key -out example.com.crt

sleep 2
openssl req -out terminate.example.com.csr -newkey rsa:2048 -nodes -keyout terminate.example.com.key -subj "/CN=terminate.example.com/O=some organization"

sleep 2
openssl x509 -req -sha256 -days 365 -CA example.com.crt -CAkey example.com.key -set_serial 0 -in terminate.example.com.csr -out terminate.example.com.crt

sleep 2
kubectl create secret tls terminate-example-tls-cert --key=terminate.example.com.key --cert=terminate.example.com.crt

echo "Done!"
