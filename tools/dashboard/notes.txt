# Kubernetes dashboard
## Deploy the dashboard manifest

When you deploy the kubernets dashboard, you need to create access tokens to be able to use the dashboard. Otherwise, the dashboard will not be able to communicate with the api-server.

In this example, we show you how to create an admin token and a view token. Also, for dev purposes, we should you how to give the kubernetes-dashboard admin rights without providing any tokens. This is not recommended in production!

```kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml```

ONLY for dev purposes, bind the cluster-admin role to kubernetes-dashboard service account.
```
echo "
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: kubernetes-dashboard
  labels:
    k8s-app: kubernetes-dashboard
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: kubernetes-dashboard
  namespace: kube-system
" > dashboard.rbac.yaml

kubectl apply -f dashboard.rbac.yaml
```




## Service accounts and cluster role bindings
For production, create an admin service account with a cluster role binding to cluster-admin
```
echo "
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dashboard-admin
automountServiceAccountToken: false" > dashboard.dasboard-admin.yaml

echo "
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: kubernetes-dashboard
  labels:
    k8s-app: kubernetes-dashboard
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: dashboard-admin
  namespace: kube-system
" > dashboard.admin.rbac.yaml
```


## Create an view service account with a cluster role binding to view
```
echo "
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dashboard-view
automountServiceAccountToken: false" > dashboard.dasboard-view.yaml

echo "
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: kubernetes-dashboard
  labels:
    k8s-app: kubernetes-dashboard
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: dashboard-admin
  namespace: kube-system
" > dashboard.view.rbac.yaml
```

## Apply the to cluster roles and cluster role bindings
```
kubectl apply -f dashboard.dasboard-admin.yaml
kubectl apply -f dashboard.dasboard-view.yaml
kubectl apply -f dashboard.admin.rbac.yaml
kubectl apply -f dashboard.view.rbac.yaml
```

## Get Secret names for service account, to login to kubernetes dashboard
```
admin_secret=$(kubectl get serviceaccounts/build-robot -o json)
view_secret=$(kubectl get serviceaccounts/build-robot -o json)

kubectl get secrets/dashboard-admin -o json
kubectl get secrets/dashboard-view -o json
```

## Create ingress for Kubernets-dashboard
```
echo "
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: kubernetes-dashboard
  annotations:
    kubernetes.io/ingress.class: traefik
spec:
  rules:
  - host: dashboard.example.com
    http:
      paths:
      - path: /
        backend:
          serviceName: kubernetes-dashboard
          servicePort: 443
" > dashboard.ingress.yaml
kubectl apply -f dashboard.ingress.yaml  
```

# Add entry to hostfile to resolve dashboard.example.com
```echo "192.168.50.4 dashboard.example.com" >> /etc/hosts```


