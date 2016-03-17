import json
import datetime

import opentrv.data

MIME_TYPE="application/senml+json"

class Serializer(object):
    """
    SenML serializer that transforms from data record to SenML JSON payload and
    vice versa.
    """

    def __init__(self):
        pass

    def from_json(self, payload):
        return self.from_json_object(json.loads(payload))

    def from_json_object(self, payload):
        r = []
        bn = None
        bt = None
        bu = None
        t = None
        for o in payload:
            if "bn" in o:
                bn = o["bn"]
                bt = o["bt"] if "bt" in o else None
                bu = o["bu"] if "bu" in o else None
                t = opentrv.data.Topic(bn)
            else:
                r.append(opentrv.data.Record(
                    o["n"],
                    datetime.datetime.utcfromtimestamp(
                        bt + o["t"] if ("t" in o and bt is not None) else (o["t"] if "t" in o else bt)
                        ),
                    o["v"],
                    o["u"] if "u" in o else bu,
                    t
                    ))
        return r

    def to_json(self, records):
        return json.dumps(self.to_json_object(records))

    def to_json_object(self, records):
        ja = []
        bn = None
        bt = None
        for r in records:
            t = r.topic.path()
            ts = int((r.timestamp - datetime.datetime.utcfromtimestamp(0)).total_seconds())
            if bn is None or t != bn:
                bn = t
                bt = ts
                e = {"bn": bn, "bt": ts}
                if len(ja) == 0:
                    e["ver"] = 3
                ja.append(e)
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
            ja.append(e)
        return ja


        