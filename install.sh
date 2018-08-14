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

echo "Running Vagrant, this will take a while...
Follow progress in logs/vagrant-provisioning.log"
vagrant up &> logs/vagrant-provisioning.log


echo "Do you want me to configure kubectl for you? [y/n], followed by [ENTER]:"

read CONFIGURE_KUBECTL
if [ "$CONFIGURE_KUBECTL" = "y" ]; then
  echo "Setting up kubectl config..."

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

  echo "Set the current context to kubernetes-the-easy-way..."
  kubectl config use-context kubernetes-the-easy-way >> logs/kubedeploy.log

  # Running post install deploy script
  (cd scripts; ./post_deploy.sh  &> ../logs/post_deploy.log)

else
  echo "The network is not setup, as we need kubectl to work for that."
  echo "The script ./script/post_deploy.sh setups up network, so run"
  echo "this when you have the chance, to enable networking in the"
  echo "cluster."
fi


