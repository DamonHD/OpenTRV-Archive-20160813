import json
import datetime

import opentrv.data

MIME_TYPE="application/senml+json"

KEY_BASE_NAME = "bn"
KEY_BASE_TIME = "bt"
KEY_BASE_UNIT = "bu"
KEY_NAME      = "n"
KEY_TIME      = "t"
KEY_UNIT      = "u"
KEY_VALUE     = "v"
KEY_VERSION   = "ver"

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
            if KEY_BASE_NAME in o:
                bn = o[KEY_BASE_NAME]
                bt = o[KEY_BASE_TIME] if KEY_BASE_TIME in o else None
                bu = o[KEY_BASE_UNIT] if KEY_BASE_UNIT in o else None
                t = opentrv.data.Topic(bn)
            else:
                r.append(opentrv.data.Record(
                    o[KEY_NAME],
                    datetime.datetime.utcfromtimestamp(
                        bt + o[KEY_TIME] if (
                            KEY_TIME in o and bt is not None
                            ) else (
                            o[KEY_TIME] if KEY_TIME in o else bt)
                        ),
                    o[KEY_VALUE],
                    o[KEY_UNIT] if KEY_UNIT in o else bu,
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
                e = {KEY_BASE_NAME: bn, KEY_BASE_TIME: ts}
                if len(ja) == 0:
                    e[KEY_VERSION] = 3
                ja.append(e)
            # handle individual item
            e = {
                KEY_NAME:  r.name,
                KEY_VALUE: r.value
            }
            if r.unit is not None:
                e[KEY_UNIT] = r.unit
            dt = ts - bt
            if dt != 0:
                e[KEY_TIME] = dt
            ja.append(e)
        return ja


        