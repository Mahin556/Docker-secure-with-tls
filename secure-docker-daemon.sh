set -eu
#set -x ; debugging

cd ~
echo "you are now in $PWD"

if [ ! -d ".docker/" ]; then
	    echo "Directory .docker does not exist"
	        echo "Creating the directory"
		    mkdir .docker
fi

cd .docker/
echo "type in your certificate password (characters are not echoed)"
read -p '>' -s PASSWORD

echo "Type in the server name or IP you’ll use to connect to the Docker server (use IP if connecting via IP)"
read -p '>' SERVER

# Generate Certificate Authority (CA) private key
openssl genrsa -aes256 -passout pass:$PASSWORD -out ca-key.pem 2048

# Generate self-signed certificate for CA
openssl req -new -x509 -days 365 -key ca-key.pem -passin pass:$PASSWORD -sha256 -out ca.pem -subj "/C=TR/ST=./L=./O=./CN=$SERVER"

# Generate server key
openssl genrsa -out server-key.pem 2048

# Create a SAN config file
cat > san.cnf <<EOF
[req]
default_bits       = 2048
distinguished_name = req_distinguished_name
req_extensions     = v3_req
prompt             = no

[req_distinguished_name]
C  = TR
ST = .
L  = .
O  = .
CN = $SERVER

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
IP.1 = $SERVER
EOF

# Create a certificate signing request using the SAN config
openssl req -new -key server-key.pem -out server.csr -config san.cnf

# Sign the server CSR with the CA using SAN extension
openssl x509 -req -days 365 -in server.csr -CA ca.pem -CAkey ca-key.pem -passin pass:$PASSWORD -CAcreateserial -out server-cert.pem -extfile san.cnf -extensions v3_req

# Generate client key
openssl genrsa -out key.pem 2048

# Generate client CSR
openssl req -subj '/CN=client' -new -key key.pem -out client.csr

# Create extension file for client authentication
echo "extendedKeyUsage = clientAuth" > extfile.cnf

# Sign the client CSR with the CA
openssl x509 -req -days 365 -in client.csr -CA ca.pem -CAkey ca-key.pem -passin pass:$PASSWORD -CAcreateserial -out cert.pem -extfile extfile.cnf

echo "Removing unnecessary files: client.csr, extfile.cnf, server.csr, san.cnf"
rm ca.srl client.csr extfile.cnf server.csr san.cnf

echo "Setting permissions for private keys (read-only by owner)"
chmod 0400 ca-key.pem key.pem server-key.pem

echo "Setting permissions for public certificates (read-only by everyone)"
chmod 0444 ca.pem server-cert.pem cert.pem

