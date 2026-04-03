# Generate the key and cert
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 \
  -subj '/CN=app.example.com/O=MyOrg' \
  -keyout app-example-tls.key -out app-example-tls.crt

# Create the Kubernetes Secret in the same namespace as the Gateway (default)
kubectl create secret tls app-example-tls-cert \
  --key=app-example-tls.key \
  --cert=app-example-tls.crt