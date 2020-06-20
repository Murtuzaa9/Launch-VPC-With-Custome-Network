#!/bin/bash
# Author: Murtuza Ansari
# Note : This is fresh VM so we already know that we need to install java and elasticsearch which is not installed by default in fresh VM.

cat >> /etc/yum.repos.d/elasticsearch.repo << EOF
[elasticsearch-7.x]
name=Elasticsearch repository for 7.x packages
baseurl=https://artifacts.elastic.co/packages/7.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOF

yum install unzip java elasticsearch  -y
systemctl daemon-reload 
systemctl enable elasticsearch.service && systemctl start elasticsearch.service  

hostnamectl set-hostname node1.elastic.com
echo "$(hostname -I) node1.elastic.com  node1" >> /etc/hosts

#Set environment variables
ES_HOME=/usr/share/elasticsearch
ES_PATH_CONF=/etc/elasticsearch
mkdir -pv /home/ec2-user/tmp/cert_blog && cd /home/ec2-user/tmp/cert_blog

#Creating instance yaml file and add the instance information to yml file
cat >> /home/ec2-user/tmp/cert_blog/instance.yml << EOF
# add the instance information to yml file
instances:
  - name: 'node1'
    dns: [ 'node1.elastic.com' ]
EOF

#Generating CA and server certificates
cd $ES_HOME
bin/elasticsearch-certutil cert ca --pem --in /home/ec2-user/tmp/cert_blog/instance.yml --out /home/ec2-user/tmp/cert_blog/certs.zip &> /dev/null
cd /home/ec2-user/tmp/cert_blog && unzip certs.zip -d ./certs

#Creating certs directory and copying certificates into this directory
cd $ES_PATH_CONF  && mkdir certs 
cp /home/ec2-user/tmp/cert_blog/certs/ca/ca.crt /home/ec2-user/tmp/cert_blog/certs/node1/* certs

#Configuring elasticsearch.yml
echo "node.name: node1" >> elasticsearch.yml
echo "network.host: node1.elastic.com"  >> elasticsearch.yml
echo "xpack.security.enabled: true" >> elasticsearch.yml
echo "xpack.security.http.ssl.enabled: true" >> elasticsearch.yml
echo "xpack.security.transport.ssl.enabled: true" >> elasticsearch.yml
echo "xpack.security.http.ssl.key: certs/node1.key" >> elasticsearch.yml
echo "xpack.security.http.ssl.certificate: certs/node1.crt" >> elasticsearch.yml
echo "xpack.security.http.ssl.certificate_authorities: certs/ca.crt" >> elasticsearch.yml
echo "xpack.security.transport.ssl.key: certs/node1.key" >> elasticsearch.yml
echo "xpack.security.transport.ssl.certificate: certs/node1.crt" >> elasticsearch.yml
echo "xpack.security.transport.ssl.certificate_authorities: certs/ca.crt" >> elasticsearch.yml
echo "discovery.seed_hosts: [ "node1.elastic.com" ]" >> elasticsearch.yml
echo "cluster.initial_master_nodes: [ "node1" ]" >> elasticsearch.yml

#Restaring Elasticsearch service
systemctl restart elasticsearch.service

#Set built-in user passwords"
cd $ES_HOME
echo y | bin/elasticsearch-setup-passwords auto -u "https://node1.elastic.com:9200" > /tmp/password.txt
