/*
The OpenTRV project licenses this file to you
under the Apache Licence, Version 2.0 (the "Licence");
you may not use this file except in compliance
with the Licence. You may obtain a copy of the Licence at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing,
software distributed under the Licence is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
KIND, either express or implied. See the Licence for the
specific language governing permissions and limitations
under the Licence.

Author(s) / Copyright (s): Bruno Girin 2016 */

package uk.org.opentrv.comms.statshandlers.mqtt;

import static uk.org.opentrv.comms.cfg.ConfigUtil.getAsString;
import static uk.org.opentrv.comms.cfg.ConfigUtil.getAsNumber;

import java.io.IOException;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.Map;

import org.eclipse.paho.client.mqttv3.MqttClient;
import org.eclipse.paho.client.mqttv3.MqttConnectOptions;
import org.eclipse.paho.client.mqttv3.MqttDeliveryToken;
import org.eclipse.paho.client.mqttv3.MqttException;
import org.eclipse.paho.client.mqttv3.MqttMessage;
import org.eclipse.paho.client.mqttv3.MqttTopic;

import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;
import org.json.simple.parser.ParseException;

import uk.org.opentrv.comms.statshandlers.StatsHandler;
import uk.org.opentrv.comms.statshandlers.StatsMessageWithMetadata;
import uk.org.opentrv.comms.util.CommonSensorLabels;
import uk.org.opentrv.comms.util.ParsedRemoteBinaryStatsRecord;
import uk.org.opentrv.comms.cfg.ConfigException;

/**
 * Stats handler that sends data over MQTT. The payload is a JSON frame with minimal
 * alteration from what is received by the handler.
 */
public final class MqttPublishingHandler implements StatsHandler {

    public static final String REQUEST_METHOD = "POST";
    public static final String CHARSET = "UTF-8";
    public static final String CONTENT_TYPE_KEY = "Content-Type";
    public static final String CONTENT_TYPE_VALUE = "application/json";
    public static final String CONTENT_LENGTH_KEY = "Content-Length";

    private final String brokerUrl;
    private final String clientId;
    private final String rootTopic;
    private final int qos;

    private final MqttClient client;
    private final MqttConnectOptions conOpt;

    /**
     * Create a new MqttPublishingHandler from a URL, a root topic and a QOS value.
     *
     * @param brokerUrl the broker URL
     * @param clientId the client ID to use to connect to the MQTT broker
     * @param rootTopic the root topic to use
     * @param the QOS value (0, 1 or 2)
     * @throws MalformedURLException
     */
    public MqttPublishingHandler(final String brokerUrl, final String clientId, final String rootTopic, final int qos)
        throws MalformedURLException, MqttException
    {
        this.brokerUrl = brokerUrl;
        this.clientId = clientId;
        this.rootTopic = rootTopic;
        this.qos = qos;
        
        // Construct the object that contains connection parameters
        // such as cleansession and LWAT
        conOpt = new MqttConnectOptions();
        conOpt.setCleanSession(false);

        // Construct the MqttClient instance
        client = new MqttClient(this.brokerUrl, clientId);
    }

    /**
     * Create a new MqttPublishingHandler from a configuration map that contains a
     * URL, root toic and QOS.
     *
     * @param config the configuration map
     * @throws MalformedURLException
     */
    public MqttPublishingHandler(final Map config)
        throws MalformedURLException, MqttException, ConfigException
    {
        this(
            getAsString(config, "brokerUrl", "tcp://localhost:1883"),
            getAsString(config, "clientId", "OpenTRV"),
            getAsString(config, "rootTopic", "OpenTRV/Local"),
            getAsNumber(config, "qos", 0).intValue()
        );
    }

    public String getBrokerURL() {
        return brokerUrl;
    }

    public String getClientId() {
        return clientId;
    }

    public String getRootTopic() {
        return rootTopic;
    }

    public int getQOS() {
        return qos;
    }
    
    private void publish(MqttPayload payload) throws MqttException {
        final String topicName = getRootTopic() + "/" + payload.getLeafTopic();
        client.connect();
        System.out.println("Connected to "+brokerUrl+" with client ID "+client.getClientId());
        MqttTopic topic = client.getTopic(topicName);
        MqttMessage message = new MqttMessage(payload.toJSONString().getBytes());
        message.setQos(qos);
        MqttDeliveryToken token = topic.publish(message);
        token.waitForCompletion();
        System.out.println("Message published, disconnecting");
        client.disconnect();
    }

    /**
     * Remote stats handler that sends data to the specified MQTT broker using the
     * OpenTRV JSON format. The payload is sent to a sub-topic of the root topic
     * as per the '@' value of the paylod (leaf ID). All metrics are given the
     * same timestamp obtained when creating the record.
     * <p>
     * This is intended to process the printable-ASCII form of remote binary stats lines starting with '@', eg:
     * <pre>
@D49;T19C7
@2D1A;T20C7
@A45;P;T21CC
@3015;T25C8;L62;O1
     * </pre>
     * and remote JSON stats lines starting with '{', eg:
     * <pre>
{"@":"cdfb","T|C16":296,"H|%":87,"L":231,"B|cV":256}
{"@":"cdfb","T|C16":296,"H|%":87,"L":231,"B|cV":256}
{"@":"cdfb","T|C16":296,"H|%":88,"L":229,"B|cV":256}
{"@":"cdfb","T|C16":297,"H|%":89,"L":227,"B|cV":256}
{"@":"cdfb","T|C16":297,"H|%":89,"L":229,"B|cV":256}
     * </pre>
     * <p>
     * Example payload:
     * <pre>
     * {
     *     "method":"dad_data",
     *     "ver":"1.1",
     *     "dad_id":"ED_25",
     *     "data":[
     *         {"id":"A45_T","period":"2014-08-23T10:25:12","value":21.75"},
     *         {"id":"A45_L","period":"2014-08-23T10:25:12","value":35"},
     *         {"id":"A45_O","period":"2014-08-23T10:25:12","value":1"}
     *     ]
     * }
     * </pre>
     */
    @Override
    public void processStatsMessage(final StatsMessageWithMetadata swmd) throws IOException {
        final char firstChar = swmd.message.charAt(0);
        final MqttPayload payloadObj;
        if('{' == firstChar) {
            // Process potential JSON; reject if bad.
            final long nowms = System.currentTimeMillis();
            final JSONParser parser = new JSONParser();
            try {
                final Object obj = parser.parse(swmd.message);
                final JSONObject jsonObj = (JSONObject)obj;
                payloadObj = new MqttPayload(nowms, jsonObj);
            } catch(final ParseException pe) {
                return;
            }
        } else if(CommonSensorLabels.ID.getLabel() == firstChar) {
            // Process potential binary record.
            final ParsedRemoteBinaryStatsRecord parsed = new ParsedRemoteBinaryStatsRecord(swmd.message);
            payloadObj = new MqttPayload(parsed);
        } else {
            // Ignore all other lines.
            return;
        }
        System.out.println("Sending: "+payloadObj.toJSONString());
        try {
            publish(payloadObj);
        } catch(MqttException mqe) {
            throw new IOException("Could not publish to MQTT topic", mqe);
        }
    }

}
