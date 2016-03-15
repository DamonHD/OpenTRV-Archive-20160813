import unittest

from opentrv.platform.model import Concentrators

class TestConcentrators(unittest.TestCase):
    def test_find_by_uuid(self):
        concs = Concentrators()
        concs.add({"uuid": "test_uuid", "mkey": "test_mkey"})
        c = concs.find_by_uuid("test_uuid")
        self.assertIsNotNone(c)
        self.assertEqual("test_uuid", c["uuid"])
        self.assertEqual("test_mkey", c["mkey"])