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
                           Deniz Erbilgin 2015
*/

package uk.org.opentrv.test.leafauthenc;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

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

public class AESGCMTest
    {
    public static final int AES_KEY_SIZE = 128; // in bits
    public static final int GCM_NONCE_LENGTH = 12; // in bytes
    public static final int GCM_TAG_LENGTH = 16; // in bytes (default 16, 12 possible)

    /**Cryptographically-secure PRNG. */
    private static SecureRandom srnd;

    /**Do some expensive initialisation as lazily as possible... */
    @BeforeClass
    public static void beforeClass() throws NoSuchAlgorithmException
        {
        srnd = SecureRandom.getInstanceStrong(); // JDK 8.
        }

// From: https://bugs.openjdk.java.net/browse/JDK-8062828 comments:
//    public static void main(String[] args) throws Exception {
//        int testNum = 0; // pass
//
//        if (args.length > 0) {
//            testNum = Integer.parseInt(args[0]);
//            if (testNum <0 || testNum > 3) {
//                System.out.println("Usage: java AESGCMUpdateAAD2 [X]");
//                System.out.println("X can be 0, 1, 2, 3");
//                System.exit(1);
//            }
//        }
//        byte[] input = "Hello AES-GCM World!".getBytes();
//
//        // Initialise random and generate key
//        //SecureRandom random = SecureRandom.getInstanceStrong();
//        SecureRandom random = new SecureRandom();
//        KeyGenerator keyGen = KeyGenerator.getInstance("AES");
//        keyGen.init(AES_KEY_SIZE, random);
//        SecretKey key = keyGen.generateKey();
//
//        // Encrypt
//        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding", "SunJCE");
//        final byte[] nonce = new byte[GCM_NONCE_LENGTH];
//        random.nextBytes(nonce);
//        GCMParameterSpec spec = new GCMParameterSpec(GCM_TAG_LENGTH * 8, nonce);
//        cipher.init(Cipher.ENCRYPT_MODE, key, spec);
//
//        byte[] aad = "Whatever I like".getBytes();;
//        cipher.updateAAD(aad);
//
//        byte[] cipherText = cipher.doFinal(input);
//
//        // Decrypt; nonce is shared implicitly
//        cipher.init(Cipher.DECRYPT_MODE, key, spec);
//
//        // EXPECTED: Uncommenting this will cause an AEADBadTagException when decrypting
//        // because AAD value is altered
//        if (testNum == 1) aad[1]++;
//
//        cipher.updateAAD(aad);
//
//        // EXPECTED: Uncommenting this will cause an AEADBadTagException when decrypting
//        // because the encrypted data has been altered
//        if (testNum == 2) cipherText[10]++;
//
//        // EXPECTED: Uncommenting this will cause an AEADBadTagException when decrypting
//        // because the tag has been altered
//        if (testNum == 3) cipherText[cipherText.length - 2]++;
//
//        try {
//            byte[] plainText = cipher.doFinal(cipherText);
//            if (testNum != 0) {
//                System.out.println("Test Failed: expected AEADBadTagException not thrown");
//            } else {
//                // check if the decryption result matches
//                if (Arrays.equals(input, plainText)) {
//                    System.out.println("Test Passed: match!");
//                } else {
//                    System.out.println("Test Failed: result mismatch!");
//                    System.out.println(new String(plainText));
//                }
//            }
//        } catch(AEADBadTagException ex) {
//            if (testNum == 0) {
//                System.out.println("Test Failed: unexpected ex " + ex);
//                ex.printStackTrace();
//            } else {
//                System.out.println("Test Passed: expected ex " + ex);
//            }
//        }
//    }

    /**Basic test that the AES-GCM suite is available and works.
     * Based on https://bugs.openjdk.java.net/browse/JDK-8062828 commentary/example.
     * <p>
     * Note: AES/GCM/NoPadding impl appends auth tag to cyphertext, I believe: DHD20151220.
     */
    @Test
    public void testAESGCMBasics() throws Exception
        {
        final byte[] input = "{\"T|C16\":234,\"L\":237,\"B|cV\":256}".getBytes();

        // Initialise random and generate key
//        final SecureRandom random = SecureRandom.getInstanceStrong(); // JDK 8.
//        SecureRandom random = new SecureRandom(); // JDK 7.
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
//        System.out.println("Size plain="+input.length+" aad="+aad.length+" cipher="+cipherText.length);
        assertTrue(cipherText.length < 64); // Would fit in typical radio frame, ignoring RF sync, nonce, etc.

        // Decrypt: nonce is shared implicitly.
        cipher.init(Cipher.DECRYPT_MODE, key, spec);

        cipher.updateAAD(aad);

        final byte[] plainText = cipher.doFinal(cipherText);
        // Check that the decryption result matches.
        assertTrue((Arrays.equals(input, plainText)));
        }

    /**Test on specific simple plaintext/ADATA.key value.
     * Can be used to test MCU-based implementations.
     * <p>
     * Note: AES/GCM/NoPadding impl appends auth tag to cyphertext, I believe: DHD20151220.
     */
    @Test
    public void testAESGCMAll0() throws Exception
        {
        final byte[] input = new byte[30]; // All-zeros input.

        // All-zeros key.
        final SecretKey key = new SecretKeySpec(new byte[AES_KEY_SIZE/8], 0, AES_KEY_SIZE/8, "AES");
        final byte[] nonce = new byte[GCM_NONCE_LENGTH]; // All-zeros nonce.
        final byte[] aad = new byte[4]; // All-zeros ADATA.

        // Encrypt...
        final Cipher cipherE = Cipher.getInstance("AES/GCM/NoPadding", "SunJCE"); // JDK 7 breaks here..
        final GCMParameterSpec spec = new GCMParameterSpec(GCM_TAG_LENGTH * 8, nonce);
        cipherE.init(Cipher.ENCRYPT_MODE, key, spec);
        cipherE.updateAAD(aad);
        final byte[] cipherText = cipherE.doFinal(input);
        assertEquals(input.length + GCM_TAG_LENGTH, cipherText.length);
        assertEquals((byte)0x03, cipherText[0]);
        assertEquals((byte)0x88, cipherText[1]);
        assertEquals((byte)0x8b, cipherText[input.length-1]);
        assertEquals((byte)0x61, cipherText[input.length + 0]); // Start of tag.
        assertEquals((byte)0x33, cipherText[input.length + 15]); // End of tag.
        System.out.println(DatatypeConverter.printHexBinary(cipherText));
        assertEquals((16 == GCM_TAG_LENGTH) ?
            "0388DACE60B6A392F328C2B971B2FE78F795AAAB494B5923F7FD89FF948B614772C7929CD0DD681BD8A37A656F33" :
            "0388DACE60B6A392F328C2B971B2FE78F795AAAB494B5923F7FD89FF948B614772C7929CD0DD681BD8A3",
            DatatypeConverter.printHexBinary(cipherText));

        // Decrypt...
        final Cipher cipherD = Cipher.getInstance("AES/GCM/NoPadding", "SunJCE"); // JDK 7 breaks here..
        cipherD.init(Cipher.DECRYPT_MODE, key, spec);
        cipherD.updateAAD(aad);
        final byte[] plainText = cipherD.doFinal(cipherText);
        // Check that the decryption result matches.
        assertTrue((Arrays.equals(input, plainText)));
        }
    }
