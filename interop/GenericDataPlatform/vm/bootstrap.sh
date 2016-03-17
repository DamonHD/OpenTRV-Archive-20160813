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

export DEBIAN_FRONTEND=noninteractive

# Fix no-tty
echo "Fix no-tty"
sed -i '/tty/!s/mesg n/tty -s \&\& mesg n/' /root/.profile

# Fix unable to resolve host
echo "Fix unable to resolve host"
sed -i "s/^127.*localhost$/& $(hostname)/ # host resolution tweak" /etc/hosts
