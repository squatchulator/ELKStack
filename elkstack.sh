#!/bin/bash

# Read user inputs for the node name and for the password 
read -p "What would you like the name for this node to be? " node
#read -p "What would you like the password for 'elastic' to be? " password

sudo apt update
sudo apt upgrade -y

# Install Java (required by Elasticsearch)
sudo apt install openjdk-11-jre-headless -y

# Install net-tools for ifconfig command
sudo apt install net-tools && sudo apt install curl
sudo apt-get install apt-transport-https

#Assign IP address to variable
ipaddress=$(ifconfig | grep -oE 'inet (addr:)?([0-9]*\.){3}[0-9]*' | awk '{print $NF; exit}')


# Import the Elasticsearch GPG key
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg

# Add the Elasticsearch APT repository
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list

# Update package index
sudo apt update

# Install Elasticsearch
sudo apt install elasticsearch -y

# Change the default password
#sudo echo -e "y\n$password\n$password" | sudo /usr/share/elasticsearch/bin/elasticsearch-reset-password -i -u elastic -url "https://$ipaddress:9200"

# Configure Elasticsearch
sudo sed -i "s/#node.name: node-1/node.name: $node/I" /etc/elasticsearch/elasticsearch.yml
sudo sed -i 's/#network.host: 192.168.0.1/network.host: '"$ipaddress"'/' /etc/elasticsearch/elasticsearch.yml
sudo sed -i 's/#http.port: 9200/http.port: 9200/' /etc/elasticsearch/elasticsearch.yml
sudo sed -i 's/xpack.security.enabled: true/xpack.security.enabled: false/' /etc/elasticsearch/elasticsearch.yml

# Enable and start Elasticsearch service
sudo systemctl enable elasticsearch
sudo systemctl start elasticsearch

# Wait for Elasticsearch to start
clear
echo "Starting elasticsearch, please wait..."
sleep 10

# Install Kibana
sudo apt install kibana

# Generate the enrollment token 
token=$(sudo /usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana)

# Edit the Kibana configuration file 
sudo sed -i 's/#server.port: 5601/server.port: 5601/' /etc/kibana/kibana.yml
sudo sed -i 's/#server.host: "localhost"/server.host: '"$ipaddress"'/' /etc/kibana/kibana.yml
sudo sed -i 's/# elasticsearch.serviceAccountToken: "my_token"/elasticsearch.serviceAccountToken: '"$token"'/' /etc/kibana/kibana.yml

# Start kibana
sudo systemctl enable kibana
sudo systemctl start kibana
sudo systemctl restart elastic
clear
echo "Elasticsearch setup completed!"
echo "You can view your Kibana dashboard at https://$ipaddress:5601."
