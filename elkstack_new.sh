#!/bin/bash

read -p "Node name: " node
read -p "Default user password: " password
read -p "Do you want to set your stack to use a loopback address? (Recommended for single node) (y/n): " isLoopback
echo "Note: Installation logs saved to /var/log/install/installLog.txt"
sed -i "/#\$nrconf{restart} = 'i';/s/.*/\$nrconf{restart} = 'a';/" /etc/needrestart/needrestart.conf
update() {
    sudo apt-get update -y
    sudo apt-get upgrade -y
}
installationScreen() {
  clear
  local package_name="$1"
  local log_file="/var/log/installLog.txt"
  if dpkg -l "$package_name" | grep -q "^ii "; then
    echo "Package $package_name is already installed."
    return
  fi
  sudo apt-get install "$package_name" -y > "$log_file" 2>&1 &
  local chars="/-\|"
  local i=0
  local pid=$!
  while ps -p $pid > /dev/null; do
    local char="${chars:$i:1}"
    echo -ne "\rInstalling $package_name [$char]"
    ((i = (i + 1) % 4))
    sleep 0.2
  done
  wait $pid
  if dpkg -l "$package_name" | grep -q "^ii "; then
    echo -e "\nPackage $package_name has been successfully installed."
  else
    echo -e "\nFailed to install $package_name. See $log_file for details."
  fi
}


installElasticsearch() {
    clear
    wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
    installationScreen "apt-transport-https"
    sudo sh -c 'echo "deb https://artifacts.elastic.co/packages/8.x/apt stable main" > /etc/apt/sources.list.d/elastic-8.x.list'
    update
    clear
    installationScreen "elasticsearch"
    sudo sed -i "s/#node.name: node-1/node.name: $node/" /etc/elasticsearch/elasticsearch.yml
    if [[ "$isLoopback" == "y" || "$isLoopback" == "Y" ]]; then
        sudo sed -i 's/#network.host: 192.168.0.1/network.host: '"0.0.0.0"'/' /etc/elasticsearch/elasticsearch.yml
        sudo sed -i 's/#discovery.seed_hosts: \["host1", "host2"\]/discovery.seed_hosts: \["127.0.0.1"\]/' /etc/elasticsearch/elasticsearch.yml
        echo -e "y\n$password\n$password" | /usr/share/elasticsearch/bin/elasticsearch-reset-password -i -u elastic -url "http://127.0.0.1:9200" > new_password
    elif [[ "$isLoopback" == "n" || "$isLoopback" == "N" ]]; then
        sudo sed -i 's/#network.host: 192.168.0.1/network.host: '"$ipaddr"'/' /etc/elasticsearch/elasticsearch.yml
        sudo sed -i 's/#discovery.seed_hosts: \["host1", "host2"\]/discovery.seed_hosts: \["'"$ipaddr"'\"]/' /etc/elasticsearch/elasticsearch.yml
        echo -e "y\n$password\n$password" | /usr/share/elasticsearch/bin/elasticsearch-reset-password -i -u elastic -url "http://$ipaddr:9200" > new_password
    else
        echo "Invalid input. Please enter y/n."
    fi
    #sudo sed -i 's/xpack.security.enabled: true/xpack.security.enabled: false/' /etc/elasticsearch/elasticsearch.yml
    
}
startElasticsearch() {
    clear
    sudo systemctl enable elasticsearch
    sudo systemctl start elasticsearch
    clear
    echo "Starting Elasticsearch..."
    sleep 10
}
installKibana() {
    clear
    installationScreen "kibana"
    clear
    enrollmentToken=$(sudo /usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana)
    sudo sed -i "s/# elasticsearch.serviceAccountToken: \"my_token\"/elasticsearch.serviceAccountToken: \"$enrollmentToken\"/" /etc/kibana/kibana.yml
    sudo sed -i 's/#server.port: 5601/server.port: 5601/' /etc/kibana/kibana.yml
    if [[ "$isLoopback" == "y" || "$isLoopback" == "Y" ]]; then
        sudo sed -i 's/#server.host: "localhost"/server.host: "0.0.0.0"/' /etc/kibana/kibana.yml
        sudo sed -i 's/#elasticsearch.hosts: ["http://localhost:9200"]/elasticsearch.hosts: ["http://localhost:9200"]/' /etc/kibana/kibana.yml
    elif [[ "$isLoopback" == "n" || "$isLoopback" == "N" ]]; then
        sudo sed -i 's/#server.host: "localhost"/server.host: "'$ipaddr'"/' /etc/kibana/kibana.yml
        sudo sed -i 's/#elasticsearch.hosts: \["http://localhost:9200"\]/elasticsearch.hosts: ["http://'$ipaddr':9200"]/' /etc/kibana/kibana.yml
    fi
}
startKibana() {
    clear
    sudo systemctl enable kibana
    sudo systemctl start kibana
    clear
    echo "Starting Kibana..."
    sleep 5
}

