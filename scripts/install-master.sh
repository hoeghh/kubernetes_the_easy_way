echo "Installing master..."

yum install -y conntrack-tools.x86_64

# Populate hosts file with new entries
# localhost is missing on 127.0.0.1 by Vagrant. This is a hack and we need to figure out why it is missing
cat /tmp/hosts >> /etc/hosts

# Prepare variables for etcd
ETCD_NAME=$(hostname -s)
ETCD_COUNT=$(cat /tmp/hosts | grep etcd | wc -l)

# Generating ETCD list for Api-Server service
counter=1
while [ $counter -le $ETCD_COUNT ]
do
  ETCD_CLUSTER_LIST=$ETCD_CLUSTER_LIST"https://192.168.50."$(($counter + 10))":2379,"
  ((counter++))
done
ETCD_CLUSTER_LIST="${ETCD_CLUSTER_LIST::-1}"
ETCD_CLUSTER_LIST=$(echo $ETCD_CLUSTER_LIST | tr -d '[:space:]')

# Download binaries we need
echo "Downloading binaries... please wait."
wget -q --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kube-apiserver" &

wget -q --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kube-controller-manager" & 

wget -q --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kube-scheduler" &

wget -q --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubectl" &

# Wait for downloads to finish
wait

# Set permission to execute and move to bin folder
chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/

# Create kuberntes folder that holds certificates and move certs from tmp to that
mkdir -p /var/lib/kubernetes/
mv /tmp/ca.pem /tmp/ca-key.pem /tmp/kubernetes-key.pem /tmp/kubernetes.pem /tmp/encryption-config.yaml /var/lib/kubernetes/

# CoroSync and Pagemaker is done, so this is pointing to 192.168.50.20, the Virtual floating ip
INTERNAL_IP="192.168.50.20"

# Count the number of master servers
MASTER_COUNT=$(cat /tmp/hosts | grep "k8s-master-" | wc -l)

cat > kube-apiserver.service <<EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --admission-control=Initializers,NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --advertise-address=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --apiserver-count=${MASTER_COUNT} \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-swagger-ui=true \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=$ETCD_CLUSTER_LIST \\
  --event-ttl=1h \\
  --experimental-encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --insecure-bind-address=127.0.0.1 \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --kubelet-https=true \\
  --runtime-config=api/all \\
  --service-account-key-file=/var/lib/kubernetes/ca-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-ca-file=/var/lib/kubernetes/ca.pem \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat > kube-controller-manager.service <<EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --address=0.0.0.0 \\
  --cluster-cidr=10.200.0.0/16 \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --leader-elect=true \\
  --master=http://127.0.0.1:8080 \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/ca-key.pem \\
  --v=5
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat > kube-scheduler.service <<EOF
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --leader-elect=true \\
  --master=http://127.0.0.1:8080 \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Move the service files to their place
mv kube-apiserver.service kube-scheduler.service kube-controller-manager.service /etc/systemd/system/

systemctl daemon-reload
systemctl enable kube-apiserver kube-controller-manager kube-scheduler
systemctl start kube-apiserver kube-controller-manager kube-scheduler

# This should be run once only.
# It needs to be run before loadbalancers get ready
# Its a hack...
if [ $(hostname) == "k8s-master-1" ]; then
  # Wait for the api-server to be ready
  RESP=$(curl -s -o /dev/null -I -w "%{http_code}" http://localhost:8080/)
  while [ $RESP != "200" ]; do
    echo "$(date) The response is $RESP"
    sleep 1
    RESP=$(curl -s -o /dev/null -I -w "%{http_code}" http://localhost:8080/)
  done

  echo "$(date) Api server is ready..."

  echo "Deploying WeaveNet..."
  sleep 15
  /usr/local/bin/kubectl create -f "https://cloud.weave.works/k8s/net?k8s-version=$(/usr/local/bin/kubectl version | base64 | tr -d '\n')&env.IPALLOC_RANGE=10.200.0.0/16"
fi
