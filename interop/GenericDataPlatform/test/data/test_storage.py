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
