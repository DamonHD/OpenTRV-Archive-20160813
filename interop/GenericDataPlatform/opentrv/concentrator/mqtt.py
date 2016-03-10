import json
import datetime
import logging
import mosquitto

import opentrv.data

class Subscriber(object):

    def __init__(self, sink):
        self.logger = logging.getLogger(__name__)
        self.logger.debug("Initialising MQTT subscriber")
        self.client = ""
        self.server = ""
        self.topic = ""
        self.sink = sink

    def start(self):
        self.logger.debug("Starting MQTT subscriber")
        mqttc = mosquitto.Mosquitto(self.client)
        mqttc.on_message = on_message
        mqttc.on_connect = on_connect
        mqttc.on_publish = on_publish
        mqttc.on_subscribe = on_subscribe
        mqttc.on_log = on_log
        mqttc.connect(self.server, args.port, 60)
        mqttc.subscribe(self.topic, 0)

        rc = 0
        while rc == 0:
            rc = mqttc.loop()
        self.logger.debug("Stopping MQTT subscriber : "+rc)

    def on_connect(self, rc):
        self.logger.debug("Connected: "+rc)

    def on_message(self, msg):
        self.logger.debug("Message: "+msg.topic+" "+str(msg.qos)+" "+str(msg.payload))
        sink.on_message(parse(msg.topic, msg.payload))

    def on_publish(self, mid):
        self.logger.debug("Published: "+str(mid))

    def on_subscribe(self, mid, granted_qos):
        self.logger.debug("Subscribed: "+str(mid)+" "+str(granted_qos))

    def on_log(self, level, string):
        self.logger.log(level, string)

    def parse(self, topic, payload):
        t = opentrv.data.Topic(topic)
        if payload[0] == "{":
            pm = json.loads(payload)
            body = pm["body"]
            tss = pm["ts"]
            ts = datetime.datetime.strptime(tss, "%Y-%m-%dT%H:%M:%SZ")
            r = [
                opentrv.data.Record(sk[0], ts, v, sk[1] if len(sk) > 1 else None, t)
                for (sk, v) in [
                    (k.split('|'), v) for (k, v) in body.items()
                ]
            ]
        else:
            self.logger.error("Cannot parse payload: "+payload+" ["+topic+"]")
            r = None
        return r
