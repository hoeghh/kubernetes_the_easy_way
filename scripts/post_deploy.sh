# Giving the API-Server access to kubelets
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF

echo "Deploying WeaveNet..."
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')&env.IPALLOC_RANGE=20.0.0.0/16"

#kubever=$(kubectl version | base64 | tr -d '\n')
#kubectl apply -f "https://git.io/weave-kube-1.6"&> ../logs/weavenet.log
#kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$kubever" &> ../logs/weavenet.log

echo "Deploying KubeDNS..."
#kubectl create -f "https://storage.googleapis.com/kubernetes-the-hard-way/kube-dns.yaml" > ../logs/kubedns.log

