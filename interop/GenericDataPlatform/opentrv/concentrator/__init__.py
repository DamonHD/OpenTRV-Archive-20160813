import logging
import argparse

import opentrv.concentrator.http
import opentrv.concentrator.mqtt

class Core(object):
    def __init__(self, options):
        self.logger = logging.getLogger(__name__)
        self.logger.setLevel(logging.DEBUG)
        self.logger.debug("Initialising core with options: "+str(options))
        self.options = options

    def run(self):
        logger.debug("Starting core")
        http_client =  opentrv.concentrator.http.Client(
            **self.options["http"])
        http_client.commission()
        mqtt_subscriber =  opentrv.concentrator.mqtt.Subscriber(
            sink=http_client, **self.options["mqtt"])
        mqtt_subscriber.start()

class OptionParser(object):
    def __init__(self):
        self.logger = logging.getLogger(__name__)

    def parse(self, argv):
        logger.debug("Parsing command line options")
        options = {}
        parser = argparse.ArgumentParser(
            description='''OpenTRV MQTT subscriber''')
        parser.add_argument(
            '-p', '--platform_url', default="http://localhost:8000",
            help="URL of the data platform.")
        parser.add_argument(
            '-m', '--mqtt_url', default="tcp://localhost:1883",
            help='''URL of the MQTT server.''')
        parser.add_argument(
            '-t', '--mqtt_topic', default='OpenTRV/Local',
            help='''Root MQTT topic.''')
        parser.add_argument(
            '-c', '--mqtt_client', default='OpenTRV Bridge',
            help='''MQTT client ID.''')
        args = parser.parse_args()
        options["http"] = {
            "url": args.platform_url
        }
        options["mqtt"] = {
            "url": args.mqtt_url,
            "topic": args.mqtt_topic,
            "client": args.mqtt_client
        }
        return options
