echo "Installing etcd..."

# Installing ETCD

echo /tmp/hosts >> /etc/hosts

wget -q --https-only --timestamping \
  "https://github.com/coreos/etcd/releases/download/v3.2.11/etcd-v3.2.11-linux-amd64.tar.gz"

tar -xvf etcd-v3.2.11-linux-amd64.tar.gz

mv etcd-v3.2.11-linux-amd64/etcd* /usr/local/bin/
rm -f etcd-v3.2.11-linux-amd64.tar.gz

mkdir -p /etc/etcd /var/lib/etcd

cp /tmp/ca.pem /tmp/kubernetes-key.pem /tmp/kubernetes.pem /etc/etcd/

INTERNAL_IP=$(/sbin/ifconfig eth2 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
ETCD_NAME=$(hostname -s)
ETCD_COUNT=$(cat /tmp/hosts | grep etcd | wc -l)

# Generating ETCD list for ETCD service
counter=1
while [ $counter -le $ETCD_COUNT ]
do
  ETCD_CLUSTER_LIST="$ETCD_CLUSTER_LIST k8s-etcd-$counter=https://192.168.50."$(($counter + 10))":2380,"
  ((counter++))
done
ETCD_CLUSTER_LIST="${ETCD_CLUSTER_LIST::-1}"
ETCD_CLUSTER_LIST=$(echo $ETCD_CLUSTER_LIST | tr -d '[:space:]')


cat > etcd.service <<EOF
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-client-urls https://${INTERNAL_IP}:2379,http://127.0.0.1:2379 \\
  --advertise-client-urls https://${INTERNAL_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster $ETCD_CLUSTER_LIST \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF


mv etcd.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable etcd
systemctl start etcd


