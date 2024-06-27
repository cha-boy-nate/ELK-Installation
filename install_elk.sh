#!/bin/bash

# Exit on error
set -e

# Function to fetch the latest version of a package
get_latest_version() {
  PACKAGE=$1
  curl -s "https://www.elastic.co/downloads/past-releases/$PACKAGE" | grep -oP '">'"$PACKAGE"'-\K[0-9]+\.[0-9]+\.[0-9]+' | head -1
}

# Fetch the latest versions
ES_VERSION=$(get_latest_version "elasticsearch")
LOGSTASH_VERSION=$(get_latest_version "logstash")
KIBANA_VERSION=$(get_latest_version "kibana")

# Variables for passwords
ELASTIC_PASSWORD="your_elastic_password"
KIBANA_PASSWORD="your_kibana_password"

# Update and install prerequisites
echo "Updating and installing prerequisites..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y apt-transport-https openjdk-11-jdk wget curl gnupg

# Add the Elastic GPG key
echo "Adding the Elastic GPG key..."
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -

# Add the Elastic repository
echo "Adding the Elastic repository..."
sudo sh -c 'echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" > /etc/apt/sources.list.d/elastic-7.x.list'

# Update package lists
sudo apt update

# Install Elasticsearch
echo "Installing Elasticsearch version $ES_VERSION..."
sudo apt install -y elasticsearch=$ES_VERSION

# Configure Elasticsearch
echo "Configuring Elasticsearch..."
sudo bash -c 'cat << EOF > /etc/elasticsearch/elasticsearch.yml
cluster.name: "myCluster"
node.name: "node-1"
network.host: "localhost"
http.port: 9200
discovery.type: single-node
xpack.security.enabled: true
EOF'

# Start and enable Elasticsearch service
echo "Starting Elasticsearch service..."
sudo systemctl daemon-reload
sudo systemctl enable elasticsearch
sudo systemctl start elasticsearch

# Wait for Elasticsearch to start and set the elastic user's password
echo "Waiting for Elasticsearch to start..."
until curl -s -X POST "localhost:9200/_security/user/elastic/_password" -H "Content-Type: application/json" -u elastic:changeme -d "{ \"password\": \"$ELASTIC_PASSWORD\" }"; do
  echo "Elasticsearch is not ready yet. Waiting..."
  sleep 5
done

echo "Elasticsearch is running."

# Install Logstash
echo "Installing Logstash version $LOGSTASH_VERSION..."
sudo apt install -y logstash=$LOGSTASH_VERSION

# Configure Logstash (this is a basic config, adjust as needed)
echo "Configuring Logstash..."
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
echo "Starting Logstash service..."
sudo systemctl enable logstash
sudo systemctl start logstash

# Install Kibana
echo "Installing Kibana version $KIBANA_VERSION..."
sudo apt install -y kibana=$KIBANA_VERSION

# Configure Kibana
echo "Configuring Kibana..."
sudo bash -c 'cat << EOF > /etc/kibana/kibana.yml
server.port: 5601
server.host: "localhost"
elasticsearch.hosts: ["http://localhost:9200"]
elasticsearch.username: "elastic"
elasticsearch.password: "$ELASTIC_PASSWORD"
xpack.security.enabled: true
EOF'

# Start and enable Kibana service
echo "Starting Kibana service..."
sudo systemctl enable kibana
sudo systemctl start kibana

# Set the kibana user's password
echo "Setting Kibana user password..."
until curl -s -X POST "localhost:9200/_security/user/kibana/_password" -H "Content-Type: application/json" -u elastic:$ELASTIC_PASSWORD -d "{ \"password\": \"$KIBANA_PASSWORD\" }"; do
  echo "Kibana is not ready yet. Waiting..."
  sleep 5
done

echo "ELK Stack installation and configuration completed."
echo "You can access Kibana at http://localhost:5601 with username 'elastic' and the password you set."
