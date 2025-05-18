#!/bin/bash

# Initialize a variable to track whether the service needs to be restarted
restart_service=0

# Fetch the current public IPv4
newip4=$(curl -s ifconfig.co -4)

# Fetch the current public IPv6
newip6=$(curl -s ifconfig.co -6)

# Exit the script if no public IP was found
if [ -z "$newip4" ] && [ -z "$newip6" ]; then
  echo "Could not retrieve public IP."
  exit 1
fi

# Check if /opt/oldip4 and /opt/oldip6 exist, if not, create them with the current public IPs
[ ! -f /opt/oldip4 ] && [ -n "$newip4" ] && echo $newip4 > /opt/oldip4
[ ! -f /opt/oldip6 ] && [ -n "$newip6" ] && echo $newip6 > /opt/oldip6

# Fetch the IPs that were saved in /opt/oldip4 and /opt/oldip6
oldip4=$(cat /opt/oldip4 2>/dev/null)
oldip6=$(cat /opt/oldip6 2>/dev/null)

# If the IPv4 addresses don't match, replace the IPv4 in the K3s service configuration
if [ "$oldip4" != "$newip4" ] && [ -n "$newip4" ]; then
  sed -i "s/$oldip4/$newip4/g" /etc/systemd/system/k3s.service
  echo $newip4 > /opt/oldip4
  restart_service=1
fi

# If the IPv6 addresses don't match, replace the IPv6 in the K3s service configuration
if [ "$oldip6" != "$newip6" ] && [ -n "$newip6" ]; then
  sed -i "s/$oldip6/$newip6/g" /etc/systemd/system/k3s.service
  echo $newip6 > /opt/oldip6
  restart_service=1
fi

# Restart the k3s service only if either IP has changed
if [ $restart_service -eq 1 ]; then
  systemctl daemon-reload
  systemctl restart k3s
fi
