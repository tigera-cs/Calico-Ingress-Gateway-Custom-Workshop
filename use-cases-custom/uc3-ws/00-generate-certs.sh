# A. Generate Gateway Server Certificate
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 \
  -subj '/CN=terminate.example.com/O=Example Inc.' \
  -keyout server.key -out server.crt

kubectl create secret tls terminate-example-tls-cert \
  --key=server.key --cert=server.crt

# B. Generate Client CA and Client Certificate
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 \
  -subj '/CN=ExampleClientCA/O=Example Inc.' \
  -keyout ca.key -out ca.crt

openssl req -newkey rsa:2048 -nodes -keyout client.key \
  -subj '/CN=my-client/O=Example Inc.' -out client.csr

openssl x509 -req -sha256 -days 365 -in client.csr \
  -CA ca.crt -CAkey ca.key -set_serial 01 -out client.crt

# Create CA secret for Gateway validation
kubectl create secret generic client-ca-cert --from-file=ca.crt=ca.crt