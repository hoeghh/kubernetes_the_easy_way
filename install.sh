echo "Sourcing config file..."
source config

echo "Generating hosts..."
scripts/generate_hosts.sh > output/hosts

echo "Generating certificates..."
(cd ssl; ../scripts/generate_certs.sh &> ../logs/cert.log)

echo "Generating data encryption config and key..."
(cd scripts; ./generated_data_encryption.sh &> ../logs/data-encryption.log)

echo "Generating kubeconfig files for workers and kubeproxy..."
scripts/generate_kube_config.sh &> logs/kube-configs.log

#echo "Checking if vm box should be updated..."
#vagrant box update &> logs/vagrant-box-upgrade.log

echo "Running Vagrant, this will take a while...
Follow progress in logs/vagrant-provition.log"
vagrant up &> logs/vagrant-provition.log

echo "Generating kubeconfig file for admin user..."
kubectl config set-cluster kubernetes-the-easy-way \
  --certificate-authority=ssl/ca.pem \
  --embed-certs=true \
  --server=https://192.168.50.20:6443 > logs/kubedeploy.log

kubectl config set-credentials admin \
  --client-certificate=ssl/admin.pem \
  --client-key=ssl/admin-key.pem >> logs/kubedeploy.log

kubectl config set-context kubernetes-the-easy-way \
  --cluster=kubernetes-the-easy-way \
  --user=admin >> logs/kubedeploy.log

echo "Set the current context to kubernets-the-easy-way..."
kubectl config use-context kubernetes-the-easy-way >> logs/kubedeploy.log

echo "Deploying KubeDNS..."
kubectl create -f "https://storage.googleapis.com/kubernetes-the-hard-way/kube-dns.yaml" > logs/kubedns.log

echo "Deploying WeaveNet..."
kubever=$(kubectl version | base64 | tr -d '\n')
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$kubever" &> logs/weavenet.log

