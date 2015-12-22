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
    public static final byte AES_GCM_ID = (byte)0x80;	// used in the trailer to indicate the encryption type

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

    
    // Global counters on the TX side for nonce generation
    public static int ResetCounter = 42;
    public static int TxMsgCounter = 42;
    // 6 Byte ID of the sensor 4 MSBs are included as the ID. 2 LSBs are pre-shared between rx and tx.
    public static byte[] LeafID = {(byte)0xAA,(byte)0xAA,(byte)0xAA,(byte)0xAA,(byte)0x55,(byte)0x55};
    
    // Message definitions ToDO - OFrameStruct into header, body and trailer pointers and define a header struct.
    
   static class BodyStruct {
	   	boolean	heat;			// call for heat flag	
    	byte 	valvePos;		// Valve % open
    	byte 	flags;			// assorted flags indicating the sate of the nation (ToDo ref spec doc here)
    	String 	stats;			// Compact JSON object with leading { final } omitted.
    }
    
  
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
    
    
    // The aad is all the header bytes => 4 fixed plus however many are in the ID 
    
    public static byte[] generateAAD (byte[] msgBuff, int len){
    	byte[] aad = new byte[len];
    	
    	System.arraycopy(msgBuff,0,aad,0,len);
    	
    	return(aad);
    }
    
    public static byte[] retrieveAAD(byte[] msgBuff,OFrameStruct decodedPacket){
    	
    	byte [] aad = new byte [decodedPacket.idLen + 4];  //4 bytes plus the size of the leaf node ID field that was sent.
    	
    	System.arraycopy(msgBuff,0,aad, 0, decodedPacket.idLen + 4);
    	
    	return(aad);
    }
    
    // Nonce Generation and Retrieval
    
    /*
     * Construction and use of IV/nonce as:
    	http://www.earth.org.uk/note-on-IoT-security.html#app4
      * 6 most-significant bytes  of leaf ID
      * 3 bytes transmitted of restart/reboot count 
      * 3 bytes TXed of message counter since restart 
     
     */
    public static byte[] generateNonce() {   	
    
    	final byte[] nonce = new byte[GCM_NONCE_LENGTH];
    	
    	System.arraycopy(LeafID,0,nonce,0,6);	// 6MSBs of leaf ID
    	
    	nonce[6] = (byte)(ResetCounter >> 16);	//3 LSB of Reset Counter
    	nonce[7] = (byte)(ResetCounter >> 8);
    	nonce[8] = (byte) ResetCounter;
    	
    	
    	nonce[9]  = (byte)(TxMsgCounter >> 16);	// 3 LSBs of TXmessage counter
    	nonce[10] = (byte)(TxMsgCounter >> 8);		
    	nonce[11] = (byte)TxMsgCounter;
    	
    	return (nonce);
    	
    }
    
    static byte[] presharedIdBytes = {LeafID[4],LeafID[5]};
    
    
    
    
    /* retrieve nonce from:
     * 4 MSBs of ID
     * 2 LSBs of ID, that are not sent OTA but magically shared
     * 3 bytes of resatr counter - retrieved from the trailer
     * 3 bytes od tx message counter - retrieved from the trailer
     *
     * @param msgBuff Raw message received from the aether
     * @param pos index into msgBuff at the start of the message body
     * @param decodedFrame the bits of the frame that have been decoded so far. i,e the header at this point
     */
    
    public static byte[] retrieveNonce (byte[] msgBuff, int pos, OFrameStruct decodedFrame ){
    
    	byte[] nonce= new byte[GCM_NONCE_LENGTH];
    	byte nonceIndx = 0;
    	
    	pos += decodedFrame.bodyLen;						// point pos at the trailer in the msgBuff
    	
    	if (msgBuff[pos++] != AES_GCM_ID){					// test trailer first byte to make sure we are dealing with the correct algo
    		
    		System.out.println("unrecognized encryption algorithm");
    		System.exit(1);
    	}
    	
    	if (decodedFrame.idLen < 4){						// check there are 4 bytes in the ID field in the header
    		System.out.format("leaf node ID length %d in header too short. should be >=4bytes\r\n",decodedFrame.idLen);
    		System.exit(1);	
    	}
    	
    	System.arraycopy(decodedFrame.id, 0, nonce, 0, decodedFrame.idLen);		// copy the first 4 (MSBs) of the ID from the header
    	nonceIndx+=decodedFrame.idLen;
    	
    	System.arraycopy(presharedIdBytes,0,nonce,nonceIndx,2);					// copy the preshared ID bytes
    	nonceIndx+=2;
    	
    	System.arraycopy(msgBuff[pos], 0, nonce, nonceIndx, 3);					// copy the 3 restart counter bytes out of the trailer
    	nonceIndx+=3;
    	pos+=3;
    	
    	System.arraycopy(msgBuff[pos], 0, nonce, nonceIndx, 3);					// copy the 3 tx message counter bytes out of the trailer
    	nonceIndx+=3;
    	pos+=3;
    	
    	return (nonce);
    	
    }
    
    public static String removePadding (byte[] plainText){
    	
    	//look at the last byte of the array to see how much padding there is
    	int size = plainText.length;
    	int padding = plainText[size-1];
    	size -= padding;
    	byte[]unpadded = new byte[size];
    	    	
    	//remove padding 
    	for (int i=0;i<size;i++)
    		unpadded[i]=plainText[i];
    	
    	return (new String (unpadded));	
    }
    
    /*
    pads the message body out with 0s to 16 or 32 bits. Errors if length > 31
    and sticks the number of bytes of padding in the last element of the array.
    
    @param body structure containing the message bod for encryption
    @param len length (in bytes) of the structure   
    returns byte array containing the padded message.
    */
    
    public static byte[] addPadding (BodyStruct body, byte len){
    	byte[] paddedMsg;
    	
    	if(len >=32) {
    		System.out.format("Body length %d too big. 32 Max",len);
    		System.exit(1);
    	}  	
    	paddedMsg = new byte[(len<16)? 16:32];
    	paddedMsg[0]= (body.valvePos |= ((body.heat == true)? (byte)0x80 : (byte)0x00)); //OR in the call for heat bit
    	paddedMsg[1]= body.flags;
    	System.arraycopy(body.stats.getBytes(),0,paddedMsg,2,body.stats.length());
    	
    	paddedMsg[paddedMsg.length-1]= (byte)(paddedMsg.length - (len+1));	// add the number of bytes of padding to the last byte in the array.
   		
    	return (paddedMsg);
    }
    
    public static int addTrailer (byte[] msgBuff,int index, byte[] authTag)
    {
    	
    	msgBuff[index] = AES_GCM_ID;					// indicated AESGCM encryption mode
    	
    	msgBuff[index++] = (byte)(ResetCounter >> 16);	//3 LSB of Reset Counter
    	msgBuff[index++] = (byte)(ResetCounter >> 8);
    	msgBuff[index++] = (byte) ResetCounter;
    	
    	msgBuff[index++] = (byte)(TxMsgCounter >> 16);	// 3 LSBs of TXmessage counter
    	msgBuff[index++] = (byte)(TxMsgCounter >> 8);		
    	msgBuff[index++] = (byte)TxMsgCounter;
    	
    	System.arraycopy(authTag,0, msgBuff, index, authTag.length); 	// copy the authentication tag into the message buffer
    	
    	return (index++);	// size of the completed TX packet
    	
    }
    
    
    
    /*
     The algorithm has four inputs: a secret key, an initialization vector (IV),  plaintext, and an input for additional authenticated data (AAD).
     It has two outputs, a ciphertext whose length is identical to the plaintext, and an authentication tag

		where:
		
		inputs
		* The secret key is the 128bit preshared key 
		* The IV is as per this spec - http://www.earth.org.uk/OpenTRV/stds/network/20151203-DRAFT-SecureBasicFrame.txt
		* The plain text is the message body, 0 padded to 15 +1 bytes (the 1 byte indicating the amount of padding)
		* AAD is the 8 header bytes of the frame (length, type, seqlen, 4xID bytes, bodyLength)
		
		outputs
		* The cipher text is the encrypted message body and is the same length as the plain text.
		* The authentication tag is included in the trailer
		
		The transmitted frame then contains:
		 The 8 byte header (unencrypted)
		 The 16 byte padded body (encrypted)
		 The 23 byte trailer (which includes the 16byte authentication tag) as detailed in the spec (unencrypted)
			
		On the decrypt side, the spec variable is reconstituted using the nonce (from the rx'd trailer) along with the pre-shared 128bit key and the preshared non transmitted bytes of the ID. 
     
     */
    

    /* 
     * @param msgBuff 	contains a pointer to a 255 byte buffer with partially build packet to send in it
     * @param length  	contains the number of bytes currently in the buffer -i.e it points to next empty memory location 
     * @param body 		contains the message body to encrypt
     * 
     * returns the number of bytes written to 
     */
    
   	public static int encryptFrame(byte[] msgBuff, int length, OFrameStruct frame,byte[] authTag) throws Exception {
   		
   		//prepare plain text
   		final byte[] input = addPadding(frame.body, frame.bodyLen); 	// pad body content out to 16 or 32 bytes. 
   		
   		
   		// Generate IV (nonce)
   		final byte[] nonce = generateNonce();
   		
   		final GCMParameterSpec spec = new GCMParameterSpec(GCM_TAG_LENGTH * 8, nonce);
   		
   		// generate AAD
   		final byte[] aad = generateAAD(msgBuff,(frame.idLen+4));		// aad = the header - 4 bytes + sizeof ID
   		
   		// Do the encrption - 
   		final Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding", "SunJCE"); // JDK 7 breaks here..
   		cipher.init(Cipher.ENCRYPT_MODE, key, spec);
   		cipher.updateAAD(aad);
   		final byte[] cipherText = cipher.doFinal(input); // the authentication tag should end up appended to the cipher text
   		
   		System.out.println("Size plain="+input.length+" aad="+aad.length+" cipher="+cipherText.length);
   		
   		
   		// copy the authentication tag appended to the end of cipherText into authTag
   		System.arraycopy(cipherText,input.length,authTag,0,GCM_TAG_LENGTH);
        
   		return (input.length);

   	}
   	
   	/*
   	 * @param msgBuff 		The received message from the aether
   	 * @param index 		Set to the start of the message body section
   	 * @param decodedPacket The decoded header section of the message.
   	 *   
   	 */
   	
   	public static void decryptFrame(byte[] msgBuff, int index, OFrameStruct decodedPacket) throws Exception{
   	   	
   		// Retrieve Nonce
   		byte[] nonce = retrieveNonce (msgBuff, index,decodedPacket);   	
   		
   		final GCMParameterSpec spec = new GCMParameterSpec(GCM_TAG_LENGTH * 8, nonce);
   		
   		//retrieve AAD
   		final byte[] aad = retrieveAAD(msgBuff,decodedPacket);		// decodedPacket needed to deduce the length of the header.
   		
   		// copy received cipher text to appropriately sized array
   		byte[] cipherText = new byte[decodedPacket.bodyLen + GCM_TAG_LENGTH]; // cipher text has the auth tag appended to it
   		System.arraycopy(msgBuff, index, cipherText, 0, decodedPacket.bodyLen);
   		
   		// append the authentication tag to the cipher text - this is a peculiarity of this Java implementation.
   		// The algo authenticates before decrypting, which is more efficient and less likely to kill the decryption engine with random crap.
   		
   		// the magic 7 is the offset from the start of the trailer to the  auth tag.
   		System.arraycopy(msgBuff,(index+decodedPacket.bodyLen+7) , cipherText,decodedPacket.bodyLen, GCM_TAG_LENGTH); 
   		
   	
   		// Decrypt: 
   		final Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding", "SunJCE"); // JDK 7 breaks here..
        cipher.init(Cipher.DECRYPT_MODE, key, spec);
        cipher.updateAAD(aad);
        final byte[] plainText = cipher.doFinal(cipherText);
        
        byte[] plainTextMsg = new byte[plainText.length - GCM_TAG_LENGTH];
        System.arraycopy(plainText, 0, plainTextMsg, 0, plainText.length - GCM_TAG_LENGTH); // separate the message body from the auth tag
        
        // copy unpadded plain text  into the decoded Packet Structure.
        decodedPacket.body.stats = removePadding (plainTextMsg); 
        
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
    	
    	
    	/*
    	 * Header
    	 */
    	 	
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
    	
    	
    	/*
    	 * Insecure Body and CRC
    	 */
    	
    	if (msg.secFlag == false){	
    		
	    	if (msg.bodyLen !=0){
	    		
	    		msgBuff[index] = msg.body.valvePos;			// copy the valve position
	    		if (msg.body.heat == true)
	    			msgBuff[index] |= 0x80; 				// set the call for heat bit.
	    		index++;							
	    		
	    		msgBuff[index++] = msg.body.flags;			// copy the flags byte
	    	}
	    	
	    	// add the variable length body elements. if there are any
	    	if (msg.bodyLen > 2){							// two is the minimum body length
	    		byte[] statBody = msg.body.stats.getBytes();
	    		
	    		for (i=0;i<(msg.bodyLen-2);i++)
	    			msgBuff[index++]=statBody[i];		
	    	}
	    	
	    		
		    // compute the crc
		    crc = computeInsecureFrameCRC(msgBuff,0,(index));
		   
		    // add crc to end of packet
		       msgBuff[index++]= crc;	
	    
		    return (index); //return the number of bytes written
    	}
    	
    	/*
    	 * Secure Body and 23 byte Trailer
    	 */
    	else {
    		
    		byte[] authTag = new byte[GCM_TAG_LENGTH];
    		
    		try {
				index+= encryptFrame (msgBuff,index,msg,authTag);
			} catch (Exception e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
				System.out.println("exceptiom thrown in decrypt frame");
				System.exit(1);
			}
    		
    		
    		index = addTrailer (msgBuff,index,authTag);
    		
    		return(index);
    	}	
    		
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
    	
    	//Message Header
    	
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
    	
    	// Message Body
    	
	    if (decodedPacket.bodyLen > 0){							// if there is a message body extract it 
	    	
	    	if (decodedPacket.secFlag == true){					// its secure frame so decrypt it, then return the decoded packet.
	    		
	    		System.out.println("decoding secure frame");
	    	  	
	    		try {
					 decryptFrame (msgBuff,i,decodedPacket);		// decrypt the frame
				} catch (Exception e) {
					// TODO Auto-generated catch block
					e.printStackTrace();
					System.out.println("exceptiom thrown in decrypt frame");
					System.exit(1);
				}
	    		
	    		
	    		
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
	    
	    
	    // Message Trailer
	    
	    if (decodedPacket.secFlag == false) {		
	    	byte[] crc = new byte[1];
	    
	    	crc[0] = computeInsecureFrameCRC(msgBuff,0,i);
	    	
	    	decodedPacket.trailer = crc;
	        
	        if (crc[0] != msgBuff[i])					//check the calculated crc with the received one
	        	return (null);						
	    }
	    else { // Extract the 23 byte trailer from the secure message
	    	
	    	byte[] trailer = new byte[23];
	    	int trailerPtr = 4+decodedPacket.idLen; // 4 fixed header bytes plus the sizeof the ID
	    	
	    	for (i=0;i<23;i++)
	    		trailer[i]=msgBuff[trailerPtr++];
	    	
	    	decodedPacket.trailer = trailer;  	
	    }
	    
    	return (decodedPacket);
    }
    
   
    
    /**Cryptographically-secure PRNG. */
    //private static SecureRandom srnd;
    private static SecretKey key;
    
    /**Do some expensive initialisation as lazily as possible... */
    @BeforeClass
    public static void beforeClass() throws NoSuchAlgorithmException
        {
    	SecureRandom srnd;
    	
        srnd = SecureRandom.getInstanceStrong(); // JDK 8.
        
     // Generate Key - needs to be available for the decrypt side too
   		final KeyGenerator keyGen = KeyGenerator.getInstance("AES");
   		keyGen.init(AES_KEY_SIZE, srnd);		
   		key = keyGen.generateKey();
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
    	bodyB.valvePos=0x7f;
    	bodyB.flags = 0x11;
    	bodyB.stats = "{\"b\":1";
    	
    	OFrameStruct packetToSendB = new OFrameStruct();
    	packetToSendB.secFlag = false;
    	packetToSendB.frameType = 0x4F; // Insecure O Frame
    	packetToSendB.frameSeqNo = 0;
    	packetToSendB.idLen = 2;
    	packetToSendB.id = idA;
    	packetToSendB.bodyLen = 0x08;  
    	packetToSendB.body = bodyB;
    	
    	
    	
    	
    	msgLen = buildOFrame (msgBuff,packetToSendB);
    	System.out.format("Raw data packet is: %02x bytes long \r\n",msgLen);
    	
    	for (i=0;i<msgLen;i++)
    		System.out.format("%02x ", msgBuff[i]);
    	
    		
    	decodedPacket = decodeOFrame (msgBuff);
    	// raw data
    	System.out.format("\r\n\r\nDecoded Packet:\r\n");
    	
    	//header
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
    	
    	//message
    	System.out.format("\r\n\r\nMessage Body\r\n");
    	System.out.format("call for heat  %b\r\n",decodedPacket.body.heat);
    	
    	if ( decodedPacket.body.valvePos == 0x7F)
    		System.out.println("no valve present");
    	else 
    		System.out.format("valve position %02x\r\n",decodedPacket.body.valvePos);
    	
    	System.out.format("\r\nflags           %02x\r\n",decodedPacket.body.flags);
    	System.out.println(("fault flag:     " + (((decodedPacket.body.flags & 0x80)== (byte)0x80)? "set":"clear")));
    	System.out.println(("low battery:    " + (((decodedPacket.body.flags & 0x40)== (byte)0x40)? "set":"clear")));
    	System.out.println(("tamper flag:    " + (((decodedPacket.body.flags & 0x20)== (byte)0x20)? "set":"clear")));
    	System.out.println(("stats present:  " + (((decodedPacket.body.flags & 0x10)== (byte)0x10)? "set":"clear")));
    	
    	System.out.println(("occupancy:      " + (((decodedPacket.body.flags & 0x0C)== (byte)0x00)? "unreported":"")));
    	System.out.println(("occupancy:      " + (((decodedPacket.body.flags & 0x0C)== (byte)0x04)? "none":"")));
    	System.out.println(("occupancy:      " + (((decodedPacket.body.flags & 0x0C)== (byte)0x08)? "possible":"")));
    	System.out.println(("occupancy:      " + (((decodedPacket.body.flags & 0x0C)== (byte)0x0c)? "likely":"")));
    	System.out.println("bottom 2 bits reserved value of b01");
    	
    	System.out.format("\r\njson string    %s\r\n",decodedPacket.body.stats);
    	
    	//Trailer
    	if (decodedPacket.secFlag == false)
    		System.out.format("CRC: %02x",decodedPacket.trailer[0]);
    	else{
    		
    		System.out.println("Trailer Bytes");
    		for(i=0;i<23;i++)
    			System.out.format("02x ", decodedPacket.trailer[i]);
    	}
    		
    		
    		
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
