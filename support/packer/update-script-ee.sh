#!/bin/bash -x
sleep 30

# Configuring repo for future updates
sudo apt-get update
sudo debconf-set-selections <<< 'postfix postfix/mailname string your.hostname.com'
sudo debconf-set-selections <<< 'postfix postfix/main_mailer_type string "Internet Site"'
sudo apt-get install -y curl openssh-server ca-certificates postfix
curl -sS https://packages.gitlab.com/install/repositories/gitlab/gitlab-ee/script.deb.sh | sudo bash

# Downloading package from S3 bucket
curl -o gitlab.deb "$DOWNLOAD_URL"
# Explicitly passing EXTERNAL_URL to prevent automatic EC2 IP detection.
sudo EXTERNAL_URL="http://gitlab.example.com" dpkg -i gitlab.deb
sudo rm gitlab.deb

# Set install type to aws
echo "gitlab-aws-ami" | sudo tee /opt/gitlab/embedded/service/gitlab-rails/INSTALLATION_TYPE > /dev/null

# Cleanup
sudo rm -rf /var/lib/apt/lists/*
sudo find /root/.*history /home/*/.*history -exec rm -f {} \;
sudo rm -f /home/ubuntu/.ssh/authorized_keys /root/.ssh/authorized_keys

sudo mv ~/ami-startup-script.sh /var/lib/cloud/scripts/per-instance/gitlab
sudo chmod +x /var/lib/cloud/scripts/per-instance/gitlab
