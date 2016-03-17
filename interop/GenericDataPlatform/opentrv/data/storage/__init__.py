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

import os
import os.path

ROOT_PATH = os.path.expanduser('~/.local/share/opentrv')

def path(partial_path):
    """
    Return the full path for the given partial path.
    """
    return os.path.abspath(os.path.join(ROOT_PATH, partial_path))

def mkdir(partial_path):
    """
    Recursively create a folder for the given partial path.
    """
    fpath = path(partial_path)
    if os.path.exists(fpath):
        if not os.path.isdir(fpath):
            raise ValueError("Path {0} already exists and is not a directory".format(fpath))
    else:
        os.makedirs(fpath)
