# Kubernetes the easy way

This repository tries to automate the guide "[Kubernetes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)" by Kelsey Hightower, using Vagrant and Virtualbox.

## Prerequisites

- Vagrant
- VirtualBox 5.2
- `kubectl`
- `cfssl`
- `cfssljson`

## Installing cfssl and cfssljson
PKI and TLS Tools by Cloudflare (https://github.com/cloudflare/cfssl)
```
For Linux :
 curl -o /usr/local/bin/cfssl https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
 curl -o /usr/local/bin/cfssljson https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
 chmod +x /usr/local/bin/cfssl*

For Mac :
 curl -o /usr/local/bin/cfssl https://pkg.cfssl.org/R1.2/cfssl_darwin-amd64
 curl -o /usr/local/bin/cfssljson https://pkg.cfssl.org/R1.2/cfssljson_darwin-amd64
 chmod +x /usr/local/bin/cfssl*

For Windows :
  Download https://pkg.cfssl.org/R1.2/cfssl_windows-amd64.exe
  Download https://pkg.cfssl.org/R1.2/cfssljson_windows-amd64.exe
  Do whatever Windows people do
```

## Getting started
First off, edit the file `config`. Here you can specify how many of each type of nodes you want. Eg. 3 master nodes. Also you can specify the number of CPU and Memory for each type.

Once thats done, just run `./install.sh`.

## What just happend
The script set the number of nodes you want and the resources they get. It then generates a hosts file with ip's and hostnames. This is used to configure each node in the cluster. Then it generates certificates, based on the hostfile. 

Now it calls Vagrant to provition the nodes. While provitioning the nodes, Vagrant will copy scripts and certifiates to each node and execute them. The script can be found under the scripts folder and the certificates under the folder ssl.

## Connect local kubectl to the new cluster
### Set the current context to kubernets-the-easy-way
```kubectl config use-context kubernetes-the-easy-way```

### Test connection and see worker nodes connected
```kubectl get nodes```

## SSH into the machines
In order to SSH into the machines via Vagrant, you first need to source the config file.

```
source config
vagrant ssh k8s-master-1
```
You can then do a ```sudo su``` to become root.

## Destroy machines
If Kubernetes is not your thing after all, or that you for other reasons want to remove the cluster, simply run this script 
```sh
./destroy.sh
```
