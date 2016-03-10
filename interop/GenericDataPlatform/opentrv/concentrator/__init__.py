import logging

import opentrv.concentrator.http
import opentrv.concentrator.mqtt

class Core(object):
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.logger.setLevel(logging.DEBUG)
        self.logger.debug("Initialising core")

    def run(self):
        logger.debug("Starting core")
        http_client =  opentrv.concentrator.http.Client()
        http_client.commission()
        mqtt_subscriber =  opentrv.concentrator.mqtt.Subscriber(http_client)
        mqtt_subscriber.start()
