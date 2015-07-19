package hello.mqtt;

import java.io.IOException;

import org.eclipse.paho.client.mqttv3.MqttCallback;
import org.eclipse.paho.client.mqttv3.MqttClient;
import org.eclipse.paho.client.mqttv3.MqttConnectOptions;
import org.eclipse.paho.client.mqttv3.MqttDeliveryToken;
import org.eclipse.paho.client.mqttv3.MqttException;
import org.eclipse.paho.client.mqttv3.MqttMessage;
import org.eclipse.paho.client.mqttv3.MqttTopic;

public class Subscriber implements MqttCallback {
	
	private String brokerUrl;
	private int qos;
	
	private MqttClient client;
	private MqttConnectOptions conOpt;
	
	public Subscriber(String server, int port, String clientId, int qos) {
		this.brokerUrl = "tcp://"+server+":"+port;
		this.qos = qos;
		
    	try {
    		// Construct the object that contains connection parameters
    		// such as cleansession and LWAT
	    	conOpt = new MqttConnectOptions();
	    	conOpt.setCleanSession(false);

    		// Construct the MqttClient instance
			client = new MqttClient(this.brokerUrl, clientId);
			
			// Set this wrapper as the callback handler
	    	client.setCallback(this);
		} catch (MqttException e) {
			e.printStackTrace();
			System.err.println("Unable to set up client: "+e.toString());
			System.exit(1);
		}
	}
	
	public void subscribe(String topicName) throws MqttException {
		client.connect();
		System.out.println("Connected to "+brokerUrl+" with client ID "+client.getClientId());
		
    	// Subscribe to the topic
    	System.out.println("Subscribing to topic \""+topicName+"\" qos "+qos);
    	client.subscribe(topicName, qos);

    	// Block until Enter is pressed
    	System.out.println("Press <Enter> to exit");
		try {
			System.in.read();
		} catch (IOException e) {
			//If we can't read we'll just exit
		}
		client.disconnect();
		System.out.println("Disconnected");
	}

	public static void main(String[] args) {
		String server = "localhost";
		int port = 1883;
		String clientId = "Java Subscriber";
		String topic = "Sample/#";
		int qos = 0;
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
				System.err.println("Unrecognised argument: "+args[i]);
				return;
			}
		}

		Subscriber sub = new Subscriber(server, port, clientId, qos);
		try {
			sub.subscribe(topic);
		} catch (MqttException e) {
			System.err.println("Exception when subscribing");
			e.printStackTrace();
		}
	}

	@Override
	public void connectionLost(Throwable arg0) {
		// TODO Auto-generated method stub
		
	}

	@Override
	public void deliveryComplete(MqttDeliveryToken arg0) {
		// TODO Auto-generated method stub
		
	}

	@Override
	public void messageArrived(MqttTopic topic, MqttMessage message)
			throws Exception {
		// TODO Auto-generated method stub
		System.out.println(topic.getName()+": "+new String(message.getPayload()));
	}

}
