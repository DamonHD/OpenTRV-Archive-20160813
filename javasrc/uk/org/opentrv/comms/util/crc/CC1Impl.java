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

package uk.org.opentrv.comms.util.crc;


/**CRC implementation for CC1 (Central Control 1) frames.
 * These are short (up to 7 bytes but in fact 7-byte fixed-length as of 2015/08/01) frames
 * for simple central control (2-way) comms for heating control.
 */
public final class CC1Impl
    {
    private CC1Impl() { /* prevent instance creation */ }

    /**Alternative value to use for CRC7_5B if result would ber zero.
     * This is to ensure that both 0x00 and 0xff can be avoided in the result,
     * but still only 7 bits are actually required.
     */
    public static final byte crc7_5B_update_nz_ALT = (byte)0x80;

     /**Compute the (non-zero) CRC for simple CC1 messages, for encode or decode.
      * Nominally looks at the message type to decide who many bytes to apply the CRC to.
      * The result should match the actual CRC on decode,
      * and can be used to set the CRC from on encode.
      *
      * @param buf  buffer; never null
      * @param offset  offset within buffer; non-negative
      * @param buflen  length of section to computer CRC for starting at offset;
      *     must be positive and entirely within buf[]
      * @return 0 (invalid) if the buffer is too short or the message otherwise invalid
      */
     public static byte computeSimpleCRC(final byte buf[], final int offset, final int buflen)
         {
         // Assume a fixed message length.
         final int len = 7;

         if(buflen < len) { return(0); } // FAIL

         // Start with first (type) byte, which should always be non-zero.
         // NOTE: this does not start with a separate (eg -1) value, nor invert the result, to save time for these fixed length messages.
         byte crc = buf[offset];
         if(0 == crc) { return(0); } // FAIL.

         for(int i = 1; i < len; ++i)
             { crc = CRC7_5B.crc7_5B_update(crc, buf[offset + i]); }

         // Replace a zero CRC value with a non-zero.
         if(0 != crc) { return(crc); }
         return(crc7_5B_update_nz_ALT);
         }
    }
