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

Author(s) / Copyright (s): Damon Hart-Davis 2015
                           Matthew Waite 2015
*/

package uk.org.opentrv.test.leafauthenc;

import static org.junit.Assert.assertEquals;

import java.io.UnsupportedEncodingException;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;

import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;

import org.junit.BeforeClass;
import org.junit.Test;

import uk.org.opentrv.comms.util.crc.CRC7_5B;

public class SecureFrameTest
    {
    public static final int AES_KEY_SIZE = 128; // in bits
    public static final int GCM_NONCE_LENGTH = 12; // in bytes
    public static final int GCM_TAG_LENGTH = 16; // in bytes (default 16, 12 possible)
    public static final byte AES_GCM_ID = (byte)0x80;    // used in the trailer to indicate the encryption type

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


    // Nominal global counters on the TX side for nonce generation
    public static final int ResetCounter = 42;
    public static final int TxMsgCounter = 793;
    // 6 Byte ID of the sensor 4 MSBs are included as the ID. 2 LSBs are pre-shared between rx and tx.
    public static byte[] LeafID = {(byte)0xAA,(byte)0xAA,(byte)0xAA,(byte)0xAA,(byte)0x55,(byte)0x55};

    // Message definitions ToDO - OFrameStruct into header, body and trailer pointers and define a header struct.

   static class BodyStruct {
           boolean    heat;            // call for heat flag
        byte     valvePos;        // Valve % open
        byte     flags;            // assorted flags indicating the sate of the nation (ToDo ref spec doc here)
        String     stats;            // Compact JSON object with leading { final } omitted.
    }


    static class OFrameStruct {
        byte         length;            // Overall frame length, excluding this byte, typically <=64 and filled in automatically
        boolean        secFlag;        // secure flag
        byte         frameType;        // frame type.
        byte         frameSeqNo;        // Frame Sequence number bits 4-7,
        byte        idLen;            //    length of the id field
        byte []     id;                // 0 implies anonymous, typically 2 bytes.
        byte        bodyLen;        // length of the body section
        BodyStruct    body;            // Body section
        byte[]        trailer;        // Trailer - either a 7bit CRC for insecure frame or variable length security
                                    // info in the encrypted case, with the length determined by encryption method used
    }

    // The aad is all the header bytes => 4 fixed plus however many are in the ID

    public static byte[] generateAAD (final byte[] msgBuff, final int len){
        final byte[] aad = new byte[len];

        System.arraycopy(msgBuff,0,aad,0,len);

        return(aad);
    }

    public static byte[] retrieveAAD(final byte[] msgBuff,final OFrameStruct decodedPacket){

        final byte [] aad = new byte [decodedPacket.idLen + 4];  //4 bytes plus the size of the leaf node ID field that was sent.

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

        System.arraycopy(LeafID,0,nonce,0,6);    // 6MSBs of leaf ID

        nonce[6] = (byte)(ResetCounter >> 16);    //3 LSB of Reset Counter
        nonce[7] = (byte)(ResetCounter >> 8);
        nonce[8] = (byte) ResetCounter;


        nonce[9]  = (byte)(TxMsgCounter >> 16);    // 3 LSBs of TXmessage counter
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

    public static byte[] retrieveNonce (final byte[] msgBuff, int pos, final OFrameStruct decodedFrame ){

        final byte[] nonce= new byte[GCM_NONCE_LENGTH];
        byte nonceIndx = 0;

        pos += decodedFrame.bodyLen;                        // point pos at the trailer in the msgBuff

        if (msgBuff[pos++] != AES_GCM_ID){                    // test trailer first byte to make sure we are dealing with the correct algo

            System.out.println("unrecognized encryption algorithm");
            System.exit(1);
        }

        if (decodedFrame.idLen < 4){                        // check there are 4 bytes in the ID field in the header
            System.out.format("leaf node ID length %d in header too short. should be >=4bytes\r\n",decodedFrame.idLen);
            System.exit(1);
        }

        System.arraycopy(decodedFrame.id, 0, nonce, 0, decodedFrame.idLen);        // copy the first 4 (MSBs) of the ID from the header
        nonceIndx+=decodedFrame.idLen;

        System.arraycopy(presharedIdBytes,0,nonce,nonceIndx,2);                    // copy the preshared ID bytes
        nonceIndx+=2;

        System.arraycopy(msgBuff, pos, nonce, nonceIndx, 3);                    // copy the 3 restart counter bytes out of the trailer
        nonceIndx+=3;
        pos+=3;

        System.arraycopy(msgBuff, pos, nonce, nonceIndx, 3);                    // copy the 3 tx message counter bytes out of the trailer


        return (nonce);

    }

    public static byte[] removePadding (final byte[] plainText){

        //look at the last byte of the array to see how much padding there is
        int size = plainText.length;

        System.out.println("size ="+ size);

        final int padding = plainText[size-1];
        size -= padding;
        final byte[]unpadded = new byte[size];

        //remove padding
        for (int i=0;i<size;i++)
            {
                unpadded[i]=plainText[i];
                }

        return (unpadded);
    }

    /*
    pads the message body out with 0s to 16 or 32 bits. Errors if length > 31
    and sticks the number of bytes of padding in the last element of the array.

    @param body structure containing the message bod for encryption
    @param len length (in bytes) of the structure
    returns byte array containing the padded message.
    */

    public static byte[] addPadding (final BodyStruct body, final byte len){
        byte[] paddedMsg;

        System.out.println("\r\n Length = "+len);

        if(len >=32) {
            System.out.format("Body length %d too big. 32 Max",len);
            System.exit(1);
        }
        paddedMsg = new byte[(len<16)? 16:32];
        paddedMsg[0]= (body.valvePos |= ((body.heat == true)? (byte)0x80 : (byte)0x00)); //OR in the call for heat bit
        paddedMsg[1]= body.flags;
        System.arraycopy(body.stats.getBytes(),0,paddedMsg,2,body.stats.getBytes().length);
        final int padding =(paddedMsg.length - (len+1));
        paddedMsg[paddedMsg.length-1]= (byte)padding;    // add the number of bytes of padding to the last byte in the array.




        return (paddedMsg);
    }

    public static int addTrailer (final byte[] msgBuff,int index, final byte[] authTag)
    {


        msgBuff[index++] = AES_GCM_ID;                    // indicated AESGCM encryption mode

        msgBuff[index++] = (byte)(ResetCounter >> 16);    //3 LSB of Reset Counter
        msgBuff[index++] = (byte)(ResetCounter >> 8);
        msgBuff[index++] = (byte) ResetCounter;

        msgBuff[index++] = (byte)(TxMsgCounter >> 16);    // 3 LSBs of TXmessage counter
        msgBuff[index++] = (byte)(TxMsgCounter >> 8);
        msgBuff[index++] = (byte)TxMsgCounter;

        System.arraycopy(authTag,0, msgBuff, index, authTag.length);     // copy the authentication tag into the message buffer

        return (index+authTag.length);    // size of the completed TX packet

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
        * The authentication tag appended to the decrypted message in the output of the Java algo.

        The transmitted frame then contains:
         The 8 byte header (unencrypted)
         The 16 byte padded body (encrypted)
         The 23 byte trailer (which includes the 16byte authentication tag) as detailed in the spec (unencrypted)

        On the decrypt side, the spec variable is reconstituted using the nonce (from the rx'd trailer) along with the pre-shared 128bit key and the preshared non transmitted bytes of the ID.

     */


    /*
     * @param msgBuff     contains a pointer to a 255 byte buffer with partially build packet to send in it
     * @param pos          points to the start of the body section in msgBuff
     * @param body         contains the message body to encrypt
     *
     * returns the number of bytes written to
     */

       public static int encryptFrame(final byte[] msgBuff, final int pos, final OFrameStruct frame,final byte[] authTag) throws Exception {

           //prepare plain text
           final byte[] input = addPadding(frame.body, frame.bodyLen);     // pad body content out to 16 or 32 bytes.

           //Update frame length Header = 4+idLen bytes. Body padded bodylength (input.length). Trailer is fixed 23 bytes
           // A better place to do this might be after the trailer has been built. An even better design would be to have separate
           // structures for header, body and trailer - this would make the design more extensible and do away with lots of magic numbers.

           msgBuff[0] = (byte)(4+frame.idLen+input.length + 23);

           // setup the bodylength now it has been padded
           frame.bodyLen = (byte)input.length;

           msgBuff[pos-1] = (frame.bodyLen);        //Pos -1 is a bit of a hack. This will be fixed with architectural change of body structure to contain the body length.

           // Generate IV (nonce)
           final byte[] nonce = generateNonce();

           final GCMParameterSpec spec = new GCMParameterSpec(GCM_TAG_LENGTH * 8, nonce);

           // generate AAD
           final byte[] aad = generateAAD(msgBuff,(frame.idLen+4));        // aad = the header - 4 bytes + sizeof ID

           // Do the encrption -
           final Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding", "SunJCE"); // JDK 7 breaks here..
           cipher.init(Cipher.ENCRYPT_MODE, key, spec);
           cipher.updateAAD(aad);
           final byte[] cipherText = cipher.doFinal(input); // the authentication tag should end up appended to the cipher text

           // print input
           System.out.format("%d Byte padded input text\r\n",input.length);
           for(final byte element : input)
            {
                System.out.format("%02x ",element);
                }
           System.out.format("\r\n\r\n");

           // print nonce
           System.out.format("%d Byte Nonce\r\n",nonce.length);
           for(final byte element : nonce)
            {
                System.out.format("%02x ",element);
                }
           System.out.format("\r\n\r\n");

           //print aad
           System.out.format("%d Byte aad\r\n",aad.length);
           for(final byte element : aad)
            {
                System.out.format("%02x ",element);
                }
           System.out.format("\r\n\r\n");

           //print output
           System.out.format("%d Byte cipher text plus authentication tag output from algo\r\n",cipherText.length);
           for(final byte element : cipherText)
            {
                System.out.format("%02x ",element);
                }
           System.out.format("\r\n\r\n");

           // copy cipher text minus authtag to the msgBuff
        System.arraycopy(cipherText,0,msgBuff,pos, cipherText.length - GCM_TAG_LENGTH);

           // copy the authentication tag appended to the end of cipherText into authTag
           System.arraycopy(cipherText,input.length,authTag,0,GCM_TAG_LENGTH);


           return (input.length);

       }

       /*
        * @param msgBuff         The received message from the aether
        * @param index         Set to the start of the message body section
        * @param decodedPacket The decoded header section of the message.
        *
        */

       public static void decryptFrame(final byte[] msgBuff, final int index, final OFrameStruct decodedPacket) throws Exception{

           // Retrieve Nonce
           final byte[] nonce = retrieveNonce (msgBuff, index,decodedPacket);

           System.out.println("\r\nRetrieved nonce");
           for(final byte element : nonce)
            {
                System.out.format("%02x ",element);
                }


           final GCMParameterSpec spec = new GCMParameterSpec(GCM_TAG_LENGTH * 8, nonce);

           //retrieve AAD
           final byte[] aad = retrieveAAD(msgBuff,decodedPacket);        // decodedPacket needed to deduce the length of the header.

           System.out.println("\r\nRetrieved aad");
           for(final byte element : aad)
            {
                System.out.format("%02x ",element);
                }

           // copy received ecrypted body text to appropriately sized array
           final byte[] cipherText = new byte[decodedPacket.bodyLen + GCM_TAG_LENGTH]; // cipher text has the auth tag appended to it
           System.arraycopy(msgBuff, index, cipherText, 0, decodedPacket.bodyLen);

           // append the authentication tag to the cipher text - this is a peculiarity of this Java implementation.
           // The algo authenticates before decrypting, which is more efficient and less likely to kill the decryption engine with random crap.

           // the magic 7 is the offset from the start of the trailer to the  auth tag.
           System.arraycopy(msgBuff,(index+decodedPacket.bodyLen+7) , cipherText,decodedPacket.bodyLen, GCM_TAG_LENGTH);

           System.out.format("\r\nRetrieved  %d byte cipher text with auth tag appended\r\n", cipherText.length);
           for(final byte element : cipherText)
            {
                System.out.format("%02x ",element);
                }


           // Decrypt:
           final Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding", "SunJCE"); // JDK 7 breaks here..
        cipher.init(Cipher.DECRYPT_MODE, key, spec);
        cipher.updateAAD(aad);
        final byte[] plainText = cipher.doFinal(cipherText);

        //print out received plain text
        System.out.println("\r\nDecrypted plain text");
           for(final byte element : plainText)
            {
                System.out.format("%02x ",element);
                }

           // copy unpadded plain text  into the decoded Packet Structure.
        final byte[] unpadded = removePadding (plainText);

        System.out.println("unpadded length =" + unpadded.length);

        // copy stats string to the structure
        final byte[] stats = new byte[unpadded.length-2];
        System.arraycopy (unpadded,2,stats,0,unpadded.length-2);
        decodedPacket.body.stats = new String(stats);

        // set heat flag and valve position
        if ((unpadded[0] & 0x80)== 0x80)
            {
                decodedPacket.body.heat = true;
                }

        // clear out the top bit and set the valve position
        unpadded[0]&= 0x7F;
        decodedPacket.body.valvePos = unpadded[0];

        //set up the flags
        decodedPacket.body.flags = unpadded[1];

       }



    // Positions in the message byte array of TX buffer
       public static final int LENGTH = 0;        // Overall frame length, excluding this byte, typically <=64
       public static final int TYPE = 1;        // bit 7 is secure/insecure flag, bits 6-0 constitute the frame type.
       public static final int SEQ_LEN = 2;    // Frame Sequence number bits 4-7, id length bits 0-3
       public static final int ID = 3;            // Start Position of ID

    /*
     * Takes a 255 byte message buffer and builds the O'Frame in it by serialising the OFrame data structure for passing to the physical layer.
     */
    public static  int buildOFrame (final byte[] msgBuff, final OFrameStruct msg){

        byte crc = 0;
        int index = ID + msg.idLen;                        // set index to the position of body length field
        final int bodyPos = index+1;                            // bodyPos points at the actual body section of the frame
        int i;
        final int packetLen = 5 + msg.idLen + msg.bodyLen;     // There are 5 fixed bytes in an insecure packet (including the crc)



        System.out.println("body len = "+msg.bodyLen);

        /*
         * Header
         */

        if (msg.secFlag == false)
         {
                msgBuff[LENGTH] =  (byte)(packetLen -1);        //the frame length byte contains length -1
                }

        // The packet length for secure packets gets set in the buildOFrame() function

        msgBuff[TYPE] = msg.frameType;
        if (msg.secFlag == true){

            System.out.println("secure flag set");
            msgBuff[TYPE] |= 0x80;                        // bit 7 of the type byte

        }
        msgBuff[SEQ_LEN] = msg.idLen;                    // lower nibble message id length
        msgBuff[SEQ_LEN] |= (msg.frameSeqNo << 4);        // upper nibble frame sequence number

        // build the variable parts of the frame
        for (i=0;i<msg.idLen;i++)
         {
                msgBuff[ID+i]=msg.id[i];                    // copy the message id bytes into the message buffer
                }




        /*
         * Insecure Body and CRC
         */

        if (msg.secFlag == false){
            // add the message body fixed elements. the assumption here is tha the body length field has been pre-filled in the struct
            msgBuff[index++] = msg.bodyLen;                    // index was initialised to point at the message body length position

            if (msg.bodyLen !=0){

                msgBuff[index] = msg.body.valvePos;            // copy the valve position
                if (msg.body.heat == true)
                 {
                        msgBuff[index] |= 0x80;                 // set the call for heat bit.
                        }
                index++;

                msgBuff[index++] = msg.body.flags;            // copy the flags byte
            }

            // add the variable length body elements. if there are any
            if (msg.bodyLen > 2){                            // two is the minimum body length
                final byte[] statBody = msg.body.stats.getBytes();

                for (i=0;i<(msg.bodyLen-2);i++)
                    {
                        msgBuff[index++]=statBody[i];
                        }
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

            final byte[] authTag = new byte[GCM_TAG_LENGTH];
            byte length=0;

            if (msg.idLen < 4){
                System.out.println("Leaf node ID too short. Must be 4 or more bytes");
                System.exit(1);
            }

            try {

                length = (byte)encryptFrame (msgBuff,bodyPos,msg,authTag);

                //msg.bodyLen is set up in the encryption function, after the padding has been added
                index++;                            // index was initialised to point at the body length field at the top of the function.

                index+=length;                        // move index to point at the start of the trailer
            } catch (final Exception e) {
                // TODO Auto-generated catch block
                e.printStackTrace();
                System.out.println("exceptiom thrown in encrypt frame");
                System.exit(1);
            }


            index+= addTrailer (msgBuff,(bodyPos+length),authTag);
            return(index);
        }

    }

    /*
     * Parses the incoming message and returns an OFrameStruct object populated with the message contents
     */
    public static OFrameStruct decodeOFrame (final byte[] msgBuff){

        int i=0,j=0;

        //allocate memory to build packet in
        final OFrameStruct decodedPacket = new OFrameStruct();
        final BodyStruct body = new BodyStruct();
        decodedPacket.body = body;

        //Message Header

        decodedPacket.length = msgBuff[i++];                // packet length byte

        if ((msgBuff[i] & (byte)0x80) == (byte)0x80)
            {
                decodedPacket.secFlag = true;
                }

        decodedPacket.frameType |= (byte)(msgBuff[i++] & (byte)0x7F);    //set up frame type (after masking out bit 7)

        decodedPacket.idLen = (byte)(msgBuff[i] & (byte)0x0F);    //  id length is bottom nibble of seq length byte
        decodedPacket.frameSeqNo = (byte)(msgBuff[i++] >>> 4);    //   sequence number is top nibble of seq length byte

        final byte[] id = new byte[decodedPacket.idLen];                // copy id fields
        decodedPacket.id = id;
        for (j=0;j<decodedPacket.idLen;j++){
            decodedPacket.id[j] = msgBuff[i++];
        }

        decodedPacket.bodyLen = msgBuff[i++];                    // message body length

        // Message Body

        if (decodedPacket.bodyLen > 0){                            // if there is a message body extract it

            if (decodedPacket.secFlag == true){                    // its secure frame so decrypt it, then return the decoded packet.

                System.out.println("decoding secure frame");

                try {
                     decryptFrame (msgBuff,i,decodedPacket);        // decrypt the frame
                } catch (final Exception e) {
                    // TODO Auto-generated catch block
                    e.printStackTrace();
                    System.out.println("exceptiom thrown in decrypt frame");
                    System.exit(1);
                }



            }
            else {                                                // insecure so extract it

                System.out.println("decoding insecure frame");

                if ((msgBuff[i] & (byte)0x80) == (byte)0x80)
                 {
                        decodedPacket.body.heat = true;                // set call for heat flag
                        }

                decodedPacket.body.valvePos = (byte)(msgBuff[i++] & (byte)0x7F);        // mask out the call for heat flag to get the valve position


                decodedPacket.body.flags = msgBuff[i++];        //flags byte

                if (decodedPacket.bodyLen > 2)    {                // test to see if there is a JSON object in the field (first 2 bytes are mandatory)
                    String json = new String();
                    json ="";

                    for (j=0;j<(decodedPacket.bodyLen-2);j++)
                        {
                            json += (char)msgBuff[i++];
                            }

                    decodedPacket.body.stats = json;            //extracted json
                }
            }
        }
        else
            {
                System.out.println("No Message Content found");
                }


        // Message Trailer

        if (decodedPacket.secFlag == false) {
            final byte[] crc = new byte[1];

            crc[0] = computeInsecureFrameCRC(msgBuff,0,i);

            decodedPacket.trailer = crc;

            if (crc[0] != msgBuff[i]) {
                return (null);
                }
        }
        else { // Extract the 23 byte trailer from the secure message

            final byte[] trailer = new byte[23];
            int trailerPtr = 4+decodedPacket.idLen; // 4 fixed header bytes plus the sizeof the ID

            for (i=0;i<23;i++)
                {
                    trailer[i]=msgBuff[trailerPtr++];
                    }

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
        final SecureRandom srnd;

//        srnd = SecureRandom.getInstanceStrong(); // JDK 8.

     // Generate Key - needs to be available for the decrypt side too
//           final KeyGenerator keyGen = KeyGenerator.getInstance("AES");
//           keyGen.init(AES_KEY_SIZE, srnd);
//           key = keyGen.generateKey();
        key = new SecretKeySpec(new byte[AES_KEY_SIZE/8], 0, AES_KEY_SIZE/8, "AES");
        }


    public static void printPacket (final OFrameStruct decodedPacket){
        byte i=0;

        System.out.format("\r\n\r\nDecoded Packet:\r\n");

        //header
        System.out.format("frame length: %02x\r\n",decodedPacket.length);
        System.out.format("secure flag:  %b\r\n",  decodedPacket.secFlag);
        System.out.format("frame type:   %02x\r\n",decodedPacket.frameType);
        System.out.format("sequence no:  %02x\r\n",decodedPacket.frameSeqNo);
        System.out.format("idLen:        %02x\r\n",decodedPacket.idLen);
        System.out.format("id:           ");
        for(i=0;i<decodedPacket.idLen;i++)
            {
                System.out.format("%02x",decodedPacket.id[i]);
                }
        System.out.format("\r\n");
        System.out.format("body length   %02x\r\n",decodedPacket.bodyLen);

        //message
        System.out.format("\r\n\r\nMessage Body\r\n");
        System.out.format("call for heat  %b\r\n",decodedPacket.body.heat);

        if ( decodedPacket.body.valvePos == 0x7F)
            {
                System.out.println("no valve present");
                }
        else
            {
                System.out.format("valve position %02x\r\n",decodedPacket.body.valvePos);
                }

        System.out.format("\r\nflags           %02x\r\n",decodedPacket.body.flags);
        System.out.println(("fault flag:     " + (((decodedPacket.body.flags & 0x80)== (byte)0x80)? "set":"clear")));
        System.out.println(("low battery:    " + (((decodedPacket.body.flags & 0x40)== (byte)0x40)? "set":"clear")));
        System.out.println(("tamper flag:    " + (((decodedPacket.body.flags & 0x20)== (byte)0x20)? "set":"clear")));
        System.out.println(("stats present:  " + (((decodedPacket.body.flags & 0x10)== (byte)0x10)? "set":"clear")));


        if ((decodedPacket.body.flags & 0x0C) == (byte)0x00)
            {
                System.out.println("occupancy: unreported");
                }
        if ((decodedPacket.body.flags & 0x0C) == (byte)0x40)
            {
                System.out.println("occupancy: none");
                }
        if ((decodedPacket.body.flags & 0x0C) == (byte)0x08)
            {
                System.out.println("occupancy: possible");
                }
        if ((decodedPacket.body.flags & 0x0C) == (byte)0x0C)
            {
                System.out.println("occupancy: likely");
                }
        System.out.println("bottom 2 bits reserved value of b01");

        System.out.format("\r\njson string    %s\r\n",decodedPacket.body.stats);

        //Trailer
        if (decodedPacket.secFlag == false)
            {
                System.out.format("CRC: %02x",decodedPacket.trailer[0]);
                }
        else{

            System.out.println("Trailer Bytes");
            for(i=0;i<23;i++)
                {
                    System.out.format("%02x ", decodedPacket.trailer[i]);
                    }
        }
    }



    /**Playpen for understanding jUnit. */
    @Test
    public void testPlaypen()
        {

        final byte[] msgBuff = new byte[0xFF];
        int msgLen,i;

        // This is Example 1 in Damon's Spec
        final OFrameStruct packetToSendA = new OFrameStruct();
        final byte[] idA = {(byte)0x80,(byte)0x81};
        final byte[] idC = new byte[4];
        System.arraycopy(LeafID, 0, idC, 0, 4); // 4MSBs of leaf node ID

        final BodyStruct bodyA = new BodyStruct();

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
        final BodyStruct bodyB= new BodyStruct();
        bodyB.heat = false;
        bodyB.valvePos=0x7f;
        bodyB.flags = 0x11;
        bodyB.stats = "{\"b\":1";

        final OFrameStruct packetToSendB = new OFrameStruct();
        packetToSendB.secFlag = false;
        packetToSendB.frameType = 0x4F; // Insecure O Frame
        packetToSendB.frameSeqNo = 0;
        packetToSendB.idLen = 2;
        packetToSendB.id = idA;
        packetToSendB.body = bodyB;
        packetToSendB.bodyLen = (byte)(bodyB.stats.getBytes().length+2);

        //Example 3 - secure version of example 2 above
        final BodyStruct bodyC= new BodyStruct();
        bodyC.heat = false;
        bodyC.valvePos=0x7f;
        bodyC.flags = 0x11;
        bodyC.stats = "{\"b\":1";

        final OFrameStruct packetToSendC = new OFrameStruct();
        packetToSendC.secFlag = true;
        packetToSendC.frameType = 0x4F; // secure O Frame
        packetToSendC.frameSeqNo = 0;
        packetToSendC.idLen = 4;        // needs to be 4 bytes or more. Behaviour undefined if more at the moment
        packetToSendC.id = idC;
        packetToSendC.body = bodyC;        // This must happen before the next line to avoid null pointer exception!!
        packetToSendC.bodyLen = (byte)(bodyC.stats.getBytes().length+2);  //Number of bytes in the stats string + 2 for the flags


        System.out.println("Start Test");
        System.out.println("bodyLen ="+ packetToSendC.bodyLen);

        //TODO - set up an array of structure pointers and run the whole lot through the encode / decode functions

        msgLen = buildOFrame (msgBuff,packetToSendC);

        System.out.format("Raw data packet  from encoder is: %02x bytes long \r\n",msgLen);
        for (i=0;i<msgLen;i++)
            {
                System.out.format("%02x ", msgBuff[i]);
                }

        System.out.println("");            // CR LF

        // Decode and print out the received packet.
        printPacket(decodeOFrame (msgBuff));
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

    /**Compute (non-secure) CRC over secureable frame content.
     * @param buf  buffer that included the frame data to have the CRC applied (all of header and body);
     *     never null
     * @param pos  starting position of the frame data in the buffer;
     *     must be valid offset within the buffer
     * @param len  length of frame data to have the CRC computed over;
     *     strictly positive and pos+len must be within the buffer
     */
    public static byte computeInsecureFrameCRC(final byte buf[], final int pos, final int len)
        {
        byte crc = (byte)0xff; // Initialise CRC with 0xff (protects against extra leading 0x00s).
        for(int i = 0; i < len; ++i)
            {
            crc = CRC7_5B.crc7_5B_update(crc, buf[pos + i]);
            }
        if(0 == crc) { return((byte)0x80); } // Avoid all-0s and all-1s result values, ie self-whitened.
        return(crc);
        }

    /**Simple minimal test of non-secure 'O' format frame.
     * Do a valve frame at 0% open, no stats.
     * Do a non-valve frame with minimal representative {"b":1} stats.
     */
    @Test
    public void testNonSecure()
        {
//Example insecure frame, from valve unit 0% open, no call for heat/flags/stats.
//
//08 4f 02 80 81 02 | 00 01 | 1c
//
//08 length of header after length byte 5 + body 2 + trailer 1
//4f 'O' insecure OpenTRV basic frame
//02 0 sequence number, ID length 2
//80 ID byte 1
//81 ID byte 2
//02 body length 2
//00 valve 0%, no call for heat
//01 no flags or stats, unreported occupancy
//23 CRC value
        // Check the CRC computation for the simple "valve 0%" frame.
        assertEquals((byte)0x23, computeInsecureFrameCRC(new byte[]{8, 'O', 2, (byte)0x80, (byte)0x81, 2, 0, 1}, 0, 8));

//Example insecure frame, no valve, representative minimum stats {"b":1}
//In this case the frame sequence number is zero, and ID is 0x80 0x81.
//
//0e 4f 02 80 81 08 | 7f 11 7b 22 62 22 3a 31 | 61
//
//0e length of header (14) after length byte 5 + body 8 + trailer 1
//4f 'O' insecure OpenTRV basic frame
//02 0 sequence number, ID length 2
//80 ID byte 1
//81 ID byte 2
//08 body length 8
//7f no valve, no call for heat
//11 no flags, unreported occupancy, stats present
//7b 22 62 22 3a 31  {"b":1  Stats: note that implicit trailing '}' is not sent.
//61 CRC value
        // Check the CRC computation for the simple stats frame.
        assertEquals((byte)0x61, computeInsecureFrameCRC(new byte[]{14, 'O', 2, (byte)0x80, (byte)0x81, 8, 0x7f, 0x11, '{', '"', 'b', '"', ':', '1'}, 0, 14));
        }

    }
