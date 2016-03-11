import unittest
import datetime
import json

import opentrv.data
import opentrv.data.senml

class TestSenmlSerializer(unittest.TestCase):
    def test_to_json_object(self):
        t1 = opentrv.data.Topic("dummy")
        t2 = opentrv.data.Topic("local/topic")
        ts = datetime.datetime.utcnow()
        r = [
            opentrv.data.Record("t", ts, 10, topic=t1, unit="C"),
            opentrv.data.Record("u", ts, 1.1, topic=t1),
            opentrv.data.Record("v", ts, 15, topic=t1),
            opentrv.data.Record("w", ts, 1.6, topic=t1),
            opentrv.data.Record("t", ts, 20, topic=t2),
            opentrv.data.Record("u", ts, 2.2, topic=t2),
            opentrv.data.Record("x", ts, 25, topic=t2)
        ]
        serializer = opentrv.data.senml.Serializer()
        o = serializer.to_json_object(r)
        self.assertEqual(2, len(o))
        bt = int((ts - datetime.datetime.utcfromtimestamp(0)).total_seconds())
        self.assertEqual(t1.path(), o[0]["bn"])
        self.assertEqual(bt, o[0]["bt"])
        self.assertEqual(4, len(o[0]["e"]))
        self.assertEqual("t", o[0]["e"][0]["n"])
        self.assertEqual(10, o[0]["e"][0]["v"])
        self.assertEqual(t2.path(), o[1]["bn"])

    def test_to_json(self):
        t1 = opentrv.data.Topic("dummy")
        t2 = opentrv.data.Topic("local/topic")
        ts = datetime.datetime.utcnow()
        r = [
            opentrv.data.Record("t", ts, 10, topic=t1, unit="C"),
            opentrv.data.Record("u", ts, 1.1, topic=t1),
            opentrv.data.Record("v", ts, 15, topic=t1),
            opentrv.data.Record("w", ts, 1.6, topic=t1),
            opentrv.data.Record("t", ts, 20, topic=t2),
            opentrv.data.Record("u", ts, 2.2, topic=t2),
            opentrv.data.Record("x", ts, 25, topic=t2)
        ]
        serializer = opentrv.data.senml.Serializer()
        j = serializer.to_json(r)
        o = json.loads(j)
        self.assertEqual(2, len(o))
        bt = int((ts - datetime.datetime.utcfromtimestamp(0)).total_seconds())
        self.assertEqual(t1.path(), o[0]["bn"])
        self.assertEqual(bt, o[0]["bt"])
        self.assertEqual(4, len(o[0]["e"]))
        self.assertEqual("t", o[0]["e"][0]["n"])
        self.assertEqual(10, o[0]["e"][0]["v"])
        self.assertEqual(t2.path(), o[1]["bn"])

    def test_from_json_object(self):
        ts = datetime.datetime.utcnow()
        bt = int((ts - datetime.datetime.utcfromtimestamp(0)).total_seconds())
        o = [
            {
                "bt": bt,
                "bn": "opentrv/local",
                "e": [
                    {"n": "t", "v": 10, "u": "C"},
                    {"n": "t", "v": 15, "t": 60}
                ]
            },
            {
                "bt": bt,
                "bn": "opentrv/remote",
                "e": [
                    {"n": "t", "v": 20, "u": "C"},
                    {"n": "t", "v": 25, "t": 60}
                ]
            }
        ]
        serializer = opentrv.data.senml.Serializer()
        r = serializer.from_json_object(o)
        self.assertEqual(4, len(r))
        self.assertEqual("opentrv/local", r[0].topic.path())
        self.assertEqual(0, int((ts - r[0].timestamp).total_seconds()))
        self.assertEqual("t", r[0].name)
        self.assertEqual("C", r[0].unit)
        self.assertIsNone(r[1].unit)
        self.assertEqual(0, int((ts + datetime.timedelta(seconds=60) - r[1].timestamp).total_seconds()))

    def test_from_json(self):
        ts = datetime.datetime.utcnow()
        bt = int((ts - datetime.datetime.utcfromtimestamp(0)).total_seconds())
        j = "".join([
            "[{\"bt\":",str(bt),",\"bn\":\"opentrv/local\",\"e\":[",
            "{\"n\": \"t\", \"v\": 10, \"u\": \"C\"},",
            "{\"n\": \"t\", \"v\": 15, \"t\": 60}",
            "]},",
            "{\"bt\":",str(bt),",\"bn\":\"opentrv/remote\",\"e\": [",
            "{\"n\": \"t\", \"v\": 20, \"u\": \"C\"},",
            "{\"n\": \"t\", \"v\": 25, \"t\": 60}",
            "]}]"])
        serializer = opentrv.data.senml.Serializer()
        r = serializer.from_json(j)
        self.assertEqual(4, len(r))
        self.assertEqual("opentrv/local", r[0].topic.path())
        self.assertEqual(0, int((ts - r[0].timestamp).total_seconds()))
        self.assertEqual("t", r[0].name)
        self.assertEqual("C", r[0].unit)
        self.assertIsNone(r[1].unit)
        self.assertEqual(0, int((ts + datetime.timedelta(seconds=60) - r[1].timestamp).total_seconds()))
