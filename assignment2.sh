#!/bin/bash
# assignment2.sh - Configure server1 automatically
# Author: Jaskaran
# Date: $(date)
# Description: Ensures server1 matches the target configuration (network, software, users, keys, etc.)

set -e  # stop on first error

echo "=============================================="
echo "  Assignment 2 Configuration Script for server1"
echo "=============================================="
echo

# Ensure running as root
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: Please run this script as root."
  exit 1
fi

echo
echo "Configuring Network..."
echo "----------------------"

# Find the netplan file (usually in /etc/netplan)
NETPLAN_FILE=$(ls /etc/netplan/*.yaml 2>/dev/null | head -n1)

# If no netplan file exists, create one
if [ -z "$NETPLAN_FILE" ]; then
  NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"
  echo "No netplan file found, creating $NETPLAN_FILE"
  cat <<EOF > $NETPLAN_FILE
network:
  version: 2
  ethernets:
    eth0:
      addresses: [192.168.16.21/24]
      dhcp4: no
EOF
else
  # Backup netplan if not already backed up
  if [ ! -f "${NETPLAN_FILE}.bak" ]; then
    cp $NETPLAN_FILE ${NETPLAN_FILE}.bak
    echo "Backup created: ${NETPLAN_FILE}.bak"
  fi

  # Update existing IP
  sed -i 's|addresses: \[192\.168\.16\.[0-9]\+/24\]|addresses: [192.168.16.21/24]|' $NETPLAN_FILE
fi

# Apply netplan (may warn in container)
netplan apply || echo "Warning: netplan apply may not run inside container"

# Fix /etc/hosts
if grep -q "server1" /etc/hosts; then
  sed -i 's|192\.168\.16\.[0-9]\+ server1|192.168.16.21 server1|' /etc/hosts
else
  echo "192.168.16.21 server1" >> /etc/hosts
fi

echo "Network configuration updated successfully."  

echo
echo "Installing required software..."
echo "-------------------------------"

# Update package list
apt update -y

# Install Apache2 if not installed
if ! dpkg -l | grep -qw apache2; then
    apt install -y apache2
    echo "Apache2 installed"
else
    echo "Apache2 already installed"
fi

# Install Squid if not installed
if ! dpkg -l | grep -qw squid; then
    apt install -y squid
    echo "Squid installed"
else
    echo "Squid already installed"
fi

# Enable and start services
systemctl enable apache2
systemctl start apache2
systemctl enable squid
systemctl start squid

echo "Software setup completed successfully."

echo
echo "Creating users..."
echo "----------------"

# List of users to create
USER_LIST=(dennis aubrey captain snibbles brownie scooter sandy perrier cindy tiger yoda)

for user in "${USER_LIST[@]}"; do
  # Create user if it doesn't exist
  if ! id -u $user &>/dev/null; then
    useradd -m -s /bin/bash $user
    echo "User $user created"
  else
    echo "User $user already exists"
  fi

  # Setup SSH directory
  SSH_DIR="/home/$user/.ssh"
  mkdir -p $SSH_DIR
  chown $user:$user $SSH_DIR
  chmod 700 $SSH_DIR

  # Generate SSH keys if they don't exist
  if [ ! -f "$SSH_DIR/id_rsa" ]; then
    sudo -u $user ssh-keygen -t rsa -f $SSH_DIR/id_rsa -N ""
  fi
  if [ ! -f "$SSH_DIR/id_ed25519" ]; then
    sudo -u $user ssh-keygen -t ed25519 -f $SSH_DIR/id_ed25519 -N ""
  fi

  # Add public keys to authorized_keys
  cat $SSH_DIR/id_rsa.pub $SSH_DIR/id_ed25519.pub >> $SSH_DIR/authorized_keys
  chmod 600 $SSH_DIR/authorized_keys
  chown $user:$user $SSH_DIR/authorized_keys

  # Special configuration for dennis
  if [ "$user" == "dennis" ]; then
    usermod -aG sudo dennis
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm" >> $SSH_DIR/authorized_keys
  fi
done

echo "All user accounts configured successfully."

