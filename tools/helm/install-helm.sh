kubectl create -f tiller-rbac-config.yaml
helm init --service-account tiller

echo "Now wait for tiller to start by running

kubectl get pods --all-namespaces

"


