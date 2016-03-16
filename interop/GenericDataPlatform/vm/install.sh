#!/usr/bin/env bash

set -e

# Load up the release information
. /etc/lsb-release

f0=$(readlink -e $0)
d0=$(dirname $f0)
d1=$(dirname $d0)

export DEBIAN_FRONTEND=noninteractive

echo "Installing PIP and Mosquitto"
apt-get update -qqy
apt-get install -qy python3-pip mosquitto

echo "Installing Mosquitto clients for testing"
apt-get install -qy mosquitto-clients

echo "Installing python packages"
if [ -d /vagrant ]; then
    # if in vagrant VM then install as editable
    pip3 install -r /vagrant/vm/requirements.txt
    pip3 install -e /vagrant
else
    # if not in vagrant VM then install from local as non-editable
    pip3 install -r $d0/requirements.txt
    pip3 install $d1
fi
