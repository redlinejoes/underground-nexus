#Initiate Swarm mode if not already running in swarm mode
docker swarm init --advertise-addr 127.0.0.1

#Build the traefik-public network
docker network create --attachable --driver=overlay --subnet=10.15.0.0/16 --gateway=10.15.0.1 traefik-public

#Attach management and state resoruces to the traefik network (Pihole manages the DNS for the stack)
docker network connect traefik-public workbench
docker network connect traefik-public Athena0
docker network connect --ip 10.15.0.20 traefik-public Inner-DNS-Control
docker network connect traefik-public torpedo

#Define system variables
export DOMAIN=underground-ops.me
bash -c "NODE_ID=$(docker info -f '{{.Swarm.NodeID}}'); EMAIL=me@underground-ops.me; DOMAIN=underground-ops.me"

#Apply docker lables
docker node update --label-add traefik-public.traefik-public-certificates=true Underground-Nexus
docker node update --label-add traefik-public.traefik-public-certificates=true underground-nexus

#Build collaborator stack, GitLab and Traefik loadbalancer
docker stack deploy -c /nexus-bucket/underground-nexus/traefik-api-proxy.yml traefik
docker stack deploy -c /nexus-bucket/underground-nexus/gitlab-proxy-deploy.yml gitlab
docker stack deploy -c /nexus-bucket/underground-nexus/workbench-proxy-deploy.yml collaborator-workbench

#Set up "Control Panel" stack - powered by Wordpress
mkdir /var/lib/docker/volumes/underground-wordpress_db_data
cp /nexus-bucket/underground-nexus/'Production Artifacts'/Wordpress/_data.zip /var/lib/docker/volumes/underground-wordpress_db_data/
cd /var/lib/docker/volumes/underground-wordpress_db_data/
unzip _data.zip
rm -r /var/lib/docker/volumes/underground-wordpress_db_data/_data.zip
docker stack deploy -c /nexus-bucket/underground-nexus/wordpress-proxy-deploy.yml underground-wordpress

#Build the Underground Observability Stack
cd /nexus-bucket/underground-nexus/'Observability Stack'/
docker stack deploy -c ./docker-stack.yml underground-observability
#cd /nexus-bucket/underground-nexus/'Observability Stack'/wazuh-docker/multi-node/
#docker-compose -f generate-indexer-certs.yml run --rm generator
#docker stack deploy -c ./docker-stack.yml underground-siem

#Set up DNS and CNAME Records to make underground-ops.me available
cd /var/lib/docker/volumes/pihole_config/_data/
echo "10.20.0.1 underground-ops.me" >> custom.list

cd /var/lib/docker/volumes/pihole_DNS_data/_data/
echo "cname=api.underground-ops.me,underground-ops.me" >> 05-pihole-custom-cname.conf
echo "cname=gitlab.underground-ops.me,underground-ops.me" >> 05-pihole-custom-cname.conf
echo "cname=workbench.underground-ops.me,underground-ops.me" >> 05-pihole-custom-cname.conf
echo "cname=grafana.underground-ops.me,underground-ops.me" >> 05-pihole-custom-cname.conf
echo "cname=alertmanager.underground-ops.me,underground-ops.me" >> 05-pihole-custom-cname.conf
echo "cname=indexer.underground-ops.me,underground-ops.me" >> 05-pihole-custom-cname.conf
echo "cname=prometheus.underground-ops.me,underground-ops.me" >> 05-pihole-custom-cname.conf
echo "cname=wazuh.underground-ops.me,underground-ops.me" >> 05-pihole-custom-cname.conf
