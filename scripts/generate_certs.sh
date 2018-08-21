
source ../cert_config.env

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
  "CN": "$CA_CERT_CN_CommonName",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "$CA_CERT_C_CountryName",
      "L": "$CA_CERT_L_Locality",
      "O": "$CA_CERT_O_Organization",
      "OU": "$CA_CERT_OU_OrganizationalUnit",
      "ST": "$CA_CERT_ST_STATE"
    }
  ]
}
EOF

# Generate the CA certificate and private key
cfssl gencert -initca ca-csr.json | cfssljson -bare ca

# Create the admin client certificate signing request
cat > admin-csr.json <<EOF
{
  "CN": "$ADMIN_CERT_CN_CommonName",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "$ADMIN_CERT_C_CountryName",
      "L": "$ADMIN_CERT_L_Locality",
      "O": "$ADMIN_CERT_O_Organization",
      "OU": "$ADMIN_CERT_OU_OrganizationalUnit",
      "ST": "$ADMIN_CERT_ST_STATE"
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
  "CN": "$WORKERS_CERT_CN_CommonName:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "$WORKERS_CERT_C_CountryName",
      "L": "$WORKERS_CERT_L_Locality",
      "O": "$WORKERS_CERT_O_Organization",
      "OU": "$WORKERS_CERT_OU_OrganizationalUnit",
      "ST": "$WORKERS_CERT_ST_STATE"
    }
  ]
}
EOF

  EXTERNAL_IP=$(cat ../output/hosts | grep ${instance} | cut -d" " -f1)

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
  "CN": "$KUBEPROXY_CERT_CN_CommonName",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "$KUBEPROXY_CERT_C_CountryName",
      "L": "$KUBEPROXY_CERT_L_Locality",
      "O": "KUBEPROXY_CERT_O_Organization",
      "OU": "$KUBEPROXY_CERT_OU_OrganizationalUnit",
      "ST": "$KUBEPROXY_CERT_ST_STATE"
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
KUBERNETES_PUBLIC_ADDRESS="192.168.50.20"

# Create the Kubernetes API Server certificate signing request
cat > kubernetes-csr.json <<EOF
{
  "CN": "$APISERVER_CERT_CN_CommonName",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "$APISERVER_CERT_C_CountryName",
      "L": "$APISERVER_CERT_L_Locality",
      "O": "$APISERVER_CERT_O_Organization",
      "OU": "$APISERVER_CERT_OU_OrganizationalUnit",
      "ST": "$APISERVER_CERT_ST_STATE"
    }
  ]
}
EOF

HOSTNAMES=$(cat ../output/hosts | cut -d" " -f1 | tr '\n' ',')
HOSTNAMES=${HOSTNAMES::-1}
HOSTNAMES=$HOSTNAMES",${KUBERNETES_PUBLIC_ADDRESS},10.32.0.1,127.0.0.1,kubernetes.default,k8s-master"
echo "Adding hosts : "$HOSTNAMES

# Generate the Kubernetes API Server certificate and private key
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=$HOSTNAMES \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes

