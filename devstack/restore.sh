#!/bin/bash


source ~/adminrc.sh


# Recreate the loop devices for the physical volumes
# on which Cinder volumes reside
#
if losetup -a | grep -q /opt/stack/data/stack-volumes
then echo loop devices are already set up
else
    sudo losetup -f --show --direct-io=on /opt/stack/data/stack-volumes-default-backing-file
    sudo losetup -f --show --direct-io=on /opt/stack/data/stack-volumes-lvmdriver-1-backing-file
    echo restarting Cinder Volume service
    sudo systemctl restart devstack@c-vol
fi
sudo lvs # there should be one logical volume
sleep 1
openstack volume service list # all services should be up and running


# Octavia requires a directory for its UNIX sockets
# and specific IP and MAC addresses on the o-hm0 network interface.
# o-hm0 is required to communicate with the loadbalancer instances.
#
echo
echo recreating /var/run/octavia
sudo mkdir /var/run/octavia
sudo chown stack /var/run/octavia
echo

# Set o-hm0 up if it is down
#
echo setting up the o-hm0 interface
if ip l show o-hm0 | grep -q 'state DOWN'
then sudo ip l set o-hm0 up
else echo o-hm0 interface is not DOWN
fi

# Get MAC and IP address from the Neutron port for the load balancer instance
#
HM0_IP=$(openstack port show octavia-health-manager-standalone-listen-port -c fixed_ips  -f yaml | grep ip_address | cut -f3 -d' ')
HM0_MAC=$(openstack port show octavia-health-manager-standalone-listen-port -c mac_address -f value)

# Configure o-hm0 with these addresses
#
if ip a show dev o-hm0 | grep -q $HM0_IP
then echo o-hm0 interface has IP address
else sudo ip a add ${HM0_IP}/24 dev o-hm0
fi
sudo ip link set dev o-hm0 address $HM0_MAC
echo o-hm0 MAC address set to $HM0_MAC
echo route to loadbalancer network:
ip r show 192.168.0.0/24
echo

# Add netfilter rules. They could be configured in a /etc/sysconfig file
# instead of this script.
#
echo fix netfilter for Octavia
sudo iptables -A INPUT -i o-hm0 -p udp -m udp --dport 20514 -j ACCEPT
sudo iptables -A INPUT -i o-hm0 -p udp -m udp --dport 10514 -j ACCEPT
sudo iptables -A INPUT -i o-hm0 -p udp -m udp --dport 5555 -j ACCEPT
