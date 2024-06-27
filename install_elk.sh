#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

LOG_FILE="elk_install.log"
echo "Starting ELK installation..." | tee -a $LOG_FILE

# Update and install prerequisites
echo "Updating and installing prerequisites..." | tee -a $LOG_FILE
sudo apt update | tee -a $LOG_FILE
sudo apt upgrade -y | tee -a $LOG_FILE
sudo apt install -y apt-transport-https openjdk-11-jdk wget curl gnupg | tee -a $LOG_FILE

# Add the Elastic GPG key
echo "Adding the Elastic GPG key..." | tee -a $LOG_FILE
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add - | tee -a $LOG_FILE

# Add the Elastic repository
echo "Adding the Elastic repository..." | tee -a $LOG_FILE
sudo sh -c 'echo "deb https://artifacts.elastic.co/packages/8.x/apt stable main" > /etc/apt/sources.list.d/elastic-8.x.list'

# Update package lists
echo "Updating package lists..." | tee -a $LOG_FILE
sudo apt update | tee -a $LOG_FILE

# Install Elasticsearch
echo "Installing Elasticsearch..." | tee -a $LOG_FILE
sudo apt install -y elasticsearch | tee -a $LOG_FILE

# Configure Elasticsearch
echo "Configuring Elasticsearch..." | tee -a $LOG_FILE
sudo bash -c 'cat << EOF > /etc/elasticsearch/elasticsearch.yml
cluster.name: "myCluster"
node.name: "node-1"
network.host: "localhost"
http.port: 9200
discovery.type: single-node
EOF'

# Ensure necessary directories exist
echo "Ensuring necessary directories exist..." | tee -a $LOG_FILE
sudo mkdir -p /var/lib/elasticsearch
sudo mkdir -p /var/log/elasticsearch

# Set ownership and permissions
echo "Setting ownership and permissions..." | tee -a $LOG_FILE
sudo chown -R elasticsearch:elasticsearch /etc/elasticsearch /var/lib/elasticsearch /var/log/elasticsearch

# Start and enable Elasticsearch service
echo "Starting and enabling Elasticsearch service..." | tee -a $LOG_FILE
sudo systemctl daemon-reload | tee -a $LOG_FILE
sudo systemctl enable elasticsearch | tee -a $LOG_FILE
sudo systemctl start elasticsearch | tee -a $LOG_FILE

# Wait for Elasticsearch to start
echo "Waiting for Elasticsearch to start..." | tee -a $LOG_FILE
sleep 20

# Check Elasticsearch status
echo "Checking Elasticsearch status..." | tee -a $LOG_FILE
if ! sudo systemctl is-active --quiet elasticsearch; then
  echo "Elasticsearch failed to start. Checking logs..." | tee -a $LOG_FILE
  sudo journalctl -u elasticsearch -xe | tee -a $LOG_FILE
  sudo cat /var/log/elasticsearch/elasticsearch.log | tee -a $LOG_FILE
  exit 1
fi
echo "Elasticsearch started successfully." | tee -a $LOG_FILE

# Install Logstash
echo "Installing Logstash..." | tee -a $LOG_FILE
sudo apt install -y logstash | tee -a $LOG_FILE

# Configure Logstash
echo "Configuring Logstash..." | tee -a $LOG_FILE
sudo mkdir -p /etc/logstash/conf.d
sudo bash -c 'cat << EOF > /etc/logstash/conf.d/logstash.conf
input {
  beats {
    port => 5044
  }
}
output {
  elasticsearch {
    hosts => ["localhost:9200"]
  }
  stdout { codec => rubydebug }
}
EOF'

# Start and enable Logstash service
echo "Starting and enabling Logstash service..." | tee -a $LOG_FILE
sudo systemctl enable logstash | tee -a $LOG_FILE
sudo systemctl start logstash | tee -a $LOG_FILE

# Wait for Logstash to start
echo "Waiting for Logstash to start..." | tee -a $LOG_FILE
sleep 20

# Check Logstash status
echo "Checking Logstash status..." | tee -a $LOG_FILE
if ! sudo systemctl is-active --quiet logstash; then
  echo "Logstash failed to start. Checking logs..." | tee -a $LOG_FILE
  sudo journalctl -u logstash -xe | tee -a $LOG_FILE
  sudo cat /var/log/logstash/logstash-plain.log | tee -a $LOG_FILE
  exit 1
fi
echo "Logstash started successfully." | tee -a $LOG_FILE

# Install Kibana
echo "Installing Kibana..." | tee -a $LOG_FILE
sudo apt install -y kibana | tee -a $LOG_FILE

# Configure Kibana
echo "Configuring Kibana..." | tee -a $LOG_FILE
sudo bash -c 'cat << EOF > /etc/kibana/kibana.yml
server.port: 5601
server.host: "localhost"
elasticsearch.hosts: ["http://localhost:9200"]
EOF'

# Start and enable Kibana service
echo "Starting and enabling Kibana service..." | tee -a $LOG_FILE
sudo systemctl enable kibana | tee -a $LOG_FILE
sudo systemctl start kibana | tee -a $LOG_FILE

# Wait for Kibana to start
echo "Waiting for Kibana to start..." | tee -a $LOG_FILE
sleep 20

# Check Kibana status
echo "Checking Kibana status..." | tee -a $LOG_FILE
if ! sudo systemctl is-active --quiet kibana; then
  echo "Kibana failed to start. Checking logs..." | tee -a $LOG_FILE
  sudo journalctl -u kibana -xe | tee -a $LOG_FILE
  sudo cat /var/log/kibana/kibana.log | tee -a $LOG_FILE
  exit 1
fi
echo "Kibana started successfully." | tee -a $LOG_FILE

echo "ELK Stack installation and configuration completed successfully." | tee -a $LOG_FILE
echo "You can access Kibana at http://localhost:5601." | tee -a $LOG_FILE
