# A. Generate Gateway Server Certificate
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 \
  -subj '/CN=terminate.example.com/O=Example Inc.' \
  -keyout server.key -out server.crt

kubectl create secret tls terminate-example-tls-cert \
  --key=server.key --cert=server.crt

