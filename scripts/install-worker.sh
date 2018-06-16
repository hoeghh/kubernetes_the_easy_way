echo "Installing worker..."

# The socat binary enables support for the kubectl port-forward command
dnf install -y socat libseccomp-devel btrfs-progs-devel util-linux nfs-utils conntrack-tools.x86_64

# Install Docker and specific dependencies
dnf remove -y 	  docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-selinux \
                  docker-engine-selinux \
                  docker-engine

dnf install -y 	  dnf-plugins-core \

dnf config-manager \
    --add-repo \
    https://download.docker.com/linux/fedora/docker-ce.repo

dnf config-manager --set-disabled docker-ce-edge

dnf install docker-ce -y

# Removing Docker-created bridge and iptables rules
#iptables -t nat -F
#ip link set docker0 down
#ip link delete docker0

# Fixing Docker service to leave iptables alone and not masq
sed -i '/^ExecStart/ s/$/ --iptables=false --ip-masq=false/' /lib/systemd/system/docker.service

# Disabling swap (now and permently)
echo "Disableling swap..."
swapoff -a
sed -i '/^\/swapfile/ d' /etc/fstab

# We will be using weave net for networking, so we need to pass bridged IPv4 traffic to iptables’ chains
echo "Setting up network..."
echo "net.bridge.bridge-nf-call-ip6tables=1
net.bridge.bridge-nf-call-iptables=1" > /etc/sysctl.conf

# Add hostnames to hosts file
cat /tmp/hosts >> /etc/hosts

# Create the installation directories
sudo mkdir -p         \
  /var/lib/kubelet    \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /opt/cni/bin        \
  /var/run/kubernetes \
  /etc/cni/net.d 

# Download binaries
echo "Downloading files..."
wget -q --timestamping  https://github.com/containernetworking/plugins/releases/download/v0.6.0/cni-plugins-amd64-v0.6.0.tgz
wget -q --timestamping  https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kube-proxy & 
wget -q --timestamping  https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubelet &

# Wait for downloads to finish
wait

tar -xvf cni-plugins-amd64-v0.6.0.tgz -C /opt/cni/bin/

# Install the worker binaires
chmod +x kube-proxy kubelet
mv kube-proxy kubelet /usr/local/bin/


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
  --cluster-dns=20.32.0.10 \\
  --cluster-domain=cluster.local \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --register-node=true \\
  --network-plugin=cni \\
  --cni-conf-dir=/etc/cni/net.d \\
  --cni-bin-dir=/opt/cni/bin \\
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
After=network.target

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --kubeconfig=/var/lib/kube-proxy/kubeconfig \\
  --cluster-cidr=20.0.0.0/16 \\
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


