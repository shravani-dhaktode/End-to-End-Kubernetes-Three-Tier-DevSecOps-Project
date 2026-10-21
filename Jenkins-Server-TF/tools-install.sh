#!/bin/bash
# Runs automatically ONE time when the Jenkins EC2 server first boots (Ubuntu 24.04).
# Takes about 8-10 minutes. Progress log: /var/log/tools-install.log
# When everything is finished the file /home/ubuntu/SETUP_DONE is created.
# NOTE: this file is read by Terraform's templatefile(), so never use the dollar-brace syntax here.

exec > /var/log/tools-install.log 2>&1
set -x
export DEBIAN_FRONTEND=noninteractive

# ---------- Swap (extra safety memory) ----------
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# ---------- Basic packages ----------
apt-get update -y
apt-get install -y fontconfig curl wget unzip gnupg git jq ca-certificates

# ---------- Java 21 (Jenkins needs Java 21+) ----------
apt-get install -y openjdk-21-jre
java -version

# ---------- Jenkins (LTS) ----------
mkdir -p /etc/apt/keyrings
wget -O /etc/apt/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" > /etc/apt/sources.list.d/jenkins.list
apt-get update -y
apt-get install -y jenkins
systemctl enable jenkins
systemctl start jenkins

# ---------- Docker ----------
apt-get install -y docker.io
usermod -aG docker jenkins
usermod -aG docker ubuntu
systemctl enable docker
systemctl restart docker
chmod 777 /var/run/docker.sock
# Jenkins must be restarted to pick up the docker group
systemctl restart jenkins

# ---------- SonarQube (runs as a Docker container on port 9000) ----------
sysctl -w vm.max_map_count=524288
echo 'vm.max_map_count=524288' >> /etc/sysctl.conf
docker run -d --name sonar --restart unless-stopped -p 9000:9000 sonarqube:community

# ---------- Node.js 20 ----------
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# ---------- AWS CLI v2 ----------
cd /tmp
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip -q awscliv2.zip
./aws/install
aws --version

# ---------- kubectl (latest stable) ----------
KVER=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -sLO "https://dl.k8s.io/release/$KVER/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/
kubectl version --client

# ---------- eksctl ----------
curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" | tar xz -C /tmp
mv /tmp/eksctl /usr/local/bin
eksctl version

# ---------- Helm ----------
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

# ---------- Trivy (pinned to a known-good version) ----------
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin v0.58.1
trivy --version

# ---------- Done ----------
echo "All tools installed at $(date)" > /home/ubuntu/SETUP_DONE
chown ubuntu:ubuntu /home/ubuntu/SETUP_DONE
