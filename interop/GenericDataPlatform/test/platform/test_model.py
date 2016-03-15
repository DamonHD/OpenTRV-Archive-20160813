import unittest

from opentrv.platform.model import Devices

class TestDevices(unittest.TestCase):
    def test_find_by_uuid(self):
        devices = Devices()
        devices.add({"uuid": "test_uuid", "mkey": "test_mkey"})
        d = devices.find_by_uuid("test_uuid")
        self.assertIsNotNone(d)
        self.assertEqual("test_uuid", d["uuid"])
        self.assertEqual("test_mkey", d["mkey"])