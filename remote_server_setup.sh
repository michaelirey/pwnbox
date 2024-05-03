#!/bin/bash

# Back up the existing docker.list to docker.list.bak
sudo cp /etc/apt/sources.list.d/docker.list /etc/apt/sources.list.d/docker.list.bak

# Remove duplicate lines from docker.list
sudo sh -c 'awk "!seen[\$0]++" /etc/apt/sources.list.d/docker.list.bak > /etc/apt/sources.list.d/docker.list'

# Create or update the apt configuration to disable SSL peer verification
echo 'Acquire::https::Verify-Peer "false";' | sudo tee /etc/apt/apt.conf.d/99verify-peer.conf > /dev/null

echo "Configuration complete. SSL peer verification is now disabled."

chmod 755 ./port_scanner.sh

# Install ngrok
curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
	| sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null \
	&& echo "deb https://ngrok-agent.s3.amazonaws.com buster main" \
	| sudo tee /etc/apt/sources.list.d/ngrok.list \
	&& sudo apt update \
	&& sudo apt install ngrok

ngrok config add-authtoken ${NGROK_AUTH_TOKEN}

ngrok http http://localhost:1977
