source config
scripts/generate_hosts.sh > hosts
(cd ssl; ../scripts/generate_certs.sh)
vagrant box update
vagrant up

