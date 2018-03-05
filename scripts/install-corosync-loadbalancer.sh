
# Installing HA Software packages : Pacemaker Corosync PCS and PSMisc
yum --nogpgcheck -q -y install pacemaker pcs corosync psmisc git


echo "Assigning password to pcs user hacluster"
# TODO This needs to come from our config file on the provitioning machine
PCS_PASSWORD="BananaSplit"
echo "hacluster:${PCS_PASSWORD}" | chpasswd

echo "Enabling PCSD ..."
systemctl enable pcsd.service 
systemctl stop pcsd.service
systemctl start pcsd.service

echo "Generating a list of loadbalancer nodes ..."
LOADBALANCERS=$(grep -v \# /tmp/hosts | grep "loadbalancer-" | sort -u | awk '{print $2}' | tr '\n' ' ')

echo "Authenticate user hacluster to the cluster nodes ..."
pcs cluster auth -u hacluster -p ${PCS_PASSWORD} ${LOADBALANCERS}

# Finding the last loadbalancer in hosts, and using this to setup the cluster
# This is beourse every node needs to be ready when we run this.
LAST_LOADBALANCER=$(cat /tmp/hosts | grep "loadbalancer-" | tail -1 | cut -d" " -f2)
HOSTNAME=$(hostname -s)

if [ "${HOSTNAME}" == "${LAST_LOADBALANCER}" ]; then
  echo "Executing pcs cluster setup commands on the last loadbalancer node only ..."

  # Master VIP will be the IP of the hostname 'loadbalancer.domainname.tld' in the hosts file.
  VIP=$(grep -v \# /tmp/hosts | grep "loadbalancer$" | awk '{print $1}')

  echo "Creating CoroSync communication cluster/service ..."
  pcs cluster setup --name LOADBALANCERHA ${LOADBALANCERS} --force

  echo "Starting cluster on all cluster nodes ... This may take few seconds ..."
  pcs cluster start --all

  # this enables the corosync and pacemaker services to start at boot time.
  pcs cluster enable --all

  pcs property set stonith-enabled=false

  echo "Setting up cluster resource VIP as ${VIP} ..."
  pcs resource create LOADBALANCERVIP ocf:heartbeat:IPaddr2 ip=${VIP} cidr_netmask=32 op monitor interval=30s

  # Checking corosync status
  echo "Checking corosync status ..."
  corosync-cfgtool -s
  systemctl status corosync pacemaker --no-pager -l
  pcs status
fi

