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

import unittest
import os
import os.path

import opentrv.data.storage

class TestStorage(unittest.TestCase):
    def test_path(self):
        home = os.path.expanduser('~')
        tpath = opentrv.data.storage.path("test")
        epath = os.path.join(home, ".local/share/opentrv", "test")
        self.assertEqual(epath, tpath)

    def test_mkdir(self):
        home = os.path.expanduser('~')
        epath = os.path.join(home, ".local/share/opentrv", "test")
        self.assertFalse(os.path.exists(epath))
        opentrv.data.storage.mkdir("test")
        self.assertTrue(os.path.exists(epath))
        os.rmdir(epath)
