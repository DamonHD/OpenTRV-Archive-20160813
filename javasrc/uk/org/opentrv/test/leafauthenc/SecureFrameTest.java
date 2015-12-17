package uk.org.opentrv.test.leafauthenc;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import java.io.UnsupportedEncodingException;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.Arrays;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
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
    public void testPlaypen()
        {
//        assertTrue(false);
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
//7b 22 62 22 3a 31 {"b":1   Stats: note that implicit trailing '}' is not sent.
//61 CRC value
        // Check the CRC computation for the simple stats frame.
        assertEquals((byte)0x61, computeInsecureFrameCRC(new byte[]{14, 'O', 2, (byte)0x80, (byte)0x81, 8, 0x7f, 0x11, '{', '"', 'b', '"', ':', '1'}, 0, 14));
        }

    }
