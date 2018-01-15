# Kubernetes the easy way

> This is work in progress. 

This repository tries to automate the guide "Kubernetes the hard way" by Kelsey Hightower, using Vagrant and Virtualbox.

## Prerequisites

- Vagrant
- VirtualBox 5.2
- `kubectl`

PKI and TLS Tools by Cloudflare (https://github.com/cloudflare/cfssl)
- cfssl 
- cfssljson

```
 curl -o /usr/local/bin/cfssl https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
 curl -o /usr/local/bin/cfssljson https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
 chmod +x /usr/local/bin/cfssl*
```

## Getting started
First off, edit the file config. Here you can specify how man of each type of nodes you want. Eg. 3 master nodes. Also you can specify the number of CPU and Memory for each type.

Ones thats done, just run `./install.sh`.

## What just happend
The script set the number of nodes you want and the resources they get. Then it calls Vagrant to provition the nodes. While provitioning the nodes, Vagrant will copy scripts to each node and execute it. The script can be found under the scripts folder.

### Destroy machines
To remove all machines, please run
```sh
vagrant destroy -f
```
