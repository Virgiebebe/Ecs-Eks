#!/bin/bash
set -e

echo "=== Removing old Docker versions ==="
sudo apt-get remove -y docker docker-engine docker.io containerd runc || true

echo "=== Updating system and installing prerequisites ==="
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

echo "=== Adding Docker GPG key ==="
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "=== Adding Docker repository ==="
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release; echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "=== Installing Docker Engine ==="
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "=== Enabling Docker service ==="
sudo systemctl enable docker
sudo systemctl start docker

echo "=== Adding current user to docker group (optional) ==="
sudo usermod -aG docker $USER

echo "=== DONE! ==="
echo "Log out and back in to use Docker without sudo."
echo "Test with: docker run hello-world"
