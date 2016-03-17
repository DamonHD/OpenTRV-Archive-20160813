# The OpenTRV project licenses this file to you
# under the Apache Licence, Version 2.0 (the "Licence");
# you may not use this file except in compliance
# with the Licence. You may obtain a copy of the Licence at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the Licence is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied. See the Licence for the
# specific language governing permissions and limitations
# under the Licence.
#
# Author(s) / Copyright (s): Bruno Girin 2016

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

    def __init__(self, sink, server, port, topic, client, truncate_topic=True):
        """
        Initialise the MQTT subscriber with the given parameters.
        """
        self.logger = logging.getLogger(__name__)
        self.logger.debug("Initialising MQTT subscriber to: {0}:{1}/{2} [{3}]".format(
            server, port, topic, client))
        self.client = client
        self.server = server
        self.port = port
        self.root_topic = topic
        self.sub_topic = "{0}/#".format(topic)
        self.sink = sink
        self.truncate_topic = truncate_topic

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
        mqttc.subscribe(self.sub_topic, 0)

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
        if self.truncate_topic:
            t = t.relative_to(opentrv.data.Topic(self.root_topic))
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
