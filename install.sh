echo "Sourcing config file..."
source config

echo "Generating hosts..."
scripts/generate_hosts.sh > hosts

echo "Generating certificates..."
(cd ssl; ../scripts/generate_certs.sh &> ../logs/cert.log)

echo "Checking if vm box should be updated..."
vagrant box update &> logs/vagrant-box-upgrade.log

echo "Running Vagrant, this will take a while...
Follow progress in logs/vagrant-provition.log"
vagrant up &> logs/vagrant-provition.log

