#!/bin/bash

# Exit on error
set -e

# Variables
ES_VERSION="7.17.0"
LOGSTASH_VERSION="7.17.0"
KIBANA_VERSION="7.17.0"
ELASTIC_PASSWORD="your_elastic_password"
KIBANA_PASSWORD="your_kibana_password"

# Update and install prerequisites
sudo apt update && sudo apt upgrade -y
sudo apt install -y apt-transport-https openjdk-11-jdk wget curl gnupg

# Add the Elastic GPG key
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -

# Add the Elastic repository
sudo sh -c 'echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" > /etc/apt/sources.list.d/elastic-7.x.list'

# Update and install Elasticsearch
sudo apt update
sudo apt install -y elasticsearch=$ES_VERSION

# Configure Elasticsearch
sudo bash -c 'cat << EOF > /etc/elasticsearch/elasticsearch.yml
cluster.name: "myCluster"
node.name: "node-1"
network.host: "localhost"
http.port: 9200
discovery.type: single-node
xpack.security.enabled: true
EOF'

# Start and enable Elasticsearch service
sudo systemctl enable elasticsearch
sudo systemctl start elasticsearch

# Set the elastic user's password
until curl -s -X POST "localhost:9200/_security/user/elastic/_password" -H "Content-Type: application/json" -u elastic:changeme -d "{ \"password\": \"$ELASTIC_PASSWORD\" }"; do
  echo "Waiting for Elasticsearch to start..."
  sleep 5
done

# Install Logstash
sudo apt install -y logstash=$LOGSTASH_VERSION

# Configure Logstash (this is a basic config, adjust as needed)
sudo bash -c 'cat << EOF > /etc/logstash/conf.d/logstash.conf
input {
  beats {
    port => 5044
  }
}

output {
  elasticsearch {
    hosts => ["localhost:9200"]
    user => "elastic"
    password => "$ELASTIC_PASSWORD"
  }
  stdout { codec => rubydebug }
}
EOF'

# Start and enable Logstash service
sudo systemctl enable logstash
sudo systemctl start logstash

# Install Kibana
sudo apt install -y kibana=$KIBANA_VERSION

# Configure Kibana
sudo bash -c 'cat << EOF > /etc/kibana/kibana.yml
server.port: 5601
server.host: "localhost"
elasticsearch.hosts: ["http://localhost:9200"]
elasticsearch.username: "elastic"
elasticsearch.password: "$ELASTIC_PASSWORD"
xpack.security.enabled: true
EOF'

# Start and enable Kibana service
sudo systemctl enable kibana
sudo systemctl start kibana

# Set the kibana user's password
until curl -s -X POST "localhost:9200/_security/user/kibana/_password" -H "Content-Type: application/json" -u elastic:$ELASTIC_PASSWORD -d "{ \"password\": \"$KIBANA_PASSWORD\" }"; do
  echo "Waiting for Kibana to start..."
  sleep 5
done

echo "ELK Stack installation and configuration completed."
echo "You can access Kibana at http://localhost:5601 with username 'elastic' and the password you set."
