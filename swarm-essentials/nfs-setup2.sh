#!/bin/bash

# Create and configure the NFS share directory
mkdir -p /var/nfsshare
chmod -R 755 /var/nfsshare
chown nobody:nogroup /var/nfsshare

# Install required NFS packages
apt update
apt install -y nfs-kernel-server

# Enable and start required services
systemctl enable nfs-server
systemctl start nfs-server

# Configure exports
echo "/var/nfsshare    *(rw,sync,no_root_squash,no_subtree_check)" > /etc/exports

# Restart NFS server to apply changes
exportfs -arv
systemctl restart nfs-server

echo "NFS server setup complete. The shared directory is: /var/nfsshare"
