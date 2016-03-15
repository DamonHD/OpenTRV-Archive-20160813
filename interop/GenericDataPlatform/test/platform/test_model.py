import unittest

from opentrv.platform.model import Concentrators, Devices, Sensors
import opentrv.data

class TestConcentrators(unittest.TestCase):
    def test_find_by_uuid(self):
        concs = Concentrators()
        concs.add({"uuid": "test_uuid", "mkey": "test_mkey"})
        c = concs.find_by_uuid("test_uuid")
        self.assertIsNotNone(c)
        self.assertEqual("test_uuid", c["uuid"])
        self.assertEqual("test_mkey", c["mkey"])

class TestDevices(unittest.TestCase):
    def test_find_by_bn(self):
        mkey = "test_mkey"
        c = {"uuid": "test_uuid", "mkey": mkey}
        bn = "mytopic"
        devices = Devices(c)
        devices.add({"mkey": mkey, "bn": bn})
        d = devices.find_by_bn(bn)
        self.assertIsNotNone(d)
        self.assertEqual(mkey, d["mkey"])
        self.assertEqual(bn, d["bn"])

    def test_find_by_topic(self):
        mkey = "test_mkey"
        c = {"uuid": "test_uuid", "mkey": mkey}
        t = opentrv.data.Topic("my/topic")
        devices = Devices(c)
        devices.add_topic(t)
        d = devices.find_by_topic(t)
        self.assertIsNotNone(d)
        self.assertEqual(mkey, d["mkey"])
        self.assertEqual("my_topic", d["bn"])

class TestSensors(unittest.TestCase):
    def test_find_by_n(self):
        mkey = "test_mkey"
        bn = "mytopic"
        n = "t"
        d = {"mkey": mkey, "bn": bn}
        sensors = Sensors(d)
        sensors.add({"mkey": mkey, "bn": bn, "n": n})
        s = sensors.find_by_n("t")
        self.assertIsNotNone(s)
        self.assertEqual(mkey, s["mkey"])
        self.assertEqual(bn, s["bn"])
        self.assertEqual(n, s["n"])

    def test_find_by_record(self):
        mkey = "test_mkey"
        bn = "mytopic"
        d = {"mkey": mkey, "bn": bn}
        r = opentrv.data.Record("t", 0, 10)
        sensors = Sensors(d)
        sensors.add_record(r)
        s = sensors.find_by_record(r)
        self.assertIsNotNone(s)
        self.assertEqual(mkey, s["mkey"])
        self.assertEqual(bn, s["bn"])
        self.assertEqual("t", s["n"])
