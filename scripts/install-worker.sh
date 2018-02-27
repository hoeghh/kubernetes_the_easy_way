echo "Installing worker..."

# The socat binary enables support for the kubectl port-forward command
yum install -y socat libseccomp-devel btrfs-progs-devel util-linux nfs-utils 

# Install Docker and specific dependencies
yum remove -y 	  docker \
                  docker-common \
                  docker-selinux \
                  docker-engine

yum install -y 	  yum-utils \
		  device-mapper-persistent-data \
		  lvm2

yum-config-manager \
		  --add-repo \
		  https://download.docker.com/linux/centos/docker-ce.repo

yum-config-manager --disable docker-ce-edge

yum install -y    docker-ce

# Disabling swap (now and permently)
echo "Disableling swap..."
swapoff -a
sed -i.bak '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# We will be using weave net for networking, so we need to pass bridged IPv4 traffic to iptables’ chains
echo "Setting up network..."
echo "net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1" > /etc/sysctl.conf

# Add hostnames to hosts file
cat /tmp/hosts >> /etc/hosts

# Create the installation directories
sudo mkdir -p \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes

# Download binaries
echo "Downloading files..."
wget -q --timestamping  https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubectl &
wget -q --timestamping  https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kube-proxy & 
wget -q --timestamping  https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubelet &

# Wait for downloads to finish
wait

# Install the worker binaires
chmod +x kubectl kube-proxy kubelet
mv kubectl kube-proxy kubelet /usr/local/bin/


# Retrieve the Pod CIDR range for the current instance
# From master :  --cluster-cidr=10.200.0.0/16 
WORKER_NB=$(echo ${HOSTNAME} | rev | cut -d"-" -f1 | rev)
POD_CIDR="10.200.$WORKER_NB.0/24"


#Configure the Kubelet
mv /tmp/${HOSTNAME}-key.pem /tmp/${HOSTNAME}.pem /var/lib/kubelet/
mv /tmp/${HOSTNAME}.kubeconfig /var/lib/kubelet/kubeconfig
mv /tmp/ca.pem /var/lib/kubernetes/


# Create the kubelet.service systemd unit file:
cat > kubelet.service <<EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=docker.service
Requires=docker.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --allow-privileged=true \\
  --anonymous-auth=false \\
  --authorization-mode=Webhook \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --cloud-provider= \\
  --cluster-dns=10.32.0.10 \\
  --cluster-domain=cluster.local \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --pod-cidr=${POD_CIDR} \\
  --register-node=true \\
  --runtime-request-timeout=15m \\
  --tls-cert-file=/var/lib/kubelet/${HOSTNAME}.pem \\
  --tls-private-key-file=/var/lib/kubelet/${HOSTNAME}-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Configure the Kubernetes Proxy
mv /tmp/kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig

# Create the kube-proxy.service systemd unit file:
cat > kube-proxy.service <<EOF
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --cluster-cidr=10.200.0.0/16 \\
  --kubeconfig=/var/lib/kube-proxy/kubeconfig \\
  --proxy-mode=iptables \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

mv kubelet.service kube-proxy.service /etc/systemd/system/

# Start the Worker Services
echo "Starting services..."
systemctl daemon-reload
systemctl enable docker kubelet kube-proxy
systemctl start docker kubelet kube-proxy


