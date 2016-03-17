#!/usr/bin/env bash

# The OpenTRV project licenses this file to you
# under the Apache Licence, Version 2.0 (the "Licence");
# you may not use this file except in compliance
# with the Licence. You may obtain a copy of the Licence at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the Licence is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied. See the Licence for the
# specific language governing permissions and limitations
# under the Licence.
#
# Author(s) / Copyright (s): Bruno Girin 2016

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
