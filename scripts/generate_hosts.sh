
# Static floating IP's
echo "192.168.50.4 k8s-loadbalancer"
echo "192.168.50.20 k8s-master"

# Generating ip-hostname list for ETCD nodes
counter=1
while [ $counter -le $ETCD_COUNT ]
do
echo "192.168.50."$(($counter + 10))" k8s-etcd-$counter"
((counter++))
done

# Generating ip-hostname list for MASTER nodes
counter=1
while [ $counter -le $MASTER_COUNT ]
do
echo "192.168.50."$(($counter + 20))" k8s-master-$counter"
((counter++))
done

# Generating ip-hostname list for WORKER nodes
counter=1
while [ $counter -le $WORKER_COUNT ]
do
echo "192.168.50."$(($counter + 30))" k8s-worker-$counter"
((counter++))
done

# Generating ip-hostname list for LOADBALANCER nodes
counter=1
while [ $counter -le $LOADBALANCER_COUNT ]
do
echo "192.168.50."$(($counter + 4))" k8s-loadbalancer-$counter"
((counter++))
done

# Adding EXTRA_HOSTS as defined in config
echo $EXTRA_HOSTS
