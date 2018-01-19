# Generating kubernetes configuration files for Authentication

KUBERNETES_PUBLIC_ADDRESS=192.168.50.20

# Generating config for each worker node
WORKER_COUNT=$(cat output/hosts | grep worker | wc -l)
echo "WORKER_COUNT: $WORKER_COUNT"

echo "Generating configs for workers..."
counter=1
while [ $counter -le $WORKER_COUNT ]
do
  kubectl config set-cluster kubernetes-the-easy-way \
    --certificate-authority=ssl/ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=output/k8s-worker-${counter}.kubeconfig

  kubectl config set-credentials system:node:k8s-worker-${counter} \
    --client-certificate=ssl/k8s-worker-${counter}.pem \
    --client-key=ssl/k8s-worker-${counter}-key.pem \
    --embed-certs=true \
    --kubeconfig=output/k8s-worker-${counter}.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-easy-way \
    --user=system:node:k8s-worker-${counter} \
    --kubeconfig=output/k8s-worker-${counter}.kubeconfig

  kubectl config use-context default --kubeconfig=output/k8s-worker-${counter}.kubeconfig

  ((counter++))
done

# Generate a kubeconfig file for the kube-proxy service
echo "Generating config for kube-proxy..."
kubectl config set-cluster kubernetes-the-easy-way \
  --certificate-authority=ssl/ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
  --kubeconfig=output/kube-proxy.kubeconfig
kubectl config set-credentials kube-proxy \
  --client-certificate=ssl/kube-proxy.pem \
  --client-key=ssl/kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=output/kube-proxy.kubeconfig
kubectl config set-context default \
  --cluster=kubernetes-the-easy-way \
  --user=kube-proxy \
  --kubeconfig=output/kube-proxy.kubeconfig
kubectl config use-context default --kubeconfig=output/kube-proxy.kubeconfig

