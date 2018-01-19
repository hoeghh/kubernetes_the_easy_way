# This folder keeps all outputs from scripts being run on the host system

- `hosts` file is generated via the config file and used by mosts nodes in scripts to configre themselves, especially when they have to know other nodes of same type.
- `k8s-worker-x.kubeconfig` is generated for each worker node and used to authenticate to the api-server.
- `kube-proxy.kubeconfig` is generated for kube-proxy on each worker node and used to authenticate to the api-server.
