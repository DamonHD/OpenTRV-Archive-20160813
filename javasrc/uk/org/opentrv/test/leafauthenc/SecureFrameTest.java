package uk.org.opentrv.test.leafauthenc;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import java.io.UnsupportedEncodingException;
import java.security.NoSuchAlgorithmException;
import java.security.NoSuchProviderException;
import java.security.SecureRandom;
import java.util.Arrays;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.NoSuchPaddingException;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import javax.xml.bind.DatatypeConverter;

import org.junit.BeforeClass;
import org.junit.Test;

import uk.org.opentrv.comms.util.crc.CRC7_5B;

public class SecureFrameTest
    {
    public static final int AES_KEY_SIZE = 128; // in bits
    public static final int GCM_NONCE_LENGTH = 12; // in bytes
    public static final int GCM_TAG_LENGTH = 16; // in bytes (default 16, 12 possible)

    /**Standard text string to compute checksum of, eg as used by pycrc. */
    public static final String STD_TEST_ASCII_TEXT = "123456789";
    /**Private byte array to clone from as needed. */
    private static final byte[] _STD_TEST_ASCII_TEXT_B;
    static
        {
        try { _STD_TEST_ASCII_TEXT_B = STD_TEST_ASCII_TEXT.getBytes("ASCII7"); }
        catch(final UnsupportedEncodingException e) { throw new IllegalStateException(); }
        }
    /**Get STD_TEST_ASCII_TEXT as new private byte array. */
    public static byte[] getStdTestASCIITextAsByteArray() { return(_STD_TEST_ASCII_TEXT_B.clone()); }

    // Message definitions
    // To Do - separate out heat and valve pos.
   static class BodyStruct {
	   	boolean	heat;			// call for heat flag	
    	byte 	valvePos;		// Valve % open
    	byte 	flags;			// assorted flags indicating the sate of the nation (ToDo ref spec doc here)
    	String 	stats;			// Compact JSON object with leading { final } omitted.
    }
    
   // used on the RX side 
   //ToDo separate out seq number and length..
    static class OFrameStruct {
    	byte 		length;			// Overall frame length, excluding this byte, typically <=64 and filled in automatically
    	boolean		secFlag;		// secure flag
    	byte 		frameType;		// frame type.
    	byte 		frameSeqNo;		// Frame Sequence number bits 4-7, 
    	byte		idLen;			//	length of the id field
    	byte [] 	id;				// 0 implies anonymous, typically 2 bytes.
    	byte		bodyLen;		// length of the body section
    	BodyStruct	body;			// Body section
    	byte[]		trailer;		// Trailer - either a 7bit CRC for insecure frame or variable length security 
    								// info in the encrypted case, with the length determined by encryption method used
    }
   
    /**Compute (non-secure) CRC over secureable frame content.
     * @param buf  buffer that included the frame data to have the CRC applied (all of header and body);
     *     never null
     * @param pos  starting position of the frame data in the buffer;
     *     must be valid offset within the buffer
     * @param len  length of frame data to have the CRC computed over;
     *     strictly positive and pos+len must be within the buffer
     */
    public static byte computeInsecureFrameCRC(byte buf[], int pos, int len)
        {
        byte crc = (byte)0xff; // Initialise CRC with 0xff (protects against extra leading 0x00s).
        for(int i = 0; i < len; ++i)
            {
            crc = CRC7_5B.crc7_5B_update(crc, buf[pos + i]);
            }
        if(0 == crc) { return((byte)0x80); } // Avoid all-0s and all-1s result values, ie self-whitened.
        return(crc);
        }
    
    
   	public static int encryptFrame(byte[] msgBuff, int length) throws Exception {
   		int i;
   		
   		final byte[] input = new byte[length]; 	//where pointer is pointing is final, what is pointed to can change. (cf const char *)
   		for (i=0;i< length; i++) 				
   			input[i]=msgBuff[i];				// copy bytes to encrypt into the input buffer. This may not be necessary, but I dont understand 
   												// what side effects there will be if I give the encrypt class a 255 byte buffer with fewer bytes in it.
   			

   		final KeyGenerator keyGen = KeyGenerator.getInstance("AES");
   		keyGen.init(AES_KEY_SIZE, srnd);
   		final SecretKey key = keyGen.generateKey();

   		// Encrypt
   		final Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding", "SunJCE"); // JDK 7 breaks here..
   		final byte[] nonce = new byte[GCM_NONCE_LENGTH];
   		srnd.nextBytes(nonce);
   		final GCMParameterSpec spec = new GCMParameterSpec(GCM_TAG_LENGTH * 8, nonce);
   		cipher.init(Cipher.ENCRYPT_MODE, key, spec);

   		final byte[] aad = "819c".getBytes();
   		cipher.updateAAD(aad);

   		final byte[] cipherText = cipher.doFinal(input);
//      System.out.println("Size plain="+input.length+" aad="+aad.length+" cipher="+cipherText.length);
        
// ToDo - add cipherText into the packet, update the length field and return packet size.
   		return (1);	
   	}
   	
   	public static int decryptFrame(byte[] msgBuff, int index, OFrameStruct decodePacket){
   		
   		return (1);
   	}
   	
   	
   	
    // Positions in the message byte array of TX buffer
   	public static final int LENGTH = 0;		// Overall frame length, excluding this byte, typically <=64
   	public static final int TYPE = 1;		// bit 7 is secure/insecure flag, bits 6-0 constitute the frame type.
   	public static final int SEQ_LEN = 2;	// Frame Sequence number bits 4-7, id length bits 0-3
   	public static final int ID = 3;			// Start Position of ID
   	
    /*
     * Takes a 255 byte message buffer and builds the O'Frame in it by serialising the OFrame data structure for passing to the physical layer.
     */
    public static  int buildOFrame (byte[] msgBuff, OFrameStruct msg){
    	
    	byte crc = 0;
    	int index = ID + msg.idLen;						// set index to the position of body length
    	int i;
    	int packetLen = 5 + msg.idLen + msg.bodyLen; 	// There are 5 fixed bytes in an insecure packet (including the crc)
    	
    	// build the fixed parts of the frame 
    	msgBuff[LENGTH] =  (byte)(packetLen -1);		//the frame length byte contains length -1
    	
    	msgBuff[TYPE] = msg.frameType;					
    	if (msg.secFlag == true){						
    		
    		System.out.println("secure flag set");
    		msgBuff[TYPE] |= 0x80;						// bit 7 of the type byte 
    		
    	}
    	
    	msgBuff[SEQ_LEN] = msg.idLen;					// lower nibble message id length 
    	msgBuff[SEQ_LEN] |= (msg.frameSeqNo << 4);		// upper nibble frame sequence number 
    	
    	// build the variable parts of the frame
    	for (i=0;i<msg.idLen;i++)
    		msgBuff[ID+i]=msg.id[i];					// copy the message id bytes into the message buffer
    	
    	// add the message body fixed elements - if there are any
    	msgBuff[index++] = msg.bodyLen;					// index was initialised to point at the message body length position
    	if (msg.bodyLen !=0){
    		msgBuff[index] = msg.body.valvePos;
    		if (msg.body.heat == true)
    			msgBuff[index] |= 0x80; 				// set the call for heat bit.
    		index++;							
    		
    		msgBuff[index++] = msg.body.flags;
    	}
    	
    	// add the variable length body elements. if there are any
    	if (msg.bodyLen > 2){							// two is the minimum body length
    		byte[] statBody = msg.body.stats.getBytes();
    		
    		for (i=0;i<(msg.bodyLen-2);i++)
    			msgBuff[index++]=statBody[i];		
    	}
    	if (msg.secFlag == true){
    		System.out.println ("starting AESGCM encryption");
    		
    		//index+=encryptFrame (msgBuff,index);
    	}
    	else{	
	    	// compute the crc
	    	crc = computeInsecureFrameCRC(msgBuff,0,(index));
	   
	    	// add crc to end of packet
	        msgBuff[index++]= crc;	
    	}
    	
    	return (index); //return the number of bytes written
    }
    
    /*
     * Parses the incoming message and returns an OFrameStruct object populated with the message contents
     */
    public static OFrameStruct decodeOFrame (byte[] msgBuff){
    			
    	int i=0,j=0;			
    	
    	//allocate memory to build packet in
    	OFrameStruct decodedPacket = new OFrameStruct();
    	BodyStruct body = new BodyStruct();
    	decodedPacket.body = body;
    	
    	decodedPacket.length = msgBuff[i++];				// packet length byte
    	
    	if ((msgBuff[i] & (byte)0x80) == (byte)0x80)		// secure flag in bit 7 of frame type byte
    		decodedPacket.secFlag = true;	
    	
    	decodedPacket.frameType |= (byte)(msgBuff[i++] & (byte)0x7F);	//set up frame type (after masking out bit 7)
    	
    	decodedPacket.idLen = (byte)(msgBuff[i] & (byte)0x0F);	//  id length is bottom nibble of seq length byte
    	decodedPacket.frameSeqNo = (byte)(msgBuff[i++] >>> 4);	//   sequence number is top nibble of seq length byte
    	
    	byte[] id = new byte[decodedPacket.idLen];				// copy id fields
    	decodedPacket.id = id;  	
    	for (j=0;j<decodedPacket.idLen;j++){
    		decodedPacket.id[j] = msgBuff[i++];
    	}
    	
    	decodedPacket.bodyLen = msgBuff[i++];					// message body length
    	
	    if (decodedPacket.bodyLen > 0){							// if there is a message body extract it 
	    	
	    	if (decodedPacket.secFlag == true){					// its secure frame so decrypt it, then return the decoded packet.
	    		
	    		System.out.println("decoding secure frame");
	    	
	    		// when this function returns, the next statement is return ()   	
	    		decryptFrame (msgBuff,i,decodedPacket);
	    	}
	    	else {												// insecure so extract it
	    		if ((msgBuff[i] & (byte)0x80) == (byte)0x80)
	    			decodedPacket.body.heat = true;				// set call for heat flag
	    		
	    		decodedPacket.body.valvePos = (byte)(msgBuff[i++] & (byte)0x7F);		// mask out the call for heat flag to get the valve position
	    			
	    		
	    		decodedPacket.body.flags = msgBuff[i++];		//flags byte
	   
	    		if (decodedPacket.bodyLen > 2)	{				// test to see if there is a JSON object in the field (first 2 bytes are mandatory)
	    			String json = new String();
	    			json ="";
	    			
	    			for (j=0;j<(decodedPacket.bodyLen-2);j++)
	    				json += (char)msgBuff[i++];
	    						
	    			decodedPacket.body.stats = json;			//extracted json
	    		}
	    	}
    	}
	    
	    if (decodedPacket.secFlag == false) {		// There is probably a more elegant way to do this - bit I can't think of it right now
	    	byte crc;
	    
	    	crc = computeInsecureFrameCRC(msgBuff,0,i);
	        
	        if (crc != msgBuff[i])					//check the calculated crc with the received one
	        	return (null);						
	    }
	    
    	return (decodedPacket);
    }
    
   
    
    /**Cryptographically-secure PRNG. */
    private static SecureRandom srnd;

    /**Do some expensive initialisation as lazily as possible... */
    @BeforeClass
    public static void beforeClass() throws NoSuchAlgorithmException
        {
        srnd = SecureRandom.getInstanceStrong(); // JDK 8.
        }

    /**Playpen for understanding jUnit. */
    @Test
    public void testBasics()
        {
//        assertTrue(false);
    	byte[] msgBuff = new byte[0xFF];
    	int msgLen,i;
    	OFrameStruct decodedPacket;
    	
    	// This is Example 1 in Damon's Spec
    	OFrameStruct packetToSendA = new OFrameStruct();
    	byte[] idA = {(byte)0x80,(byte)0x81};
    	
    	BodyStruct bodyA = new BodyStruct();
    	
    	bodyA.heat = false;
    	bodyA.valvePos=0;
    	bodyA.flags = 0x01;
    	
    	packetToSendA.secFlag = false;
    	packetToSendA.frameType = 0x4F; // Insecure O Frame
    	packetToSendA.frameSeqNo = 0;
    	packetToSendA.idLen = 2;
    	packetToSendA.id = idA;
    	packetToSendA.bodyLen = 0x02;
    	packetToSendA.body = bodyA;
   
    	//Example 2 in Damons spec
    	BodyStruct bodyB= new BodyStruct();
    	bodyB.heat = false;
    	bodyB.valvePos=0;
    	bodyB.flags = 0x01;
    	bodyB.stats = "{\"b\":1";
    	
    	OFrameStruct packetToSendB = new OFrameStruct();
    	packetToSendB.secFlag = false;
    	packetToSendB.frameType = 0x4F; // Insecure O Frame
    	packetToSendB.frameSeqNo = 0;
    	packetToSendB.idLen = 2;
    	packetToSendB.id = idA;
    	packetToSendB.bodyLen = 0x08;  
    	packetToSendB.body = bodyB;
    	
    	
    	
    	
    	msgLen = buildOFrame (msgBuff,packetToSendA);
    	System.out.format("Raw data packet is: %02x bytes long \r\n",msgLen);
    	
    	for (i=0;i<msgLen;i++)
    		System.out.format("%02x ", msgBuff[i]);
    	
    		
    	decodedPacket = decodeOFrame (msgBuff);
    	
    	System.out.format("\r\n\r\nDecoded Packet:\r\n");
    	
    	System.out.format("frame length: %02x\r\n",decodedPacket.length);
    	System.out.format("secure flag:  %b\r\n",  decodedPacket.secFlag);
    	System.out.format("frame type:   %02x\r\n",decodedPacket.frameType);
    	System.out.format("sequence no:  %02x\r\n",decodedPacket.frameSeqNo);
    	System.out.format("idLen:        %02x\r\n",decodedPacket.idLen);
    	System.out.format("id:           ");
    	for(i=0;i<decodedPacket.idLen;i++)
    		System.out.format("%02x",decodedPacket.id[i]);
    	System.out.format("\r\n");
    	System.out.format("body length   %02x\r\n",decodedPacket.bodyLen);
    	
    	System.out.format("\r\n\r\nMessage Body\r\n");
    	System.out.format("call for heat  %b\r\n",decodedPacket.body.heat);
    	System.out.format("valve position %02x\r\n",decodedPacket.body.valvePos);
    	System.out.format("json string    %s\r\n",decodedPacket.body.stats);
    						
    	
        }

    /**Check expected behaviour of 7-bit '0x5B' CRC. */
    @Test public void test_crc7_5B()
        {
        // Test against standard text string.
        // For PYCRC 0.8.1
        // Running ./pycrc.py -v --width=7 --poly=0x37 --reflect-in=false --reflect-out=false --xor-in=0 --xor-out=0 --algo=bbb
        // Generates: 0x4
        // From pycrc-generated reference bit-by-bit code.
        byte crcBBB = CRC7_5B.bbb_init();
        crcBBB = CRC7_5B.bbb_update(crcBBB, getStdTestASCIITextAsByteArray(), STD_TEST_ASCII_TEXT.length());
        crcBBB = CRC7_5B.bbb_finalize(crcBBB);
        assertEquals("CRC should match for standard text string", 4, crcBBB);
        }

    }
