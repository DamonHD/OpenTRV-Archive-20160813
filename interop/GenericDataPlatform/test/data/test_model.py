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

from opentrv.data.model import Model

class TestModel(unittest.TestCase):
    def test_init(self):
        home = os.path.expanduser('~')
        dpath = os.path.join(home, ".local/share/opentrv", "test")
        epath = os.path.join(dpath, "model.json")
        self.assertFalse(os.path.exists(epath))
        m = Model("test", "model", ["k"])
        m.save()
        self.assertTrue(os.path.exists(epath))
        os.remove(epath)
        os.rmdir(dpath)

    def test_add(self):
        m = Model("test", "test", ["k"])
        m.add({"k": "one", "v": 1})
        r = m.find_by_key("k", "one")
        self.assertDictEqual({"k": "one", "v": 1}, r)

    def test_save(self):
        home = os.path.expanduser('~')
        dpath = os.path.join(home, ".local/share/opentrv", "test")
        epath = os.path.join(dpath, "model.json")
        self.assertFalse(os.path.exists(epath))
        m1 = Model("test", "model", ["k"])
        m1.add({"k": "one", "v": 1})
        m1.add({"k": "two", "v": 2})
        m1.save()
        m2 = Model("test", "model", ["k"])
        r = m2.find_by_key("k", "one")
        self.assertDictEqual({"k": "one", "v": 1}, r)
        self.assertTrue(os.path.exists(epath))
        os.remove(epath)
        os.rmdir(dpath)

    def test_del_by_key(self):
        m = Model("test", "model", ["k"])
        m.add({"k": "one", "v": 1})
        r = m.find_by_key("k", "one")
        self.assertDictEqual({"k": "one", "v": 1}, r)
        m.del_by_key("k", "one")
        r = m.find_by_key("k", "one")
        self.assertIsNone(r)

    def test_len_after_add(self):
        m = Model("test", "model", ["k"])
        m.add({"k": "one", "v": 1})
        self.assertEqual(1, len(m))

    def test_len_after_del(self):
        m = Model("test", "model", ["k"])
        m.add({"k": "one", "v": 1})
        m.add({"k": "two", "v": 2})
        self.assertEqual(2, len(m))
        m.del_by_key("k", "one")
        self.assertEqual(1, len(m))
