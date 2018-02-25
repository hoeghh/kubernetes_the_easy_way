echo "Installing worker..."

# The socat binary enables support for the kubectl port-forward command
yum install -y socat libseccomp-devel btrfs-progs-devel util-linux 

# Install Docker and specific dependencies
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install docker-ce


# Disabling swap (now and permently)
swapoff -a
sed -i.bak '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# We will be using weave net for networking, so we need to pass bridged IPv4 traffic to iptables’ chains
echo "net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1" > /etc/sysctl.conf

# Add hostnames to hosts file
cat /tmp/hosts >> /etc/hosts

# Download binaries
wget -q --timestamping  https://github.com/containernetworking/plugins/releases/download/v0.6.0/cni-plugins-amd64-v0.6.0.tgz &
wget -q --timestamping  https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubectl &
wget -q --timestamping  https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kube-proxy & 
wget -q --timestamping  https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubelet &

# Create the installation directories
sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes

# Wait for downloads to finish
wait

# Install the worker binaires
chmod +x kubectl kube-proxy kubelet
mv kubectl kube-proxy kubelet /usr/local/bin/


# Retrieve the Pod CIDR range for the current instance
# From master :  --cluster-cidr=10.200.0.0/16 
WORKER_NB=$(echo ${HOSTNAME} | rev | cut -d"-" -f1 | rev)
POD_CIDR="10.200.$WORKER_NB.0/24"

# Create the bridge network configuration file
cat > 10-bridge.conf <<EOF
{
    "cniVersion": "0.3.1",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${POD_CIDR}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF

# Create the loopback network configuration file:
cat > 99-loopback.conf <<EOF
{
    "cniVersion": "0.3.1",
    "type": "loopback"
}
EOF

#Move the network configuration files to the CNI configuration directory:
mv 10-bridge.conf 99-loopback.conf /etc/cni/net.d/

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
  --container-runtime=docker \\
  --container-runtime-endpoint=unix:///var/run/docker.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
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

# Start the Worker Services
mv kubelet.service kube-proxy.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable docker kubelet kube-proxy
systemctl start docker kubelet kube-proxy


