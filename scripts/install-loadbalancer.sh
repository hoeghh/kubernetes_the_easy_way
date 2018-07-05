echo "Installing loadbalancer..."

echo "Downloading binaries..."
wget -q --timestamping  https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubectl &
wget -q --timestamping https://github.com/containous/traefik/releases/download/v1.6.4/traefik_linux-amd64 &
wget -q --timestamping git.io/weave &

mkdir -p /root/ssl

echo "Adding hosts to /etc/hosts file"
cat /tmp/hosts >> /etc/hosts

# Installing Docker on Load balancer
dnf install dnf-plugins-core -y
dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
dnf config-manager --set-disabled docker-ce-edge
dnf install docker-ce -y

# Wait for downloads to complete
wait 
echo "Done downloading binaries..."

echo "Moving binaries in place..."
chmod +x kubectl
mv kubectl /usr/bin/
sudo mv traefik_linux-amd64 /root/traefik
sudo chmod u+x /root/traefik
mv weave /usr/bin/weave
chmod a+x /usr/bin/weave

echo "Generating kubeconfig file for admin user..."
kubectl config set-cluster kubernetes-the-easy-way \
  --certificate-authority=/tmp/ca.pem \
  --embed-certs=true \
  --server=https://192.168.50.20:6443

kubectl config set-credentials admin \
  --client-certificate=/tmp/admin.pem \
  --client-key=/tmp/admin-key.pem

kubectl config set-context kubernetes-the-easy-way \
  --cluster=kubernetes-the-easy-way \
  --user=admin

echo "Set the current context to kubernets-the-easy-way..."
kubectl config use-context kubernetes-the-easy-way

# Create rbac for traefik
if [ $(hostname) == "k8s-loadbalancer-1" ]; then
  echo "Creating rbac file for traefik..."
  cat << EOF > /root/traefik.rbac.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: traefik
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: traefik-service-account
  namespace: traefik
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: traefik-cluster-role
  namespace: traefik
rules:
  - apiGroups:
      - ""
    resources:
      - secrets
      - pods
      - services
      - endpoints
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - extensions
    resources:
      - ingresses
    verbs:
      - get
      - list
      - watch
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: traefik-cluster-role-binding
  namespace: traefik
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: traefik-cluster-role
subjects:
- kind: ServiceAccount
  name: traefik-service-account
  namespace: traefik

EOF

  echo "Creating RBAC for traefik..."
  kubectl create -f /root/traefik.rbac.yaml
fi 

sleep 2
echo "Getting token and ca.crt for Traefik from api-server..."
traefik_sa=$(kubectl get sa traefik-service-account --namespace=traefik -o jsonpath='{.secrets[].name}')
traefik_token=$(kubectl get secret $traefik_sa -n=traefik -o jsonpath='{.data.token}' | base64 -d)

kubectl get secret $traefik_sa -n=traefik -o jsonpath='{.data.ca\.crt}' | base64 -d > /root/ssl/ca.crt

cat << EOF > /root/traefik.toml
InsecureSkipVerify = true
defaultEntryPoints = ["http", "https"]
[entryPoints]
[entryPoints.http]
  address = ":80"
[entryPoints.http.redirect]
  entryPoint = "https"
[entryPoints.https]
  address = ":443"
[entryPoints.https.tls]
[[entryPoints.https.tls.certificates]]
#CertFile = "/root/ssl/traefik-wildcard.pem"
#KeyFile = "/root/ssl/traefik-wildcard.key"
[web]
address = ":8080"
ReadOnly = true
[kubernetes]
endpoint = "https://192.168.50.20:6443"
token="$traefik_token"
certAuthFilePath = "/root/ssl/ca.crt"
EOF

sudo bash -c 'cat << EOF > /etc/systemd/system/traefik.service
[Unit]
Description=Traefik proxy server
Documentation=https://github.com/containous/traefik

[Service]
ExecStart=/root/traefik \
  -c /root/traefik.toml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF'

sudo systemctl daemon-reload
sudo systemctl enable traefik
sudo service traefik start

sudo systemctl enable docker
sudo service docker start

# Install weavenet
WORKER_IPS=$(cat /etc/hosts | grep worker | cut -d " " -f1 | tr '\n' ' ')
/usr/bin/weave launch --ipalloc-init observer $WORKER_IPS --ipalloc-range 10.200.0.0/16
/usr/bin/weave expose

echo "Cleaning up..."
rm -f /tmp/admin-key.pem
rm -f /tmp/admin.pem
rm -f /tmp/ca.pem
sudo rm -rf /root/.kube
sudo rm -f /usr/bin/kubectl
