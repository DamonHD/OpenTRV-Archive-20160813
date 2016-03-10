import logging
import mosquitto

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

    def on_connect(obj, rc):
        self.logger.debug("Connected: "+rc)

    def on_message(obj, msg):
        self.logger.debug("Message: "+msg.topic+" "+str(msg.qos)+" "+str(msg.payload))
        sink.on_message(msg)

    def on_publish(obj, mid):
        self.logger.debug("Published: "+str(mid))

    def on_subscribe(obj, mid, granted_qos):
        self.logger.debug("Subscribed: "+str(mid)+" "+str(granted_qos))

    def on_log(obj, level, string):
        self.logger.log(level, string)
