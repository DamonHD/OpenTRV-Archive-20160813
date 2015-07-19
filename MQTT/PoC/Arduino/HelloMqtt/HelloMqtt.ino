#include <SPI.h>
#include <Ethernet.h>
#include "PubSubClient.h"

const unsigned int BAUD_RATE = 9600;

// Update these with values suitable for your network.
byte mac[]    = { 0x90, 0xA2, 0xDA ,0x0D, 0x2A, 0xC6 };
byte server[] = { 192, 168, 0, 6 };
byte my_ip[]  = { 192, 168, 0, 7 };

void callback(char* topic, byte* payload, unsigned int length) {
  // handle message arrived
}

EthernetClient ethClient;
PubSubClient client(server, 1883, callback, ethClient);

void setup()
{
  Serial.begin(BAUD_RATE);
  Ethernet.begin(mac, my_ip);
}

void loop()
{
  delay(1000);
  Serial.print("Connecting...");
  if (client.connect("ArduinoClient")) {
    client.publish("Sample/Arduino","Hello Arduino");
    Serial.println("Published to MQTT.");
  } else {
    Serial.println("Failed to publish.");
  }
  client.disconnect();
}

