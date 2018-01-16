# Create the CA configuration file
cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

# Create the CA certificate signing request
cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Oregon"
    }
  ]
}
EOF

# Generate the CA certificate and private key
cfssl gencert -initca ca-csr.json | cfssljson -bare ca

# Create the admin client certificate signing request
cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:masters",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

# Generate the admin client certificate and private key
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin

# Generate a certificate and private key for each Kubernetes worker node
# for instance in worker-0 worker-1 worker-2; do
counter=1
while [ $counter -le $WORKER_COUNT ]
do
  instance="k8s-worker-$counter"
  cat > ${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

  EXTERNAL_IP=$(cat ../hosts | grep ${instance} | cut -d" " -f1)

  cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -hostname=${instance},${EXTERNAL_IP} \
    -profile=kubernetes \
    ${instance}-csr.json | cfssljson -bare ${instance}

  ((counter++))
done

# Create the kube-proxy client certificate signing request
cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

# Generate the kube-proxy client certificate and private key
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy

# Retrieve the kubernetes-the-hard-way static IP address
# This is the floating ip we create with CoroSync and Pacemaker
KUBERNETES_PUBLIC_ADDRESS="192.160.50.10"

# Create the Kubernetes API Server certificate signing request
cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

HOSTNAMES=$(cat ../hosts | cut -d" " -f1 | tr '\n' ',')
HOSTNAMES=${HOSTNAMES::-1}

# Generate the Kubernetes API Server certificate and private key
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=$HOSTNAMES,10.32.0.1,10.240.0.10,10.240.0.11,10.240.0.12,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,kubernetes.default \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes

# Copy the appropriate certificates and private keys to each worker instance
#for instance in worker-0 worker-1 worker-2; do
#  scp ca.pem ${instance}-key.pem ${instance}.pem ${instance}:~/
#done

# Copy the appropriate certificates and private keys to each controller instance
#for instance in controller-0 controller-1 controller-2; do
#  scp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem ${instance}:~/
#done
