import unittest

import datetime

import opentrv.data
import opentrv.concentrator.mqtt

class TestMqttSubscriber(unittest.TestCase):
    def test_parse(self):
        payload = """{
            "ts": "2016-01-01T05:10:15Z",
            "body": {
                "T|C": 14.5,
                "O": 2
            }
        }"""
        m = opentrv.concentrator.mqtt.Subscriber(None)
        r = m.parse("topic", payload)
        expected_keys = ["T", "O"]
        expected = {
            "T": opentrv.data.Record(
                "T",
                datetime.datetime(2016, 1, 1, 5, 10, 15),
                14.5, "C", "topic"
            ),
            "O": opentrv.data.Record(
                "O",
                datetime.datetime(2016, 1, 1, 5, 10, 15),
                2, None, "topic"
            )
        }
        self.assertEqual(2, len(r))
        for i in range(0, len(r)):
            n = r[i].name
            expected_keys.remove(n)
            self.assertEqual(expected[n].name, r[i].name)
            self.assertEqual(expected[n].timestamp, r[i].timestamp)
            self.assertEqual(expected[n].value, r[i].value)
            self.assertEqual(expected[n].unit, r[i].unit)
            self.assertEqual(expected[n].topic, r[i].topic.path())

if __name__ == '__main__':
    unittest.main()