installLogstash() {
    clear
    installationScreen "logstash"
    sudo sed -i "s/#output.elasticsearch: /output.elasticsearch:" /etc/logstash/logstash.yml
    sudo sed -i "s/#hosts: \["http://localhost:9200"\]/hosts: \["http://localhost:9200"\]" /etc/logstash/logstash.yml
}
startLogstash() {
    clear
    sudo systemctl enable logstash
    sudo systemctl start logstash
    clear
    echo "Starting Logstash..."
    sleep 5
}
installMetricbeat() {
    installationScreen "metricbeat"
    sudo sed -i "s/#setup.kibana:/setup.kibana:" /etc/metricbeat/metricbeat.yml
    sudo sed -i "s/ #host: "localhost:5601"/ host: "localhost:5601"" /etc/metricbeat/metricbeat.yml
    sudo sed -i "s/#output.elasticsearch:/output.elasticsearch:" /etc/metricbeat/metricbeat.yml
    sudo sed -i "s/ #hosts: \["localhost:9200"\]/ hosts: \["http://localhost:9200"\]" /etc/metricbeat/metricbeat.yml
}
startMetricbeat() {
    clear
    sudo systemctl enable metricbeat
    sudo systemctl start metricbeat
    clear
    echo "Starting Metricbeat..."
    sleep 5
}
installFilebeat() {
    installationScreen "filebeat"
    sudo sed -i "s/ enabled: false/ enabled: true/" /etc/filebeat/filebeat.yml
    sudo sed -i "s/#setup.kibana:/setup.kibana:" /etc/filebeat/filebeat.yml
    sudo sed -i "s/ #host: "localhost:5601"/ host: "localhost:5601"" /etc/filebeat/filebeat.yml
    sudo sed -i "s/#output.elasticsearch:/output.elasticsearch:" /etc/filebeat/filebeat.yml
    sudo sed -i "s/ #hosts: \["localhost:9200"\]/ hosts: \["http://localhost:9200"\]" /etc/filebeat/filebeat.yml
    sudo sed -i "s/#output.logstash:/output.logstash:" /etc/filebeat/filebeat.yml
    sudo sed -i "s/ #hosts: \["localhost:5044"\]/ hosts: \["http://localhost:5044"\]" /etc/filebeat/filebeat.yml

}
startFilebeat(){
    clear
    sudo systemctl enable filebeat
    sudo systemctl start filebeat
    clear
    echo "Starting Filebeat..."
    sleep 5
}

installNginx() {
    installationScreen "nginx"
    sudo touch /etc/nginx/conf.d/magento_es_auth.conf
    echo 'server {
      listen 8080;
      location /_cluster/health {
        proxy_pass http://localhost:9200/_cluster/health; #or IP
  }
}' > magento_es_auth.conf
}

startNginx(){
    clear
    sudo systemctl enable nginx
    sudo systemctl start nginx
    clear
    echo "Starting Nginx..."
    sleep 5
}

update
installationScreen "net-tools"
installationScreen "curl"
ipaddr=$(ifconfig | grep -oE 'inet (addr:)?([0-9]*\.){3}[0-9]*' | awk '{print $NF; exit}')
installElasticsearch
startElasticsearch
installKibana
startKibana
installLogstash
startLogstash
installMetricbeat
startMetricbeat
installFilebeat
startFilebeat
installNginx
startNginx
