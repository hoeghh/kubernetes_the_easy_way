kubectl apply -f alertmanager.pv.yaml
kubectl apply -f prometheus.pv.yaml

helm install stable/prometheus --name=prometheus --set server.ingress.hosts[0]=prometheus.example.com --set server.ingress.enabled=true

#--set=server.terminationGracePeriodSeconds=360, server.ingress.hosts[0]=prometheus.example.com, server.ingress.enabled=true, server.baseURL=https://prometheus.example.com, alertmanager.ingress.enabled=true, alertmanager.ingress.hosts[0]=alertmng.example.com, alertmanager.enabled=true, alertmanager.persistentVolume.existingClaim="alertmng-pvc", server.persistentVolume.enabled=true, server.persistentVolume.existingClaim="promethues-pvc" stable/prometheus --name=prometheus

