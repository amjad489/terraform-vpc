#!/bin/bash -v
sudo apt-get update -y
sudo apt-get install -y nginx > /tmp/nginx.log
sudo /etc/init.d/nginx start