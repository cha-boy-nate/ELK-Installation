#!/bin/bash

# Exit on error
set -e

# Variables for passwords
ELASTIC_PASSWORD="your_elastic_password"
KIBANA_PASSWORD="your_kibana_password"

# Function to stop and remove services if they exist
stop_and_remove_service() {
  SERVICE=$1
  if systemctl is-active --quiet $SERVICE; then
    echo "Stopping $SERVICE service..."
    sudo systemctl stop $SERVICE
  fi
  if systemctl is-enabled --quiet $SERVICE; then
    echo "Disabling $SERVICE service..."
    sudo systemctl disable $SERVICE
  fi
}

# Function to remove existing directories if they exist
remove_directory() {
  DIR=$1
  if [ -d "$DIR" ]; then
    echo "Removing $DIR..."
    sudo rm -rf "$DIR"
  fi
}

# Stop and remove existing Elasticsearch, Logstash, and Kibana services
stop_and_remove_service "elasticsearch"
stop_and_remove_service "logstash"
stop_and_remove_service "kibana"

# Remove existing configuration and data directories
remove_directory "/etc/elasticsearch"
remove_directory "/var/lib/elasticsearch"
remove_directory "/var/log/elasticsearch"
remove_directory "/etc/logstash"
remove_directory "/var/lib/logstash"
remove_directory "/var/log/logstash"
remove_directory "/etc/kibana"
remove_directory "/var/lib/kibana"
remove_directory "/var/log/kibana"

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
echo "Installing Elasticsearch..."
sudo apt install -y elasticsearch

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

# Check Elasticsearch status
if ! sudo systemctl is-active --quiet elasticsearch; then
  echo "Elasticsearch failed to start. Checking logs..."
  sudo journalctl -u elasticsearch -xe
  exit 1
fi

# Wait for Elasticsearch to start
echo "Waiting for Elasticsearch to start..."
sleep 20

# Set passwords for built-in users
echo "Setting passwords for built-in users..."
echo "y" | sudo /usr/share/elasticsearch/bin/elasticsearch-setup-passwords auto -u "http://localhost:9200"

# Install Logstash
echo "Installing Logstash..."
sudo apt install -y logstash

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
echo "Installing Kibana..."
sudo apt install -y kibana

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
