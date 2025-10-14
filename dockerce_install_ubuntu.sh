#!/bin/bash

# Remove any existing Docker packages
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

# Install Docker
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add current user to docker group (no automatic switching)
sudo usermod -aG docker $USER

echo "=================================================="
echo "Docker installed successfully!"
echo "=================================================="
echo "Important: Please perform ONE of the following to activate docker group permissions:"
echo ""
echo "  1. Log out completely and log back in (recommended)"
echo "  2. Or run: newgrp docker"
echo ""
echo "After that, you can run docker commands without sudo."
echo "Currently installed Docker version:"
docker --version 2>/dev/null || echo "(Will be available after re-login)"
