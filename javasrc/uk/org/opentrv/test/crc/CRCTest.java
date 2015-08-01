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

Author(s) / Copyright (s): Damon Hart-Davis 2014
*/

package uk.org.opentrv.test.crc;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import java.io.UnsupportedEncodingException;
import java.util.Arrays;
import java.util.Random;

import org.junit.Test;

import uk.org.opentrv.comms.util.crc.CC1Impl;
import uk.org.opentrv.comms.util.crc.CRC7_5B;
import uk.org.opentrv.comms.util.crc.CRC8_98_DOW;

public final class CRCTest
    {
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

    /**Check expected behaviour of Dallas OneWire 8-bit CRC. */
    @Test public void test_crc8_98_DOW_update()
        {
        // Test against standard text string.
        // For PYCRC 0.8.1
        // Running ./pycrc.py --model=dallas-1-wire
        // Generates: 0xa1
        // From pycrc-generated reference bit-by-bit code.
        // Hand coded.
        byte crcS = 0; // Initialise with zero.
        for(final byte b : getStdTestASCIITextAsByteArray())
            { crcS = CRC8_98_DOW.crc8_98_DOW_update(crcS, b); }
        assertEquals("CRC should match for standard text string", (byte)0xa1, crcS);

        // Test against standard text string.
        // For PYCRC 0.8.1
        // Running ./pycrc.py --model=dallas-1-wire
        // Generates: 0xa1
        // From pycrc-generated reference bit-by-bit code.
        byte crcBBB = CRC8_98_DOW.bbb_init();
        crcBBB = CRC8_98_DOW.bbb_update(crcBBB, getStdTestASCIITextAsByteArray(), STD_TEST_ASCII_TEXT.length());
        crcBBB = CRC8_98_DOW.bbb_finalize(crcBBB);
        assertEquals("CRC should match for standard text string", (byte)0xa1, crcBBB);

        // Test against standard text string.
        // For PYCRC 0.8.1
        // Running ./pycrc.py --model=dallas-1-wire
        // Generates: 0xa1
        // From pycrc-generated reference table-driven code.
        byte crcTBL = CRC8_98_DOW.tbl_init();
        crcTBL = CRC8_98_DOW.tbl_update(crcTBL, getStdTestASCIITextAsByteArray(), STD_TEST_ASCII_TEXT.length());
        crcTBL = CRC8_98_DOW.tbl_finalize(crcTBL);
        assertEquals("CRC should match for standard text string", (byte)0xa1, crcTBL);

        // Test against standard text string.
        // For PYCRC 0.8.1
        // Running ./pycrc.py --model=dallas-1-wire
        // Generates: 0xa1
        // From pycrc-generated reference space-constrained table-driven code.
        byte crcTB4 = CRC8_98_DOW.tb4_init();
        crcTB4 = CRC8_98_DOW.tb4_update(crcTB4, getStdTestASCIITextAsByteArray(), STD_TEST_ASCII_TEXT.length());
        crcTB4 = CRC8_98_DOW.tb4_finalize(crcTB4);
        assertEquals("CRC should match for standard text string", (byte)0xa1, crcTB4);

        // Tests against Dallas/Maxim test vector.
        // Table 1 of http://www.maxim-ic.com/appnotes.cfm/appnote_number/27
        final byte serno[] = { 0x02, 0x1c, (byte)0xb8, 0x01, 0, 0, 0, (byte)0xa2 };

        // Byte-at-a-time update.
        crcBBB = 0;
        crcBBB = CRC8_98_DOW.bbb_update(crcBBB, new byte[]{2}, 1);
        assertEquals((byte)0xbc, CRC8_98_DOW.bbb_finalize(crcBBB));
        crcBBB = CRC8_98_DOW.bbb_update(crcBBB, new byte[]{0x1c}, 1);
        assertEquals((byte)0xaf, CRC8_98_DOW.bbb_finalize(crcBBB));
        crcBBB = CRC8_98_DOW.bbb_update(crcBBB, new byte[]{(byte)0xb8}, 1);
        assertEquals((byte)0x1e, CRC8_98_DOW.bbb_finalize(crcBBB));
        // Block update.
        crcBBB = CRC8_98_DOW.bbb_init();
        crcBBB = CRC8_98_DOW.bbb_update(crcBBB, serno, serno.length);
        crcBBB = CRC8_98_DOW.bbb_finalize(crcBBB);
        assertEquals("result on test vector with CRC must be zero", 0, crcBBB);

        // Byte-at-a-time update based on example (test vector) in:
        // Table 1 of http://www.maxim-ic.com/appnotes.cfm/appnote_number/27
        crcS = 0; // Initialise with zero.
        for(final byte element : serno)
            { crcS = CRC8_98_DOW.crc8_98_DOW_update(crcS, element); }
        assertEquals("result on test vector with CRC must be zero", 0, crcS);

        // Byte-at-a-time update based on example in:
        // Table 1 of http://www.maxim-ic.com/appnotes.cfm/appnote_number/27
        crcS = 0; // Initialise with zero.
        crcS = CRC8_98_DOW.crc8_98_DOW_update(crcS, (byte)2);
        assertEquals((byte)0xbc, crcS);

        // Verify ability to detect some types of errors.
        // This CRC should be able to detect all 1-, 2- and 3- bit errors
        // on payloads up to 14 bytes.
        assertTrue(STD_TEST_ASCII_TEXT.length() <= 14);
        for(int i = 100; --i >= 0; )
            {
            final int ec = 1 + rnd.nextInt(3);
            final byte data[] = getStdTestASCIITextAsByteArray();
            final byte xorMask[] = new byte[data.length];
            randomMask(ec, xorMask);
            byte crc = 0;
            for(int j = 0; j < data.length; ++j)
                { crc = CRC8_98_DOW.crc8_98_DOW_update(crc, data[j] ^ xorMask[j]); }
            final byte expected = (byte)0xa1;
            assertFalse("should detect every error of size " + ec + " " + Arrays.toString(xorMask) + " got " + crc + " from " + Arrays.toString(data), expected == crc);
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

        // Test against standard text string.
        // For PYCRC 0.8.1
        // Running ./pycrc.py -v --width=7 --poly=0x37 --reflect-in=false --reflect-out=false --xor-in=0 --xor-out=0 --algo=bbb
        // Generates: 0x4
        // Hand coded.
        byte crcS = 0; // Initialise with zero.
        for(final byte b : getStdTestASCIITextAsByteArray())
            { crcS = CRC7_5B.crc7_5B_update(crcS, b); }
        assertEquals("CRC should match for standard text string", 4, crcS);

        // Verify ability to detect some types of errors.
        // This CRC should be able to detect all 1-, 2- and 3- bit errors
        // on payloads up to 7 bytes (56 bits).
        final byte testbytes1[] = { (byte)0x40, 39, (byte)'3', (byte)'4', (byte)'5', (byte)'6', (byte)'7' };
        crcS = 0; // Initialise with zero.
        for(final byte b : testbytes1)
            { crcS = CRC7_5B.crc7_5B_update(crcS, b); }
        final byte expected = 11;
        assertEquals("CRC should match for standard text string", expected, crcS);
        // Systematically generate all 1-bit errors: they should all be detected.
        for(int whichByte = testbytes1.length; --whichByte >= 0; )
            {
            for(int mask = 0x80; mask != 0; mask >>= 1)
                {
                final byte[] adjustedData = testbytes1.clone();
                adjustedData[whichByte] ^= mask;
                crcS = 0; // Initialise with zero.
                for(final byte ba : adjustedData)
                    { crcS = CRC7_5B.crc7_5B_update(crcS, ba); }
                assertFalse("every single-bit error must be detected: " + mask, expected == crcS);
                }
            }
        // Check a sampling of 2- and 3- bit errors,
        // all of which should be detected (Hamming distance of CRC should be 4).
        final byte xorMask[] = new byte[testbytes1.length];
        for(int i = 100; --i >= 0; )
            {
            for(int ec = 2; ec <= 3; ++ec)
                {
                randomMask(ec, xorMask);
                crcS = 0; // Initialise with zero.
                for(int j = 0; j < testbytes1.length; ++j)
                    { crcS = CRC7_5B.crc7_5B_update(crcS, testbytes1[j] ^ xorMask[j]); }
                assertFalse("should detect every error of size " + ec + " " + Arrays.toString(xorMask) + " got " + crcS, expected == crcS);
                }
            }

        // Special case for protecting just 15 bits of a minimal stats header
        // treating the first byte as if a partial/running CRC
        // with the top bit unprotected, thus fixed and verified explicitly another way.
        verify_CRC7_5B_2_byte_behaviour(0, 0, 0);
        verify_CRC7_5B_2_byte_behaviour(0x1a, 0x40, 0); // Minimal stats payload with normal power and minimum temperature.
        verify_CRC7_5B_2_byte_behaviour(0x26, 0x40, 40); // Minimal stats payload with normal power and 20C temperature.
        verify_CRC7_5B_2_byte_behaviour(0x7b, 0x50, 40); // Minimal stats payload with low power and 20C temperature.
        verify_CRC7_5B_2_byte_behaviour(0x7e, 0x7f, 0x70); // 1-byte minimal full-stats frame (07xf initialiser + header).

        // CRC on "{}" minimal JSON message with high bit set on trailing '}'.
        verify_CRC7_5B_2_byte_behaviour(0x38, '{', '}' | 0x80);
        }


    /**Verify expected behaviour of CRC7_5B with known inputs and outputs for just two bytes.
     * Tests expected CRC computation results, and error-detection ability.
     * @param expected  CRC result
     * @param b0  byte 0 (initial value, top bit not protected by the CRC)
     * @param b1  byte 1 (update byte)
     */
    private static void verify_CRC7_5B_2_byte_behaviour(final int expected, final int b0, final int b1)
        {
        assertEquals("expected result must be computed", expected, CRC7_5B.crc7_5B_update(b0, b1));
        final byte xorMask[] = new byte[2];
        // Systematically check that no single-bit change to the inputs produces an unchanged CRC.
        for(int whichByte = 2; --whichByte >= 0; )
            {
            Arrays.fill(xorMask, (byte)0);
            for(int mask = (0 == whichByte) ? 0x40 : 0x80; mask != 0; mask >>= 1)
                {
                xorMask[whichByte] = (byte) mask;
                final byte crc = CRC7_5B.crc7_5B_update(b0 ^ xorMask[0], b1 ^ xorMask[1]);
                assertFalse("every single-bit error must be detected: " + mask, expected == crc);
                }
            }
        // Systematically check that most 2-bit burst errors produce an changed CRC.
        // Note: this is only flipping adjacent bits within each byte, not across a byte boundary.
        for(int whichByte = 2; --whichByte >= 0; )
            {
            Arrays.fill(xorMask, (byte)0);
            for(int mask = (0 == whichByte) ? 0x60 : 0xc0; mask >= 3; mask >>= 1)
                {
                xorMask[whichByte] = (byte) mask;
                final byte crc = CRC7_5B.crc7_5B_update(b0 ^ xorMask[0], b1 ^ xorMask[1]);
                assertFalse("every adjacent dual-bit error must be detected", expected == crc);
                }
            }
        }

    /**Leaves a random set of n non-zero bits in the buffer supplied.
     * FIXME: This version will refuse to set more than half the bits.
     */
    public static void randomMask(final int nOneBits, final byte[] buf)
        {
        if(null == buf) { throw new IllegalArgumentException(); }
        if(0 == buf.length) { throw new IllegalArgumentException(); }
        if(nOneBits < 0) { throw new IllegalArgumentException(); }
        if(nOneBits > (buf.length * 4)) { throw new IllegalArgumentException(); }
        Arrays.fill(buf, (byte) 0); // Zero the array.
        for(int bitsLeftToFlip = nOneBits; bitsLeftToFlip > 0; )
            {
            // Pick byte at random.
            final int n = rnd.nextInt(buf.length);
            // Pick bit at random as a mask.
            final byte m = (byte) ((0x100) >>> (1 + (rnd.nextInt() & 7)));
            if(0 != (buf[n] & m)) { continue; } // Bit already set.
//System.out.println("n="+n+", m="+m);
            // Found victim location; set the bit.
            buf[n] |= m;
            --bitsLeftToFlip;
            }
//System.out.println(Arrays.toString(buf));
        }

    /**Test some basics of the CC1 (central control V1) protocol CRC1.
     * These tests can then be ported to/from the Arduino C++ code. 
     */
    @Test public void testCC1()
        {
        byte buf[] = new byte[13]; // More than long enough.
        // Test that a zero leading byte is rejected with a zero result.
        buf[0] = 0;
        assertEquals(0, CC1Impl.computeSimpleCRC(buf, 0, buf.length));
        // Test that a plausible non-zero byte and long-enough buffer is non-zero.
        buf[0] = '!';
        assertTrue(0 != CC1Impl.computeSimpleCRC(buf, 0, buf.length));
        // Test that a plausible non-zero byte and not-long-enough buffer is rejected with a zero result.
        buf[0] = '!';
        assertEquals(0, CC1Impl.computeSimpleCRC(buf, 0, 1));
        assertEquals(0, CC1Impl.computeSimpleCRC(buf, 0, 6));
        assertTrue(0 != CC1Impl.computeSimpleCRC(buf, 0, 7 /* OTProtocolCC::CC1Alert::primary_frame_bytes */ )); // Should be long enough.
        // CC1Alert contains:
        //   * House code (hc1, hc2) of valve controller that the alert is being sent from (or on behalf of).
        //   * Four extension bytes, currently reserved and of value 1.
        // Should generally be fixed length on the wire, and protected by non-zero version of CRC7_5B.
        //     '!' hc2 hc2 1 1 1 1 crc
        // Note that most values are whitened to be neither 0x00 nor 0xff on the wire.
        // Minimal alert with zero house codes.
        byte bufAlert0[] = new byte[] {'!', 0, 0, 1, 1, 1, 1};
        assertEquals(80, CC1Impl.computeSimpleCRC(bufAlert0, 0, bufAlert0.length));
        // Minimal alert with non-zero house codes.
        byte bufAlert1[] = new byte[] {'!', 10, 21, 1, 1, 1, 1};
        assertEquals(55, CC1Impl.computeSimpleCRC(bufAlert1, 0, bufAlert1.length));
        // Minimal alert with non-zero house codes.
        byte bufAlert2[] = new byte[] {'!', 99, 99, 1, 1, 1, 1};
        assertEquals(12, CC1Impl.computeSimpleCRC(bufAlert2, 0, bufAlert2.length));
        }

    /**OK PRNG. */
    private static final Random rnd = new Random();
    }
