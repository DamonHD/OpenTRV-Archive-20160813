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
