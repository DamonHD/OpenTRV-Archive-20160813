import json
import datetime

import opentrv.data

class Serializer(object):

    def __init__(self):
        pass

    def from_json(self, payload):
        return self.from_json_object(json.loads(payload))

    def from_json_object(self, payload):
        r = []
        for o in payload:
            t = opentrv.data.Topic(o["bn"])
            bt = o["bt"]
            for e in o["e"]:
                r.append(opentrv.data.Record(
                    e["n"],
                    datetime.datetime.utcfromtimestamp(
                        bt + e["t"] if "t" in e else bt
                        ),
                    e["v"],
                    e["u"] if "u" in e else None,
                    t
                    ))
        return r

    def to_json(self, records):
        return json.dumps(self.to_json_object(records))

    def to_json_object(self, records):
        ja = []
        bo = None
        bn = None
        bt = None
        for r in records:
            t = r.topic
            ts = int((r.timestamp - datetime.datetime.utcfromtimestamp(0)).total_seconds())
            if bn is None or t != bn:
                bn = t
                bt = ts
                bo = {
                    "bn": bn.path(),
                    "bt": bt,
                    "e": []
                }
                ja.append(bo)
            # handle individual item
            e = {
                "n": r.name,
                "v": r.value
            }
            if r.unit is not None:
                e["u"] = r.unit
            dt = ts - bt
            if dt != 0:
                e["t"] = dt
            bo["e"].append(e)
        return ja


        