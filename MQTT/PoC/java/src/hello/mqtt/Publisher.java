package hello.mqtt;

import org.eclipse.paho.client.mqttv3.MqttClient;
import org.eclipse.paho.client.mqttv3.MqttConnectOptions;
import org.eclipse.paho.client.mqttv3.MqttDeliveryToken;
import org.eclipse.paho.client.mqttv3.MqttException;
import org.eclipse.paho.client.mqttv3.MqttMessage;
import org.eclipse.paho.client.mqttv3.MqttTopic;

public class Publisher {
	
	private String brokerUrl;
	private int qos;
	
	private MqttClient client;
	private MqttConnectOptions conOpt;
	
	public Publisher(String server, int port, String clientId, int qos) {
		this.brokerUrl = "tcp://"+server+":"+port;
		this.qos = qos;
		
    	try {
    		// Construct the object that contains connection parameters
    		// such as cleansession and LWAT
	    	conOpt = new MqttConnectOptions();
	    	conOpt.setCleanSession(false);

    		// Construct the MqttClient instance
			client = new MqttClient(this.brokerUrl, clientId);
		} catch (MqttException e) {
			e.printStackTrace();
			System.err.println("Unable to set up client: "+e.toString());
			System.exit(1);
		}
	}
	
	public void publish(String topicName, String payload) throws MqttException {
		client.connect();
		System.out.println("Connected to "+brokerUrl+" with client ID "+client.getClientId());
		MqttTopic topic = client.getTopic(topicName);
		MqttMessage message = new MqttMessage(payload.getBytes());
		message.setQos(qos);
		MqttDeliveryToken token = topic.publish(message);
		token.waitForCompletion();
		System.out.println("Message published, disconnecting");
		client.disconnect();
	}

	public static void main(String[] args) {
		String server = "localhost";
		int port = 1883;
		String clientId = "Java Publisher";
		String topic = "Sample/Hello";
		int qos = 0;
		String payload = "";
		for (int i=0; i<args.length; i++) {
			// Check this is a valid argument
			if (args[i].length() == 2 && args[i].startsWith("-")) {
				char arg = args[i].charAt(1);
				// Validate there is a value associated with the argument
				if (i == args.length -1 || args[i+1].charAt(0) == '-') {
					System.out.println("Missing value for argument: "+args[i]);
					return;
				}
				switch(arg) {
				case 's': server = args[++i];                 break;
				case 'p': port = Integer.parseInt(args[++i]); break;
				case 'c': clientId = args[++i];               break;
				case 't': topic = args[++i];                  break;
				default:
					System.out.println("Unrecognised argument: "+args[i]);
					return;
				}
			} else {
				payload = args[i];
			}
		}

		Publisher pub = new Publisher(server, port, clientId, qos);
		try {
			pub.publish(topic, payload);
		} catch (MqttException e) {
			System.err.println("Exception when publishing");
			e.printStackTrace();
		}
	}
}
