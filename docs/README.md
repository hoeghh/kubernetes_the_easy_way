# Docs for Kubernetes the easy way

## Purpuse of this project
This project tries to make it easy to get a HA Kubernets cluster up and running. This being HA on etcd, master and load balancer using CoroSync and Pacemaker. We use Vagrant and Virtualbox for testing, but all functionallity is made in scripts thereby only using Vagrant for provisioning machines. It should then be easy to use these scripts for production setups or on other platforms. Just remember that Pacemake and CoroSync needs multicast funtionallity on the network to work, which AWS does not supply.

## Getting started
You need to install Vagrant and VirtualBox on your system. 

In the root folder we have a ```config``` file. In this you set how many etcd, masters, workers and load balancer nodes you want and how many CPU and memory you want.

You then need to install cfssl and cfssljson. On Linux this is easy, as they can be downloaded like this :

```
curl -o /usr/local/bin/cfssl https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
curl -o /usr/local/bin/cfssljson https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
chmod +x /usr/local/bin/cfssl*
```

Now you are ready to run the ```install.sh``` file. 

```install.sh``` will source the ```config``` file to set variables need by Vagrant.
It will then generate a host file and put it into the output folder. This is used on each host to find other hosts.

It then generates certificates used in the cluster and puts them in the ssl folder. These are distributed to the hosts by Vagrant.

Then we generate an EncruptionConfig manifest. This is used by Kubernetes to encrypt data at rest.

The script then generates config files for each worker node to be able to connect to the master.

Now the script is ready to start Vagrant. Vagrant copies the files needed by each host to the host in play, and the scripts (located in the scripts folder), and then runs the scripts. These scripts installs the node in play, eg etcd or master and so on.

Once Vagrant is done, your local kubectl is configured by adding the cluster to your ~/.kube/config file.

Lastly the script runs the ```post_deploy.sh``` script. This deploys a rbac (ClusteRole and ClusterRoleBinding) so that the api-server can connect to kubelets, and then deploys Weave net CNI network into the cluster as a daemonset. Lastly it deploys kubedns to enable DNS inside the cluster.

Thats it.

## SSH into a node
In order to SSH into the machines via Vagrant, you first need to source the config file.

```
source config
vagrant ssh k8s-master-1
```
You can then do a ```sudo su``` to become root.

## Test the cluster
In the folder tools/nwtool/ we have three manifests. Deploy them like this 
```
kubectl apply -f tools/nwtool/nwtool-deployment.yaml
kubectl apply -f tools/nwtool/nwtool-service.yaml
kubectl apply -f tools/nwtool/nwtool-ingress.yaml
```

Add the hostname nwtool.example.com to your /etc/hosts to point at Load balancer virtual ip 192.168.50.4
```
cat "192.168.50.4 nwtool.example.com" >> /etc/hosts
```

Wait for the pods to be pulled and ready.
```
wait -n 1 kubectl get pods -o wide
```

Once the pods is running, you should be able to access nwtool.example.com in a browser.
You can get the Ingress controllers dashboard via 192.168.50.4:8080 in a browser as well.

## Networking

## Adding worker nodes

## Roadmap

