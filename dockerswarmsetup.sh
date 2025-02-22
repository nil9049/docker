#!/bin/bash

# Define the worker IP file
WORKER_IP_FILE="workers.txt"
SSH_KEY="abcd.pem"
USER="ubuntu"

# Get the Manager IP (this machine)
MANAGER_IP=$(hostname -I | awk '{print $1}')
echo "Manager IP: $MANAGER_IP"
echo "Worker IP file: $WORKER_IP_FILE"

install_docker() {
    echo "Installing Docker on $1..."
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$USER@$1" <<EOF
        sudo apt update -y && sudo apt upgrade -y
        sudo apt install docker.io -y
        sudo systemctl restart docker
EOF
}

# Install Docker on Manager if not already installed
echo "Installing Docker on Manager..."
sudo apt update -y && sudo apt upgrade -y
sudo apt install docker.io -y
sudo systemctl restart docker

# Check if this machine is already a Swarm Manager
if docker info | grep -q "Swarm: active"; then
    echo "This server is already a Docker Swarm Manager."
else
    echo "Initializing Docker Swarm on Manager..."
    docker swarm init --advertise-addr "$MANAGER_IP"
fi

# Get Swarm Join Token
SWARM_JOIN_TOKEN=$(docker swarm join-token worker -q)

# Install Docker on Worker nodes
while read -r WORKER_IP; do
    install_docker "$WORKER_IP"
done < "$WORKER_IP_FILE"

# Function to join Worker nodes
join_worker() {
    echo "Joining worker $1 to swarm..."
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$USER@$1" <<EOF
        sudo docker swarm join --token $SWARM_JOIN_TOKEN $MANAGER_IP:2377
EOF
}

# Read worker IPs from file and join them to Swarm
while read -r WORKER_IP; do
    join_worker "$WORKER_IP"
done < "$WORKER_IP_FILE"

echo "Swarm setup complete. Checking status on Manager..."
docker node ls

