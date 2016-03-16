#!/usr/bin/env bash

set -e

# Load up the release information
. /etc/lsb-release

export DEBIAN_FRONTEND=noninteractive

echo "Installing PIP and Mosquitto"
apt-get update -qqy
apt-get install -qy python3-pip mosquitto

echo "Installing Mosquitto clients for testing"
apt-get install -qy mosquitto-clients

echo "Installing python packages"
if [ -d /vagrant ]; then
    pip3 install -r /vagrant/vm/requirements.txt
else
    pip2 install -r ./requirements.txt
fi
