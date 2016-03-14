#!/usr/bin/env bash

set -e

# Load up the release information
. /etc/lsb-release

export DEBIAN_FRONTEND=noninteractive

# Fix no-tty
echo "Fix no-tty"
sed -i '/tty/!s/mesg n/tty -s \&\& mesg n/' /root/.profile

# Fix unable to resolve host
echo "Fix unable to resolve host"
sed -i "s/^127.*localhost$/& $(hostname)/ # host resolution tweak" /etc/hosts
