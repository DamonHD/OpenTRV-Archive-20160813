#!/usr/bin/env python

import argparse
import mosquitto

def on_connect(obj, rc):
    print("rc: "+str(rc))

def on_message(obj, msg):
    print(msg.topic+" "+str(msg.qos)+" "+str(msg.payload))

def on_publish(obj, mid):
    print("mid: "+str(mid))

def on_subscribe(obj, mid, granted_qos):
    print("Subscribed: "+str(mid)+" "+str(granted_qos))

def on_log(obj, level, string):
    print(string)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='''MQTT subscriber''')
    parser.add_argument('-s', '--server', default="localhost",
                        help="Address of the MQTT server")
    parser.add_argument('-p', '--port', type=int, default=1883,
                        help='''Port to use on the MQTT server.''')
    parser.add_argument('-c', '--client', default='Python Subscriber',
                        help='''Client name to use.''')
    parser.add_argument('-t', '--topic', default='Sample/#',
                        help='''Topic to subscribe to.''')
    args = parser.parse_args()
    
    mqttc = mosquitto.Mosquitto(args.client)
    mqttc.on_message = on_message
    mqttc.on_connect = on_connect
    mqttc.on_publish = on_publish
    mqttc.on_subscribe = on_subscribe
    # Uncomment to enable debug messages
    mqttc.on_log = on_log
    mqttc.connect(args.server, args.port, 60)
    mqttc.subscribe(args.topic, 0)

    rc = 0
    while rc == 0:
        rc = mqttc.loop()

    print("rc: "+str(rc))

