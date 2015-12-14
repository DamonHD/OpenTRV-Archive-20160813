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
    public void testBasics()
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

    }
