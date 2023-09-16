#!/bin/bash

read -p "Node name: " node
read -p "Do you want to set your stack to use a loopback address? (Recommended for single node) (y/n): " isLoopback
update() {
    sudo apt-get update
    sudo apt-get upgrade
}

getIpAddress() {
    sudo apt install net-tools && sudo apt install curl
    ipaddr=$(ifconfig | grep -oE 'inet (addr:)?([0-9]*\.){3}[0-9]*' | awk '{print $NF; exit}')
}
installElasticsearch() {
    clear
    wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
    sudo apt-get install apt-transport-https -y
    echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list
    update
    sudo apt-get install elasticsearch -y
    sudo sed -i "s/#node.name: node-1/node.name: $node/I" /etc/elasticsearch/elasticsearch.yml
    if [[ "$isLoopback" == "y" || "$isLoopback" == "Y" ]] then
        sudo sed -i 's/#network.host: 192.168.0.1/network.host: '"0.0.0.0"'/' /etc/elasticsearch/elasticsearch.yml
        sudo sed -i 's/#discovery.seed_hosts: ["node-1", "node-2"]/discovery.seed_hosts: ["127.0.0.1"]' /etc/elasticsearch/elasticsearch.yml
    elif [[ "$isLoopback" == "n" || "$isLoopback" == "N"]] then
        sudo sed -i 's/#network.host: 192.168.0.1/network.host: '"$ipaddress"'/' /etc/elasticsearch/elasticsearch.yml
        sudo sed -i 's/#discovery.seed_hosts: ["node-1", "node-2"]/discovery.seed_hosts: ['"$ipaddress"']' /etc/elasticsearch/elasticsearch.yml
    else 
        echo "Invalid input. Please enter y/n."
    fi
    sudo sed -i 's/xpack.security.enabled: true/xpack.security.enabled: false' /etc/elasticsearch/elasticsearch.yml
}
startElasticsearch() {
    sudo systemctl enable elasticsearch
    sudo systemctl start elasticsearch
    clear
    echo "Starting Elasticsearch..."
    sleep 10
}

update()
getIpAddress(ipaddr)
installElasticsearch()



# ()ncommented kibana lines
# server.port: 5601
# server.host: loopback or IP ( make if )
# elasticsearch.hosts: ["http://localhost:9200"] or IP address

# Uncommented logstash lines
# output.elasticsearch:
#   hosts: ["http://localhost:9200"] pr IP

# Uncommented metricbeat lines
# setup.kibana:
#   host: "localhost:5601" or IP
# output.elasticsearch:
#  hosts: ["http://localhost:9200"] or IP

# uncommented filebeat lines
# enabled: true
# setup.dashboards.enabled: true
# setup.kibana:
#   host: "http://localhost:5601" or IP
# output.elasticsearch:
#   hosts: ["http://localhost:9200"]
# output.logstash:
#   hosts: ["http://localhost:5044"] or IP

# nginx
# sudo nano /etc/nginx/conf.d/magento_es_auth.conf
# paste into file above: 
#server {
#  listen 8080;
#  location /_cluster/health {
#    proxy_pass http://localhost:9200/_cluster/health; #or IP
#  }
#}