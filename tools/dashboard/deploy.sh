kubectl apply -f dashboard.rbac.yaml -n kube-system
kubectl apply -f dashboard.serviceaccount.yaml -n kube-system
kubectl apply -f dashboard.ingress.yaml -n kube-system

kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml

echo "Get password token here...."
kubectl get serviceaccounts/dashboard-admin -n kube-system -o json
echo "use:
kubectl get secret -n kube-system [secret-name]
To then copy the token
Then run \"echo [token] | base64 -d\""

echo "Remember to add \"192.168.50.4 dashboard.example.com\" to /etc/hosts"
