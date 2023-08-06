#!/bin/bash

# Read user inputs for the node name and for the password 
read -p "What would you like the name for this node to be? " node
read -p "What would you like the password for 'elastic' to be? " password

sudo apt update
sudo apt upgrade -y

# Install Java (required by Elasticsearch)
sudo apt install openjdk-11-jre-headless -y

# Install net-tools for ifconfig command
sudo apt install net-tools && sudo apt install curl

#Assign IP address to variable
ipaddress=$(ifconfig | grep -oE 'inet (addr:)?([0-9]*\.){3}[0-9]*' | awk '{print $NF; exit}')


# Import the Elasticsearch GPG key
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -

# Add the Elasticsearch APT repository
sudo sh -c 'echo "deb https://artifacts.elastic.co/packages/8.x/apt stable main" > /etc/apt/sources.list.d/elastic-8.x.list'

# Update package index
sudo apt update

# Install Elasticsearch
sudo apt install elasticsearch -y

# Configure Elasticsearch
sudo sed -i "s/#node.name: node-1/node.name: $node/I" /etc/elasticsearch/elasticsearch.yml
sudo sed -i 's/#network.host: 192.168.0.1/network.host: '"$ipaddress"'/' /etc/elasticsearch/elasticsearch.yml
sudo sed -i 's/#http.port: 9200/http.port: 9200/' /etc/elasticsearch/elasticsearch.yml

# Enable and start Elasticsearch service
sudo systemctl enable elasticsearch
sudo systemctl start elasticsearch

# Wait for Elasticsearch to start
sleep 10



# Change the default password
echo -e "y\n$password\n$password" | /usr/share/elasticsearch/bin/elasticsearch-reset-password -i -u elastic -url "https://$ipaddress:9200"

# Install Kibana
#sudo apt install kibana
#sudo sed -i 's/#server.port: 5601/server.port: 5601/' /etc/kibana/kibana.yml
#sudo sed -i 's/#server.host: "localhost"/server.host: $ipaddress/I' /etc/kibana.kibana.yml

# Generate the enrollment token 
#token=$(sudo /usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana)
# Edit the Kibana configuration file 
#sudo sed -i "s/# elasticsearch.serviceAccountToken: #\"my_token\"/elasticsearch.serviceAccountToken: \$token\/" /etc/kibana/kibana.yml

# Start kibana
#sudo systemctl enable kibana
#sudo systemctl start kibana

# Test Elasticsearch
curl -X GET "http://$ipaddress:9200/"

echo "Elasticsearch setup completed."
echo "Your password for the user 'elastic' is $password. Please change this ASAP."
