import json
import datetime
import logging
import mosquitto
from urllib.parse import urljoin

import opentrv.data

class Subscriber(object):
    """
    MQTT Subscriber that listens to a given root topic, parses all messages
    received and forwards them to a given sink component.
    """

    def __init__(self, sink, server, port, topic, client):
        """
        Initialise the MQTT subscriber with the given parameters.
        """
        self.logger = logging.getLogger(__name__)
        self.logger.debug("Initialising MQTT subscriber to: {0}:{1}/{2} [{3}]".format(
            server, port, topic, client))
        self.client = client
        self.server = server
        self.port = port
        self.topic = "{0}/#".format(topic)
        self.sink = sink

    def start(self):
        """
        Start the MQTT subscriber main loop by connecting to the server and
        running the client loop until the return code is non-zero.
        """
        self.logger.debug("Starting MQTT subscriber")
        mqttc = mosquitto.Mosquitto(self.client)
        mqttc.on_message = self.on_message
        mqttc.on_connect = self.on_connect
        mqttc.on_publish = self.on_publish
        mqttc.on_subscribe = self.on_subscribe
        mqttc.on_log = self.on_log
        mqttc.connect(self.server, self.port)
        mqttc.subscribe(self.topic, 0)

        rc = 0
        while rc == 0:
            rc = mqttc.loop()
        self.logger.debug("Stopping MQTT subscriber : "+rc)

    def on_connect(self, obj, userdata, rc):
        self.logger.debug("Connected: "+str(rc))

    def on_message(self, obj, userdata, msg):
        self.logger.debug("Message: "+msg.topic+" "+str(msg.qos)+" "+str(msg.payload))
        self.sink.on_message(self.parse(msg.topic, msg.payload.decode("utf-8")))

    def on_publish(self, obj, userdata, mid):
        self.logger.debug("Published: "+str(mid))

    def on_subscribe(self, obj, userdata, mid, granted_qos):
        self.logger.debug("Subscribed: "+str(mid)+" "+str(granted_qos))

    def on_log(self, obj, userdata, level, string):
        self.logger.log(level, string)

    def parse(self, topic, payload):
        """
        Parse the payload of a received MQTT message. If the message starts
        with the "{" character, it treats it as a OpenTRV frame.
        """
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
            self.logger.error("Cannot parse payload: "+str(payload)+" ["+topic+"]")
            r = None
        return r
