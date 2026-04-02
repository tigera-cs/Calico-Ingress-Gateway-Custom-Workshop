#!/bin/bash
echo " === Generating self-signed RSA Server certificate for sample.com ==="
echo ""

openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -subj '/O=sample Inc./CN=sample.com' -keyout sample.com.key -out sample.com.crt
sleep 2

openssl req -out www.sample.com.csr -newkey rsa:2048 -nodes -keyout www.sample.com.key -subj "/CN=www.sample.com/O=sample organization"
sleep 2

openssl x509 -req -days 365 -CA sample.com.crt -CAkey sample.com.key -set_serial 0 -in www.sample.com.csr -out www.sample.com.crt
sleep 2

kubectl create secret tls sample-cert --key=www.sample.com.key --cert=www.sample.com.crt

